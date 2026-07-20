VORP = exports.vorp_core:vorpAPI()
local VorpCore = {}
local ServerRPC = exports.vorp_core:ServerRpcCall()
local VORPutils = {}
local Translations = Lang[Config.Lang]

---@diagnostic disable-next-line: undefined-global
local MySQL = MySQL

function _L(str, ...)
    if Translations[str] then
    local ok, formatted = pcall(string.format, Translations[str], ...)
    if ok then
      return formatted
    end

    print(('[democracy] Translation format fallback for key "%s": %s'):format(tostring(str), tostring(formatted)))
    return tostring(Translations[str])
    else
        print('Translation not found in server: ' .. str)
        return 'Translation not found: ' .. str
    end
end

TriggerEvent("getUtils", function(utils)
    VORPutils = utils
end)
TriggerEvent("getCore",function(core)
    VorpCore = core
end)

local function getUserGroup(user)
  if type(user.getGroup) == 'function' then
    return user.getGroup()
  end
  return user.getGroup
end

local function getUserJob(user)
  if type(user.getJob) == 'function' then
    return user.getJob()
  end
  return user.getJob
end

local hasElectionControlPermission

local function buildCharacterName(firstname, lastname, fallback)
  local first = tostring(firstname or ''):gsub('^%s+', ''):gsub('%s+$', '')
  local last = tostring(lastname or ''):gsub('^%s+', ''):gsub('%s+$', '')
  local full = (first .. ' ' .. last):gsub('^%s+', ''):gsub('%s+$', '')

  if full ~= '' then
    return full
  end

  return tostring(fallback or '')
end

local function resolveCharacterNameByCharId(charId, fallback, cb)
  MySQL.single('SELECT firstname, lastname FROM characters WHERE charidentifier = ? LIMIT 1', { charId }, function(row)
    if row then
      cb(buildCharacterName(row.firstname, row.lastname, fallback))
      return
    end

    cb(tostring(fallback or ''))
  end)
end

local LocationAliases = {
  ['st denis'] = 'saint denis',
  ['st. denis'] = 'saint denis',
  ['st dennis'] = 'saint denis',
  ['saint denis'] = 'saint denis',
  ['nuevo paraiso'] = 'nuevo paraiso',
  ['nuevo paraíso'] = 'nuevo paraiso'
}

local function normalizeLocationValue(value)
  local text = tostring(value or '')
  text = text:gsub('^%s+', ''):gsub('%s+$', '')
  text = text:gsub('%p', ' ')
  text = text:gsub('%s+', ' ')
  text = string.lower(text)
  return LocationAliases[text] or text
end

local function resolveTownIdFromBooth(city, region, state, providedTownId)
  local supplied = tostring(providedTownId or '')
  if supplied ~= '' then
    return supplied
  end

  local cityNorm = normalizeLocationValue(city)
  local regionNorm = normalizeLocationValue(region)
  local stateNorm = normalizeLocationValue(state)

  for _, loc in ipairs(Config.VotingLocations or {}) do
    if normalizeLocationValue(loc.city) == cityNorm
      and normalizeLocationValue(loc.region) == regionNorm
      and normalizeLocationValue(loc.state) == stateNorm then
      return tostring(loc.townId or '')
    end
  end

  return ''
end

local function normalizeBoothKey(value)
  return normalizeLocationValue(value)
end

local function findVotingLocationByTownId(townId)
  local target = normalizeBoothKey(townId)
  if target == '' then
    return nil
  end

  for _, loc in ipairs(Config.VotingLocations or {}) do
    if normalizeBoothKey(loc.townId) == target then
      return loc
    end
  end

  return nil
end

local ResidenceCache = {
  byCharId = {},
  sourceToCharId = {},
  ttlSeconds = 300
}

local function clearResidenceCache(charId)
  if not charId then
    return
  end

  ResidenceCache.byCharId[tostring(charId)] = nil
end

local function registerResidenceSource(source, charId)
  if not source or not charId then
    return
  end

  ResidenceCache.sourceToCharId[tostring(source)] = tostring(charId)
end

local function getCachedResidence(charId)
  local key = tostring(charId or '')
  local entry = ResidenceCache.byCharId[key]
  if not entry then
    return nil
  end

  if entry.expiresAt and entry.expiresAt < os.time() then
    ResidenceCache.byCharId[key] = nil
    return nil
  end

  return entry.value
end

local function setCachedResidence(charId, value)
  local key = tostring(charId or '')
  if key == '' then
    return
  end

  ResidenceCache.byCharId[key] = {
    value = value,
    expiresAt = os.time() + ResidenceCache.ttlSeconds
  }
end

local function getGovernmentResidence(charId)
  local cached = getCachedResidence(charId)
  if cached then
    return cached
  end

  local resources = { 'RPE_Government', 'rpe_government' }

  for _, resourceName in ipairs(resources) do
    if GetResourceState(resourceName) == 'started' then
      local resourceExports = exports[resourceName]
      local exportFn = resourceExports and resourceExports.GetResidenceByCharId
      if type(exportFn) == 'function' then
        local ok, result = pcall(exportFn, charId)
        if ok then
          if type(result) == 'table' then
            setCachedResidence(charId, result)
          end

          return result
        end
      end
    end
  end

  return nil
end

local function getResidenceDistrict(charId)
  local residence = getGovernmentResidence(charId)
  if type(residence) ~= 'table' then
    return nil
  end

  local residenceTownId = tostring(residence.town_id or residence.townId or '')
  if residenceTownId == '' then
    return nil
  end

  local location = findVotingLocationByTownId(residenceTownId)
  return {
    townId = residenceTownId,
    state = location and location.state or nil,
    region = location and location.region or nil,
    location = location,
    raw = residence
  }
end

local function isSameValue(left, right)
  return normalizeBoothKey(left) ~= '' and normalizeBoothKey(left) == normalizeBoothKey(right)
end

local function canRegisterAtBooth(charId, boothState)
  local district = getResidenceDistrict(charId)
  if not district then
    return false, 'residence_required'
  end

  if not district.state then
    return false, 'residence_not_mapped'
  end

  if not isSameValue(district.state, boothState) then
    return false, 'residence_state_mismatch'
  end

  return true, district
end

local function canRunForPosition(charId, boothTownId, boothState, boothRegion, jurisdiction)
  local district = getResidenceDistrict(charId)
  if not district then
    return false, 'residence_required'
  end

  if not district.state then
    return false, 'residence_not_mapped'
  end

  local scope = string.lower(tostring(jurisdiction or 'local'))
  if not isSameValue(district.state, boothState) then
    return false, 'candidate_state_mismatch'
  end

  if scope == 'state' then
    return true, district
  end

  if scope == 'county' then
    if not isSameValue(district.region, boothRegion) then
      return false, 'candidate_district_mismatch'
    end
    return true, district
  end

  if not isSameValue(district.townId, boothTownId) then
    return false, 'candidate_district_mismatch'
  end

  return true, district
end

local function canUseResidencyOverride(source)
  local integration = Config.ResidencyIntegration or {}
  local elections = integration.elections or {}

  if elections.allowOverride == false then
    return false
  end

  return hasElectionControlPermission(source)
end

local function logResidencyOverride(source, action, district, boothCity, boothRegion, boothState, reason)
  local user = VorpCore.getUser(source)
  local character = user and user.getUsedCharacter or nil
  local charName = character and buildCharacterName(character.firstname, character.lastname, GetPlayerName(source)) or GetPlayerName(source)
  local townId = district and district.townId or 'unknown'
  local districtState = district and district.state or 'unknown'
  local districtRegion = district and district.region or 'unknown'
  local message = ('[democracy] residency override %s by %s (%s) -> booth %s/%s/%s, residence %s/%s/%s, reason=%s'):format(
    tostring(action or 'unknown'),
    tostring(charName),
    tostring(source),
    tostring(boothCity or 'unknown'),
    tostring(boothRegion or 'unknown'),
    tostring(boothState or 'unknown'),
    tostring(townId),
    tostring(districtRegion),
    tostring(districtState),
    tostring(reason or 'override')
  )

  print(message)
  SendToDiscordWebhook(message, message, 'activity')
end

VORP.addNewCallBack('democracy:getResidenceStatus', function(source, cb, params)
  local user = VorpCore.getUser(source)
  local charId = user and user.getUsedCharacter and user.getUsedCharacter.charIdentifier or nil
  registerResidenceSource(source, charId)
  local boothState = params and params.state or ''
  local boothTownId = params and params.townId or ''
  local boothRegion = params and params.region or ''
  local district = charId and getResidenceDistrict(charId) or nil

  local payload = {
    ok = true,
    eligible = false,
    residenceText = '',
    district = district
  }

  if district then
    local location = district.location
    local address = district.raw and (district.raw.address_line or district.raw.address or '') or ''
    local labelParts = {}
    if address ~= '' then
      table.insert(labelParts, address)
    end
    if location and location.city then
      table.insert(labelParts, location.city)
    elseif district.townId ~= '' then
      table.insert(labelParts, district.townId)
    end
    if district.state then
      table.insert(labelParts, district.state)
    end

    payload.residenceText = _L('residence_hint', table.concat(labelParts, ' - '))
    payload.eligible = district.state ~= '' and isSameValue(district.state, boothState)
    if boothTownId ~= '' and boothRegion ~= '' and location then
      payload.eligible = payload.eligible and (isSameValue(location.townId, boothTownId) or isSameValue(location.region, boothRegion))
    end
  else
    payload.residenceText = _L('residence_hint_missing')
  end

  cb(payload)
end)

local ElectionRuntimeState = {
  Active = Config.ElectionBoothsActiveOnStart == true,
  ActivePositions = {},
  ScopeFilter = { type = 'all', values = {} }
}

local function getAllPositionNames()
  local names = {}
  for _, pos in ipairs(Config.Positions) do
    table.insert(names, pos.name)
  end
  return names
end

ElectionRuntimeState.ActivePositions = getAllPositionNames()

hasElectionControlPermission = function(source)
  if source == 0 then
    return true
  end

  local user = VorpCore.getUser(source)
  if not user then
    return false
  end

  local group = getUserGroup(user)
  local job = getUserJob(user)

  if group == 'admin' then
    return true
  end

  for _, official in ipairs(Config.ElectionOfficials) do
    if official == group or official == job then
      return true
    end
  end

  return false
end

local function cloneArray(input)
  local out = {}
  for _, v in ipairs(input or {}) do
    table.insert(out, v)
  end
  return out
end

local getPositionJurisdiction

local function normalizeSelectedPositions(selected)
  if type(selected) ~= 'table' then
    return getAllPositionNames()
  end

  local valid = {}
  local allowed = {}
  for _, pos in ipairs(Config.Positions) do
    allowed[pos.name] = true
  end

  for _, name in ipairs(selected) do
    if allowed[name] then
      table.insert(valid, name)
    end
  end

  if #valid == 0 then
    valid = getAllPositionNames()
  end

  return valid
end

local function isPositionActive(position)
  if not ElectionRuntimeState.Active then
    return false
  end

  for _, name in ipairs(ElectionRuntimeState.ActivePositions or {}) do
    if name == position then
      return true
    end
  end

  return false
end

local function normalizeScopeValue(value)
  local text = tostring(value or '')
  text = text:gsub('^%s+', ''):gsub('%s+$', '')
  text = text:gsub('%s+', ' ')
  return string.lower(text)
end

local function parseScopeSelection(selection)
  if type(selection) ~= 'string' or selection == '' or selection == 'all' then
    return { type = 'all', values = {} }
  end

  local scopeType, raw = selection:match('^(%w+)%:(.+)$')
  if not scopeType or not raw then
    return { type = 'all', values = {} }
  end

  local cleanType = normalizeScopeValue(scopeType)
  if cleanType == 'county' then
    cleanType = 'region'
  end

  if cleanType ~= 'state' and cleanType ~= 'region' and cleanType ~= 'city' then
    return { type = 'all', values = {} }
  end

  if cleanType == 'region' then
    local region, state = raw:match('^(.-)|(.+)$')
    if region and state then
      return {
        type = 'region',
        values = { string.format('%s|%s', normalizeScopeValue(region), normalizeScopeValue(state)) }
      }
    end

    return {
      type = 'region',
      values = { normalizeScopeValue(raw) }
    }
  end

  if cleanType == 'city' then
    local city, state = raw:match('^(.-)|(.+)$')
    if not city or not state then
      return { type = 'all', values = {} }
    end
    return {
      type = 'city',
      values = { string.format('%s|%s', normalizeScopeValue(city), normalizeScopeValue(state)) }
    }
  end

  return {
    type = cleanType,
    values = { normalizeScopeValue(raw) }
  }
end

local function getScopeStateFromFilter(scopeFilter)
  if type(scopeFilter) ~= 'table' then
    return nil
  end

  local scopeType = normalizeScopeValue(scopeFilter.type)
  local firstValue = scopeFilter.values and scopeFilter.values[1]
  if not firstValue then
    return nil
  end

  if scopeType == 'state' then
    return normalizeScopeValue(firstValue)
  end

  if scopeType == 'region' or scopeType == 'city' then
    local _, state = tostring(firstValue):match('^(.-)|(.+)$')
    if state and state ~= '' then
      return normalizeScopeValue(state)
    end
  end

  return nil
end

AddEventHandler('playerDropped', function()
  local source = source
  local charId = ResidenceCache.sourceToCharId[tostring(source)]
  if charId then
    ResidenceCache.sourceToCharId[tostring(source)] = nil
    clearResidenceCache(charId)
  end
end)

local function getSetupPositionsForScope(scopeFilter)
  local scopeState = getScopeStateFromFilter(scopeFilter)
  local positions = {}

  for _, pos in ipairs(Config.Positions or {}) do
    local include = true
    if scopeState and scopeState ~= '' then
      include = false
      for _, stateName in ipairs(pos.states or {}) do
        if normalizeScopeValue(stateName) == scopeState then
          include = true
          break
        end
      end
    end

    if include then
      table.insert(positions, { name = pos.name, jurisdiction = pos.jurisdiction })
    end
  end

  return positions
end

local function setElectionActive(active, selectedPositions, scopeFilter)
  local wasActive = ElectionRuntimeState.Active
  ElectionRuntimeState.Active = active == true
  if ElectionRuntimeState.Active then
    ElectionRuntimeState.ActivePositions = normalizeSelectedPositions(selectedPositions)
    if type(scopeFilter) == 'table' then
      ElectionRuntimeState.ScopeFilter = {
        type = scopeFilter.type or 'all',
        values = cloneArray(scopeFilter.values or {})
      }
    end
  end

  TriggerClientEvent('democracy:setElectionActive', -1, ElectionRuntimeState.Active, cloneArray(ElectionRuntimeState.ActivePositions), {
    type = ElectionRuntimeState.ScopeFilter.type,
    values = cloneArray(ElectionRuntimeState.ScopeFilter.values)
  })

  if ElectionRuntimeState.Active and not wasActive then
    TriggerClientEvent('vorp:TipBottom', -1, (_L('election_global_announcement')), 6000)
  end
end

VORP.addNewCallBack('democracy:getElectionActive', function(source, cb)
  cb({
    active = ElectionRuntimeState.Active,
    positions = cloneArray(ElectionRuntimeState.ActivePositions),
    scope = {
      type = ElectionRuntimeState.ScopeFilter.type,
      values = cloneArray(ElectionRuntimeState.ScopeFilter.values)
    }
  })
end)

VORP.addNewCallBack('democracy:getSetupPositions', function(source, cb, params)
  if not hasElectionControlPermission(source) then
    cb({ ok = false, positions = {} })
    return
  end

  local selectedScope = params and params.scope or 'all'
  local scopeFilter = parseScopeSelection(selectedScope)
  local positions = getSetupPositionsForScope(scopeFilter)
  cb({ ok = true, positions = positions })
end)

VORP.addNewCallBack('democracy:getVoteablePositions', function(source, cb, params)
  if type(params) ~= 'table' then
    cb({ ok = true, positions = {} })
    return
  end

  local city = tostring(params.city or '')
  local region = tostring(params.region or '')
  local state = tostring(params.state or '')

  local cityNorm = normalizeScopeValue(city)
  local regionNorm = normalizeScopeValue(region)
  local stateNorm = normalizeScopeValue(state)
  local user = VorpCore.getUser(source)
  local charId = user and user.getUsedCharacter and user.getUsedCharacter.charIdentifier or nil
  registerResidenceSource(source, charId)
  local residenceDistrict = charId and getResidenceDistrict(charId) or nil

  if not residenceDistrict or not residenceDistrict.state or not isSameValue(residenceDistrict.state, state) then
    cb({ ok = true, positions = {} })
    return
  end

  MySQL.query('SELECT position, city, region, state FROM ballot WHERE state = @state', {
    ['@state'] = state
  }, function(rows)
    local positions = {}

    for _, pos in ipairs(Config.Positions or {}) do
      if isPositionActive(pos.name) then
        local allowedInState = false
        for _, stateName in ipairs(pos.states or {}) do
          if normalizeScopeValue(stateName) == stateNorm then
            allowedInState = true
            break
          end
        end

        if allowedInState then
          local jurisdiction = string.lower(pos.jurisdiction or 'local')
          local hasCandidate = false

          for _, row in ipairs(rows or {}) do
            if row.position == pos.name then
              local rowState = normalizeScopeValue(row.state)
              local rowRegion = normalizeScopeValue(row.region)
              local rowCity = normalizeScopeValue(row.city)

              if jurisdiction == 'state' then
                if rowState == stateNorm then
                  hasCandidate = true
                  break
                end
              elseif jurisdiction == 'county' then
                if rowState == stateNorm and rowRegion == regionNorm then
                  hasCandidate = true
                  break
                end
              else
                if rowState == stateNorm and rowCity == cityNorm then
                  hasCandidate = true
                  break
                end
              end
            end
          end

          if hasCandidate then
            table.insert(positions, { name = pos.name, jurisdiction = pos.jurisdiction })
          end
        end
      end
    end

    cb({ ok = true, positions = positions })
  end)
end)

local function resolveRegionForScopeCity(cityNorm, stateNorm)
  for _, loc in ipairs(Config.VotingLocations or {}) do
    local locCity = normalizeScopeValue(loc.city)
    local locState = normalizeScopeValue(loc.state)
    if locCity == cityNorm and (stateNorm == '' or locState == stateNorm) then
      return normalizeScopeValue(loc.region)
    end
  end
  return ''
end

local function rowMatchesElectionScope(scopeFilter, jurisdiction, rowState, rowRegion, rowCity)
  local scopeType = normalizeScopeValue(scopeFilter and scopeFilter.type or 'all')
  local firstValue = scopeFilter and scopeFilter.values and scopeFilter.values[1]

  if scopeType == '' or scopeType == 'all' or not firstValue then
    return true
  end

  if scopeType == 'state' then
    return rowState == normalizeScopeValue(firstValue)
  end

  if scopeType == 'region' then
    local regionRaw, stateRaw = tostring(firstValue):match('^(.-)|(.+)$')
    local regionNorm = normalizeScopeValue(regionRaw or firstValue)
    local stateNorm = normalizeScopeValue(stateRaw or '')

    if jurisdiction == 'state' then
      if stateNorm ~= '' then
        return rowState == stateNorm
      end
      return true
    end

    if stateNorm ~= '' and rowState ~= stateNorm then
      return false
    end

    return rowRegion == regionNorm
  end

  if scopeType == 'city' then
    local cityRaw, stateRaw = tostring(firstValue):match('^(.-)|(.+)$')
    local cityNorm = normalizeScopeValue(cityRaw or firstValue)
    local stateNorm = normalizeScopeValue(stateRaw or '')

    if stateNorm ~= '' and rowState ~= stateNorm then
      return false
    end

    if jurisdiction == 'state' then
      return true
    end

    if jurisdiction == 'county' then
      local scopeRegion = resolveRegionForScopeCity(cityNorm, stateNorm)
      if scopeRegion == '' then
        return false
      end
      return rowRegion == scopeRegion
    end

    return rowCity == cityNorm
  end

  return true
end

VORP.addNewCallBack('democracy:getResultPositions', function(source, cb)
  if not hasElectionControlPermission(source) then
    cb({ ok = false, positions = {} })
    return
  end

  if not ElectionRuntimeState.Active then
    cb({ ok = true, positions = {} })
    return
  end

  local scopeFilter = ElectionRuntimeState.ScopeFilter or { type = 'all', values = {} }

  MySQL.query('SELECT position, city, region, state FROM ballot', {}, function(rows)
    local positions = {}

    for _, pos in ipairs(Config.Positions or {}) do
      if isPositionActive(pos.name) then
        local jurisdiction = string.lower(pos.jurisdiction or 'local')
        local hasCandidate = false

        for _, row in ipairs(rows or {}) do
          if row.position == pos.name then
            local rowState = normalizeScopeValue(row.state)
            local rowRegion = normalizeScopeValue(row.region)
            local rowCity = normalizeScopeValue(row.city)

            local allowedInState = false
            for _, stateName in ipairs(pos.states or {}) do
              if normalizeScopeValue(stateName) == rowState then
                allowedInState = true
                break
              end
            end

            if allowedInState and rowMatchesElectionScope(scopeFilter, jurisdiction, rowState, rowRegion, rowCity) then
              hasCandidate = true
              break
            end
          end
        end

        if hasCandidate then
          table.insert(positions, { name = pos.name, jurisdiction = pos.jurisdiction })
        end
      end
    end

    cb({ ok = true, positions = positions })
  end)
end)

VORP.addNewCallBack('democracy:getResultScopes', function(source, cb, params)
  if not hasElectionControlPermission(source) then
    cb({ ok = false, scopes = {}, jurisdiction = 'local' })
    return
  end

  if not ElectionRuntimeState.Active then
    cb({ ok = true, scopes = {}, jurisdiction = 'local' })
    return
  end

  local position = params and params.position
  if not position or position == '' then
    cb({ ok = false, scopes = {}, jurisdiction = 'local' })
    return
  end

  local jurisdiction = getPositionJurisdiction(position)
  local scopeFilter = ElectionRuntimeState.ScopeFilter or { type = 'all', values = {} }
  local seen = {}
  local scopes = {}

  local function trimScopeValue(value)
    local text = tostring(value or '')
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    text = text:gsub('%s+', ' ')
    return text
  end

  MySQL.query('SELECT city, region, state FROM ballot WHERE position = @position', {
    ['@position'] = position
  }, function(rows)
    for _, row in ipairs(rows or {}) do
      local rowStateNorm = normalizeScopeValue(row.state)
      local rowRegionNorm = normalizeScopeValue(row.region)
      local rowCityNorm = normalizeScopeValue(row.city)

      local allowedInState = false
      for _, pos in ipairs(Config.Positions or {}) do
        if pos.name == position then
          for _, stateName in ipairs(pos.states or {}) do
            if normalizeScopeValue(stateName) == rowStateNorm then
              allowedInState = true
              break
            end
          end
          break
        end
      end

      if allowedInState and rowMatchesElectionScope(scopeFilter, jurisdiction, rowStateNorm, rowRegionNorm, rowCityNorm) then
        local stateDisplay = trimScopeValue(row.state)
        local regionDisplay = trimScopeValue(row.region)
        local cityDisplay = trimScopeValue(row.city)

        if jurisdiction == 'state' then
          local key = string.format('state|%s', rowStateNorm)
          if not seen[key] then
            seen[key] = true
            table.insert(scopes, {
              label = stateDisplay,
              value = stateDisplay,
              state = stateDisplay
            })
          end
        elseif jurisdiction == 'county' then
          local key = string.format('region|%s|%s', rowRegionNorm, rowStateNorm)
          if not seen[key] then
            seen[key] = true
            table.insert(scopes, {
              label = string.format('%s (%s)', regionDisplay, stateDisplay),
              value = regionDisplay,
              state = stateDisplay
            })
          end
        else
          local key = string.format('city|%s|%s', rowCityNorm, rowStateNorm)
          if not seen[key] then
            seen[key] = true
            table.insert(scopes, {
              label = string.format('%s (%s)', cityDisplay, stateDisplay),
              value = cityDisplay,
              state = stateDisplay
            })
          end
        end
      end
    end

    table.sort(scopes, function(a, b)
      return tostring(a.label) < tostring(b.label)
    end)

    cb({ ok = true, scopes = scopes, jurisdiction = jurisdiction })
  end)
end)

RegisterServerEvent('democracy:applyElectionSetup')
AddEventHandler('democracy:applyElectionSetup', function(selectedPositions, selectedScope)
  local _source = source
  if not hasElectionControlPermission(_source) then
    TriggerClientEvent("vorp:TipBottom", _source, (_L('no_election_officials')), 4000)
    return
  end

  local scopeFilter = parseScopeSelection(selectedScope)
  setElectionActive(true, selectedPositions, scopeFilter)
  TriggerClientEvent("vorp:TipBottom", _source, (_L('election_commands_enabled')), 4000)
  print('[democracy] electionstart setup applied - booths active')
end)

local function handleElectionCommand(source, active)
  if not hasElectionControlPermission(source) then
    if source ~= 0 then
      TriggerClientEvent("vorp:TipBottom", source, (_L('no_election_officials')), 4000)
    end
    return
  end

  if active and source ~= 0 and Config.UseNUI ~= false then
    local positions = {}
    for _, pos in ipairs(Config.Positions) do
      table.insert(positions, { name = pos.name, jurisdiction = pos.jurisdiction })
    end

    local currentScope = ElectionRuntimeState.ScopeFilter or { type = 'all', values = {} }
    TriggerClientEvent('democracy:openElectionSetup', source, positions, cloneArray(ElectionRuntimeState.ActivePositions), {
      type = currentScope.type,
      values = cloneArray(currentScope.values)
    })
    return
  end

  setElectionActive(active, ElectionRuntimeState.ActivePositions, ElectionRuntimeState.ScopeFilter)

  if source ~= 0 then
    if active then
      TriggerClientEvent("vorp:TipBottom", source, (_L('election_commands_enabled')), 4000)
    else
      TriggerClientEvent("vorp:TipBottom", source, (_L('election_commands_disabled')), 4000)
    end
  end

  if active then
    print('[democracy] electionstart executed - booths active')
  else
    print('[democracy] electionstop executed - booths inactive')
  end
end

RegisterCommand('electionstart', function(source)
  handleElectionCommand(source, true)
end, false)

RegisterCommand('electionstop', function(source)
  handleElectionCommand(source, false)
end, false)

RegisterCommand('wahlenstart', function(source)
  handleElectionCommand(source, true)
end, false)

RegisterCommand('wahlenstop', function(source)
  handleElectionCommand(source, false)
end, false)

local function openElectionResultsFor(source)
  if source == 0 then
    print('[democracy] /electionresults can only be used by in-game admins/election officials.')
    return
  end

  if not hasElectionControlPermission(source) then
    TriggerClientEvent("vorp:TipBottom", source, (_L('no_election_officials')), 4000)
    return
  end

  TriggerClientEvent("vorp:TipBottom", source, (_L('welcome_election_official')), 4000)
  TriggerClientEvent("democracy:openElecResMenu", source)
end

RegisterCommand('electionresults', function(source)
  openElectionResultsFor(source)
end, false)

RegisterCommand('wahlergebnisse', function(source)
  openElectionResultsFor(source)
end, false)

RegisterServerEvent('removeFromBallot')
AddEventHandler('removeFromBallot', function()
  local _source = source
  local user = VorpCore.getUser(_source)
  local charId = user.getUsedCharacter.charIdentifier
  MySQL.single('SELECT * FROM ballot WHERE character_id = ?', {charId},
    function(row)
       if not row then return end
       local ballotid = row.id
       MySQL.Async.execute('DELETE FROM ballot WHERE id = @ballotid',
       {
         ['@ballotid'] = ballotid
       },
       function(rowsChanged)
         if rowsChanged > 0 then
           print("Removed from ballot, now removing votes")
           MySQL.Async.execute('DELETE FROM ballot_votes WHERE ballotID = @ballotid',
           {
             ['@ballotid'] = ballotid
           },
           function(rowsChanged)
            print("deleted votes for that candidate")
           end)

         else
           print("Person not found on ballot")
         
         end
       end)
    end)
  
end)


VORP.addNewCallBack("democracy:checkRegistration", function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)
  local charId = (user.getUsedCharacter).charIdentifier
  local city = params.city
  local region = params.region
  local isRegistered = false -- Initialize the variable

  MySQL.single('SELECT * FROM ballot_registration WHERE voterid = ? AND registrationCity = ? AND registrationRegion = ?', {charId, city, region},
    function(row)
      if not row then
        isRegistered = false
      else
        isRegistered = true
      end

      cb(isRegistered) -- Call the callback with the result
    end
  )
end)

VORP.addNewCallBack("democracy:checkonballot", function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)
  local charId = (user.getUsedCharacter).charIdentifier
  local onBallot = false -- Initialize the variable

  MySQL.single('SELECT * FROM ballot WHERE character_id = ?', {charId},
    function(row)
      if not row then
        onBallot = false
      else
        onBallot = true
       
      end

      cb(onBallot) -- Call the callback with the result
    end
  )
end)

VORP.addNewCallBack("democracy:runningstatus", function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)
  local charId = (user.getUsedCharacter).charIdentifier
   MySQL.single('SELECT * FROM ballot WHERE character_id = ?', {charId},
    function(row)
      cb(row.position)  
    end
  )
end)

VORP.addNewCallBack("democracy:isAdmin", function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)
  local userGroup = getUserGroup(user)
  local userJob = getUserJob(user)

  local isAllowed = userGroup == 'admin'
  if not isAllowed then
    for _, group in ipairs(Config.ElectionOfficials) do
      if group == userGroup or group == userJob then
        isAllowed = true
        break
      end
      if isAllowed then
        break
      end
    end
  end
  
  cb(isAllowed)
end)

local function getTermLimitQueryAndParams(charId, position, state)
  local query = 'SELECT COUNT(*) as count FROM election_winners WHERE character_id = @charId AND position = @pos'
  local queryParams = {
    ['@charId'] = charId,
    ['@pos'] = position
  }

  if Config.TermLimitScope and Config.TermLimitScope.ByState then
    query = query .. ' AND state = @state'
    queryParams['@state'] = state
  end

  if Config.TermLimitScope and Config.TermLimitScope.WindowYears and Config.TermLimitScope.WindowYears > 0 then
    local years = tonumber(Config.TermLimitScope.WindowYears)
    local cutoff = os.date('%Y-%m-%d %H:%M:%S', os.time() - (years * 365 * 24 * 60 * 60))
    query = query .. ' AND election_date >= @cutoff'
    queryParams['@cutoff'] = cutoff
  end

  return query, queryParams
end



RegisterServerEvent('registerVoter')
AddEventHandler('registerVoter', function(city, region, state, townId)
  local _source = source
  local user = VorpCore.getUser(_source) 
  local Character = VorpCore.getUser(_source).getUsedCharacter
  local charId = user.getUsedCharacter.charIdentifier
  registerResidenceSource(_source, charId)
  local resolvedTownId = resolveTownIdFromBooth(city, region, state, townId)
  local canRegister, registerReason = canRegisterAtBooth(charId, state)

  if not canRegister then
    local district = getResidenceDistrict(charId)
    if canUseResidencyOverride(_source) then
      logResidencyOverride(_source, 'register', district, city, region, state, registerReason)
    else
      TriggerClientEvent("vorp:TipBottom", _source, (_L(registerReason or 'residence_required')), 5000)
      return
    end
  end

  if not canRegister and not canUseResidencyOverride(_source) then
    TriggerClientEvent("vorp:TipBottom", _source, (_L(registerReason or 'residence_required')), 5000)
    return
  end

  if Config.DevDebug and resolvedTownId ~= '' then
    print(('[democracy] registration booth townId resolved: %s (%s/%s/%s)'):format(resolvedTownId, tostring(city), tostring(region), tostring(state)))
  end

MySQL.Async.execute('INSERT INTO ballot_registration (voterID, registrationCity, registrationRegion, state) VALUES (@character_id,  @city, @region, @state)',
  {
    ['@character_id'] = charId,
    ['@city'] = city,
    ['@region'] = region,
    ['@state'] = state
  }
)
end)

RegisterServerEvent('addballotname')
AddEventHandler('addballotname', function(city,region,position, state, townId)
  local _source = source
  if not isPositionActive(position) then
    TriggerClientEvent("vorp:TipBottom", _source, (_L('elections_not_active')), 4000)
    return
  end

  local user = VorpCore.getUser(_source) 
  local Character = VorpCore.getUser(_source).getUsedCharacter
  local fallbackName = buildCharacterName(Character.firstname, Character.lastname, GetPlayerName(_source))
  local charId = user.getUsedCharacter.charIdentifier
  registerResidenceSource(_source, charId)
  local resolvedTownId = resolveTownIdFromBooth(city, region, state, townId)
  local positionInfo

  for _, pos in ipairs(Config.Positions) do
    if pos.name == position then
        positionInfo = pos
        break
    end
  end

  local canRun, runReason = canRunForPosition(charId, resolvedTownId, state, region, positionInfo and positionInfo.jurisdiction or 'local')

  if not canRun then
    local district = getResidenceDistrict(charId)
    if canUseResidencyOverride(_source) then
      logResidencyOverride(_source, 'candidate', district, city, region, state, runReason)
    else
      TriggerClientEvent("vorp:TipBottom", _source, (_L(runReason or 'candidate_district_mismatch')), 5000)
      return
    end
  end

  if Config.DevDebug and resolvedTownId ~= '' then
    print(('[democracy] candidacy booth townId resolved: %s (%s/%s/%s)'):format(resolvedTownId, tostring(city), tostring(region), tostring(state)))
  end

  local function insertCandidate(playername)
    MySQL.Async.execute('INSERT INTO ballot (character_id, candidate_name, position, city, region, state) VALUES (@character_id, @candidate_name, @position, @city, @region, @state)',
      {
        ['@character_id'] = charId,
        ['@candidate_name'] = playername,
        ['@position'] = position,
        ['@city'] = city,
        ['@region'] = region,
        ['@state'] = state,
      }
    )
    local title = _L('discord_running_title', playername)
    local description = _L('discord_running_desc', playername, position, city, region)
    SendToDiscordWebhook(title,description, 'candidate')
  end
  
  resolveCharacterNameByCharId(charId, fallbackName, function(playername)
    if positionInfo and positionInfo.termlimit > 0 then
      local termLimitQuery, termLimitParams = getTermLimitQueryAndParams(charId, position, state)
      MySQL.query(termLimitQuery, termLimitParams, function(result)
          local count = result[1].count
          if count >= positionInfo.termlimit then
              TriggerClientEvent("vorp:TipBottom", _source, (_L('term_limit_reached', positionInfo.termlimit, position)), 6000)
          else
              -- Continue to add to ballot
              insertCandidate(playername)
          end
      end)
    else
        -- No term limit, just add to ballot
        insertCandidate(playername)
    end
  end)
end)

local function isElectionOfficial(identifier)
  for _, official in ipairs(Config.ElectionOfficials) do
      if official == identifier then
          return true
      end
  end
  return false
end

RegisterServerEvent('cleanupScript')
AddEventHandler('cleanupScript', function(state)
  local _source = source
  local user = VorpCore.getUser(_source)
  if getUserGroup(user) == 'admin' or isElectionOfficial(getUserJob(user)) then
    MySQL.Async.execute('DELETE from Ballot WHERE state = @state', {['@state'] = state})
    MySQL.Async.execute('DELETE from Ballot_votes WHERE state = @state', {['@state'] = state})
    MySQL.Async.execute('DELETE from ballot_registration WHERE state = @state', {['@state'] = state})
    TriggerClientEvent("vorp:TipBottom", _source, ('Cleanup Processing for'..state), 4000)
  else
    TriggerClientEvent("vorp:TipBottom", _source, (_L('no_election_officials')), 4000)
  end
end)


VORP.addNewCallBack("democracy:getCandidates", function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)
  local charId = (user.getUsedCharacter).charIdentifier
  local city = params.city
  local region = params.region
  local position = params.position
  local boothTownId = tostring(params.townId or '')
  if not isPositionActive(position) then
      cb({})
      return
  end

  local jurisdiction = params.jurisdiction
  local state = params.state
  local boothLocation = findVotingLocationByTownId(boothTownId)
  local boothRegion = boothLocation and boothLocation.region or nil
  local canRun, _ = canRunForPosition(charId, boothTownId, state, boothRegion, jurisdiction)
  if not canRun then
    cb({})
    return
  end
 
  local query, queryParams

    if jurisdiction == "state" then
      query = 'SELECT b.character_id as cid, COALESCE(NULLIF(TRIM(CONCAT(COALESCE(c.firstname, ""), " ", COALESCE(c.lastname, ""))), ""), b.candidate_name) as name, b.id as ballotID FROM ballot b LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE b.position=@position and b.state=@state'
      queryParams = { ['@position'] = position, ['@state'] = state }
    elseif jurisdiction == "county" then
      query = 'SELECT b.character_id as cid, COALESCE(NULLIF(TRIM(CONCAT(COALESCE(c.firstname, ""), " ", COALESCE(c.lastname, ""))), ""), b.candidate_name) as name, b.id as ballotID FROM ballot b LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE b.position=@position and b.region=@region and b.state=@state'
      queryParams = { ['@position'] = position, ['@region'] = region, ['@state'] = state }
  elseif jurisdiction == "local" then
      query = 'SELECT b.character_id as cid, COALESCE(NULLIF(TRIM(CONCAT(COALESCE(c.firstname, ""), " ", COALESCE(c.lastname, ""))), ""), b.candidate_name) as name, b.id as ballotID FROM ballot b LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE b.position=@position and b.city=@city'
      queryParams = { ['@position'] = position, ['@city'] = city }
  end
  MySQL.query(query, queryParams, function(result)
      cb(result)
  end)
end)

VORP.addNewCallBack('democracy:hasvotervotedalready', function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)
  local charId = (user.getUsedCharacter).charIdentifier
  local city = params.city
  local region = params.region
  local position = params.position
  local jurisdiction = params.jurisdiction
  local state = params.state

  local query, queryParams

    if jurisdiction == "state" then
      query = 'SELECT * from ballot_votes WHERE office=@position and state=@state and voterID = @charid'
      queryParams = { ['@position'] = position, ['@state'] = state,['@charid'] = charId  }
    elseif jurisdiction == "county" then
      query = 'SELECT * from ballot_votes WHERE office=@position and location=@region and state=@state and voterID = @charid'
      queryParams = { ['@position'] = position, ['@region'] = region, ['@state'] = state, ['@charid'] = charId }
  elseif jurisdiction == "local" then
      query = 'SELECT * from ballot_votes WHERE office=@position and location=@city and voterID = @charid'
      queryParams = { ['@position'] = position, ['@city'] = city, ['@charid'] = charId  }
  end
  MySQL.query(query, queryParams, function(result)
     -- Check if there is at least one row in the result
     local hasVoted = #result > 0
     print("has voted", hasVoted)
     cb(hasVoted)
      
  end)
end)

local function buildVoteLookupQuery(jurisdiction, position, city, region, state, charId)
  local query
  local queryParams

  if jurisdiction == "state" then
    query = 'SELECT voteID FROM ballot_votes WHERE office=@position AND state=@state AND voterID=@charid LIMIT 1'
    queryParams = { ['@position'] = position, ['@state'] = state, ['@charid'] = charId }
  elseif jurisdiction == "county" then
    query = 'SELECT voteID FROM ballot_votes WHERE office=@position AND location=@region AND state=@state AND voterID=@charid LIMIT 1'
    queryParams = { ['@position'] = position, ['@region'] = region, ['@state'] = state, ['@charid'] = charId }
  else
    query = 'SELECT voteID FROM ballot_votes WHERE office=@position AND location=@city AND voterID=@charid LIMIT 1'
    queryParams = { ['@position'] = position, ['@city'] = city, ['@charid'] = charId }
  end

  return query, queryParams
end


RegisterServerEvent('addNewVote')
AddEventHandler('addNewVote', function(city, region, position, jurisdiction, candidateid, ballotid, state)
  local _source = source
  if not isPositionActive(position) then
    TriggerClientEvent("vorp:TipBottom", _source, (_L('elections_not_active')), 4000)
    return
  end

  local user = VorpCore.getUser(_source) 
  local Character = VorpCore.getUser(_source).getUsedCharacter
  local playername = Character.firstname .. ' ' .. Character.lastname
  local charId = user.getUsedCharacter.charIdentifier
  local location
  
  local query, queryParams
  if jurisdiction =="state" then
      location = state
  elseif jurisdiction =="county" then
      location = region
  elseif jurisdiction =="local" then
    location = city
  end
  
  local lookupQuery, lookupParams = buildVoteLookupQuery(jurisdiction, position, city, region, state, charId)
  MySQL.single(lookupQuery, lookupParams, function(existingVote)
    if existingVote then
      TriggerClientEvent("vorp:TipBottom", _source, (_L('vote_already_cast_locked')), 4000)
      return
    end

    query = 'INSERT INTO ballot_votes (voterID, ballotID, office, jurisdiction, location, state) VALUES (@voterID, @ballotID, @position, @jurisdiction, @location, @state) '
    queryParams = {['@voterID'] = charId, ['@ballotID'] =ballotid, ['@position'] = position, ['@jurisdiction'] = jurisdiction, ['@location'] = location, ['@state'] = state }
    MySQL.Async.execute(query, queryParams)

    local title = _L('discord_voted_title', playername)
    local description = _L('discord_voted_desc', playername, position, location)
    SendToDiscordWebhook(title,description, 'activity')
  end)
end)


RegisterServerEvent('updateVote')
AddEventHandler('updateVote', function(city, region, position, jurisdiction, candidateid, ballotid, state)
  local _source = source
  TriggerClientEvent("vorp:TipBottom", _source, (_L('vote_already_cast_locked')), 4000)
end)


RegisterServerEvent('openelectionresultsmenu')
AddEventHandler('openelectionresultsmenu', function()
  openElectionResultsFor(source)
end)


VORP.addNewCallBack("democracy:getResults", function(source, cb, params)
  local _source = source
  local user = VorpCore.getUser(_source)
  local charId = (user.getUsedCharacter).charIdentifier
  local position = params.position
  local location = params.location
  local jurisdiction = params.jurisdiction
  local state = params.state
  local query, queryParams
    local candidateNameExpr = 'COALESCE(NULLIF(TRIM(CONCAT(COALESCE(c.firstname, ""), " ", COALESCE(c.lastname, ""))), ""), b.candidate_name)'

  if jurisdiction == "state" then
      query = 'SELECT COUNT(voteID) as votes, ' .. candidateNameExpr .. ' as candidate_name, b.position, b.city, b.region FROM ballot b ' ..
        'LEFT JOIN ballot_votes v ON b.id = v.ballotID LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE POSITION = @position AND b.state = @state ' ..
        'GROUP BY b.id, v.office, b.region, b.city, b.state ORDER BY votes DESC'
    queryParams = { ['@position'] = position, ['@state'] = location }
  elseif jurisdiction == "county" then
      query = 'SELECT COUNT(voteID) as votes, ' .. candidateNameExpr .. ' as candidate_name, b.position, b.city, b.region FROM ballot b ' ..
        'LEFT JOIN ballot_votes v ON b.id = v.ballotID LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE POSITION = @position AND b.region = @region AND b.state = @state ' ..
        'GROUP BY b.id, v.office, b.region, b.city, b.state ORDER BY votes DESC'
    queryParams = { ['@position'] = position, ['@region'] = location, ['@state'] = state }
  elseif jurisdiction == "local" then
      query = 'SELECT COUNT(voteID) as votes, ' .. candidateNameExpr .. ' as candidate_name, b.position, b.city, b.region FROM ballot b ' ..
        'LEFT JOIN ballot_votes v ON b.id = v.ballotID LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE POSITION = @position AND b.city = @city ' ..
        'GROUP BY b.id, v.office, b.region, b.city ORDER BY votes DESC'
    queryParams = { ['@position'] = position, ['@city'] = location }
  end

    MySQL.query(query, queryParams, function(result)
    cb(result)
  end)
end)

local function SendDiscordViaHttp(webhook, title, description, color, name, logo)
  local embedColor = tonumber(color) or 16711680
  local payload = {
    username = name or "Election Bot",
    avatar_url = logo or "",
    embeds = {
      {
        title = tostring(title or "Election Update"),
        description = tostring(description or ""),
        color = embedColor,
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ")
      }
    }
  }

  PerformHttpRequest(webhook, function(statusCode, _, _)
    if statusCode ~= 204 and statusCode ~= 200 then
      print(("[democracy] Discord webhook request failed with status %s"):format(tostring(statusCode)))
    end
  end, "POST", json.encode(payload), { ["Content-Type"] = "application/json" })
end

local function resolveWebhookByCategory(category)
  local webhooks = Config.Webhooks or {}
  local primary = webhooks.URL
  local candidate = webhooks.CandidateURL
  local results = webhooks.ResultsURL
  local activity = webhooks.ActivityURL

  if category == 'candidate' and candidate and candidate ~= '' then
    return candidate
  end

  if category == 'results' and results and results ~= '' then
    return results
  end

  if category == 'activity' and activity and activity ~= '' then
    return activity
  end

  return primary
end

function SendToDiscordWebhook(title, description, category)
  local webhook = resolveWebhookByCategory(category)
  local color = Config.Webhooks.Color
  local name = Config.Webhooks.WebhookName
  local logo = Config.Webhooks.WebhookLogo

  if not webhook or webhook == '' then
    return
  end

  if VORP and type(VORP.AddWebhook) == 'function' then
    local ok = pcall(VORP.AddWebhook, title, webhook, description, color, name, logo)
    if ok then
      TriggerEvent('democracy:webhook:sent', category or 'default', title, webhook)
      return
    end
  end

  SendDiscordViaHttp(webhook, title, description, color, name, logo)
  TriggerEvent('democracy:webhook:sent', category or 'default', title, webhook)
end

-- ELECTION CYCLE AUTOMATION
Citizen.CreateThread(function()
    while true do
        -- Wait for one hour
        Citizen.Wait(60 * 60 * 1000)

        if Config.ElectionCycle.Enabled then
            local currentHour = os.date('*t').hour
            if currentHour == Config.ElectionCycle.HourToRun then
                -- It's time to process the elections
                ProcessElectionCycles()
            end
        end
    end
end)

function ProcessElectionCycles()
    -- Get all unique states from the voting locations
    local states = {}
    for _, location in ipairs(Config.VotingLocations) do
        states[location.state] = true
    end

    for state, _ in pairs(states) do
        ProcessStateElection(state)
    end
end

function ProcessStateElection(state)
    -- Check the last election cycle for this state
  MySQL.single('SELECT id, state, UNIX_TIMESTAMP(start_time) as start_unix, end_time FROM election_cycles WHERE state = ? ORDER BY start_time DESC LIMIT 1', {state}, function(lastCycle)
      local currentDate = os.date('*t')
      local startWeekday = tonumber(Config.ElectionCycle.StartWeekday or 6) or 6
      local shouldStartNow = currentDate.wday == startWeekday and currentDate.hour == Config.ElectionCycle.HourToRun

      if not lastCycle or lastCycle.end_time ~= nil then
        if shouldStartNow then
          StartNewElectionCycle(state)
        end
        return
      end

      -- An active election cycle exists. Check if it's time to end it.
      local cycleStartUnix = tonumber(lastCycle.start_unix) or 0
      local daysPassed = (os.time() - cycleStartUnix) / (24 * 60 * 60)

      if daysPassed >= Config.ElectionCycle.DurationDays then
        EndElectionCycle(state, lastCycle.id)
      end
  end)
end

function StartNewElectionCycle(state)
    MySQL.Async.execute('INSERT INTO election_cycles (state) VALUES (@state)', {['@state'] = state}, function()
        print("Started a new election cycle for " .. state)
    end)
end

local function getTermForPosition(posName)
  for _, p in ipairs(Config.Positions) do
    if p.name == posName then
      return p.term
    end
  end
  return 0
end

local function getPositionsInState(state)
  local positionsInState = {}
  for _, pos in ipairs(Config.Positions) do
    for _, s in ipairs(pos.states) do
      if s == state then
        table.insert(positionsInState, pos)
        break
      end
    end
  end
  return positionsInState
end

local function getAllElectionStates()
  local states = {}
  local seen = {}
  for _, location in ipairs(Config.VotingLocations) do
    if not seen[location.state] then
      seen[location.state] = true
      table.insert(states, location.state)
    end
  end
  return states
end

local function findOnlinePlayerByCharId(charId)
  for _, src in ipairs(GetPlayers()) do
    local sourceNum = tonumber(src)
    local user = VorpCore.getUser(sourceNum)
    if user and user.getUsedCharacter and user.getUsedCharacter.charIdentifier then
      if tostring(user.getUsedCharacter.charIdentifier) == tostring(charId) then
        return sourceNum, user
      end
    end
  end
  return nil, nil
end

local function getWinnerJobName(position)
  local cfg = Config.WinnerJobAssignment or {}
  local map = cfg.PositionToJob or {}
  if map[position] then
    return map[position]
  end

  local fallback = string.lower(position):gsub('[^%w]+', '_')
  fallback = fallback:gsub('_+', '_'):gsub('^_', ''):gsub('_$', '')
  return fallback
end

local function assignWinnerOfficeJob(winner, state)
  local cfg = Config.WinnerJobAssignment or {}
  if cfg.Enabled == false then
    return
  end

  local jobName = getWinnerJobName(winner.position)
  local grade = tonumber(cfg.DefaultGrade or 0) or 0
  local jobLabel = winner.position

  local function persistMultiJobToDatabase(charId)
    if cfg.AssignOfflineMultiJob == false then
      return
    end

    MySQL.single('SELECT multijobs FROM characters WHERE charidentifier = ? LIMIT 1', { charId }, function(row)
      if not row then
        return
      end

      local parsed = {}
      if row.multijobs and row.multijobs ~= '' then
        local ok, decoded = pcall(json.decode, row.multijobs)
        if ok and type(decoded) == 'table' then
          parsed = decoded
        end
      end

      parsed[jobName] = {
        grade = grade,
        label = jobLabel
      }

      MySQL.Async.execute('UPDATE characters SET multijobs = ? WHERE charidentifier = ?', { json.encode(parsed), charId })
    end)
  end

  local sourceNum, user = findOnlinePlayerByCharId(winner.character_id)
  if not sourceNum or not user then
    persistMultiJobToDatabase(winner.character_id)
    return
  end

  local character = user.getUsedCharacter
  local assigned = false

  if cfg.UseMultiJob and character and type(character.setMultiJob) == 'function' then
    local ok = pcall(character.setMultiJob, jobName, grade, jobLabel)
    assigned = ok
  end

  -- Optional hook for external multi-job resources.
  if cfg.UseMultiJob then
    TriggerEvent('democracy:assignWinnerJob', sourceNum, winner.character_id, winner.position, state, jobName, grade, assigned)
  end

  if cfg.EquipWinnerJob and character then
    if type(character.setJob) == 'function' then
      pcall(character.setJob, jobName)
    end
    if type(character.setJobGrade) == 'function' then
      pcall(character.setJobGrade, grade)
    end
    if type(character.setJobLabel) == 'function' then
      pcall(character.setJobLabel, jobLabel)
    end
  end

  if not assigned then
    persistMultiJobToDatabase(winner.character_id)
  end

  if assigned then
    TriggerClientEvent("vorp:TipBottom", sourceNum, (_L('winner_job_assigned', winner.position, jobName)), 6000)
  end
end

local function formatWinnerScope(winner)
  if winner.scope and winner.scope ~= '' then
    return winner.scope
  end
  return winner.state
end

getPositionJurisdiction = function(position)
  for _, pos in ipairs(Config.Positions or {}) do
    if pos.name == position then
      return string.lower(pos.jurisdiction or "local")
    end
  end
  return "local"
end

local function roundToOneDecimal(value)
  return math.floor((value * 10) + 0.5) / 10
end

local function normalizeScopeKey(value)
  local text = tostring(value or "")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  text = text:gsub("%s+", " ")
  return string.lower(text)
end

local function cleanScopeValue(value)
  local text = tostring(value or "")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  text = text:gsub("%s+", " ")
  return text
end

local function formatRaceScope(position, state, city, region)
  local jurisdiction = getPositionJurisdiction(position)
  if jurisdiction == "state" then
    return cleanScopeValue(state)
  end
  if jurisdiction == "county" then
    return cleanScopeValue(region or state)
  end
  return cleanScopeValue(city or state)
end

local function collectStateRaceResults(state, cb)
  MySQL.query('SELECT b.position, b.state, b.city, b.region, COALESCE(NULLIF(TRIM(CONCAT(COALESCE(c.firstname, ""), " ", COALESCE(c.lastname, ""))), ""), b.candidate_name) as candidate_name, COUNT(v.voteID) as votes FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE b.state = @state GROUP BY b.id ORDER BY b.position ASC, b.region ASC, b.city ASC, votes DESC, candidate_name ASC', { ['@state'] = state }, function(rows)
    cb(rows or {})
  end)
end

local function buildResultsArchiveText(state, raceRows)
  if not raceRows or #raceRows == 0 then
    return _L('discord_results_archive_empty', state)
  end

  local races = {}
  local order = {}
  local overallVotes = 0

  for _, row in ipairs(raceRows or {}) do
    local scope = formatRaceScope(row.position, row.state, row.city, row.region)
    local key = string.format('%s||%s', normalizeScopeKey(row.position), normalizeScopeKey(scope))
    if not races[key] then
      races[key] = {
        position = cleanScopeValue(row.position),
        scope = scope,
        totalVotes = 0,
        candidates = {}
      }
      table.insert(order, key)
    end

    local votes = tonumber(row.votes) or 0
    races[key].totalVotes = races[key].totalVotes + votes
    overallVotes = overallVotes + votes
    table.insert(races[key].candidates, {
      name = row.candidate_name,
      votes = votes
    })
  end

  table.sort(order, function(a, b)
    local left = races[a]
    local right = races[b]
    if left.position == right.position then
      return tostring(left.scope) < tostring(right.scope)
    end
    return tostring(left.position) < tostring(right.position)
  end)

  local lines = {
    _L('discord_results_total_votes', tostring(overallVotes)),
    ''
  }

  for _, key in ipairs(order) do
    local race = races[key]
    table.insert(lines, string.format('%s | %s | %s: %s', race.position, race.scope, _L('nui_votes_suffix'), tostring(race.totalVotes)))

    table.sort(race.candidates, function(a, b)
      if a.votes == b.votes then
        return tostring(a.name) < tostring(b.name)
      end
      return a.votes > b.votes
    end)

    for index, candidate in ipairs(race.candidates) do
      if index > 5 then
        break
      end
      table.insert(lines, string.format('- %s: %s %s', candidate.name, tostring(candidate.votes), _L('nui_votes_suffix')))
    end

    table.insert(lines, '')
  end

  local text = table.concat(lines, '\n')
  if #text > 3900 then
    text = text:sub(1, 3900) .. '\n...'
  end

  return text
end

local function StoreWinner(winner, state)
  local termInMonths = tonumber(winner.term) or 0
  local now = os.time()
    local endDateRaw = os.date('*t', now)
    local termEndDate = now + (termInMonths * 30 * 24 * 60 * 60)

    if type(endDateRaw) == 'table' then
      endDateRaw.month = endDateRaw.month + termInMonths
      termEndDate = os.time(endDateRaw)
    end

    MySQL.Async.execute('INSERT INTO election_winners (character_id, candidate_name, position, state, term_end_date) VALUES (@charId, @name, @pos, @state, FROM_UNIXTIME(@termEnd))',
    {
        ['@charId'] = winner.character_id,
        ['@name'] = winner.candidate_name,
        ['@pos'] = winner.position,
        ['@state'] = state,
        ['@termEnd'] = termEndDate
    })

    assignWinnerOfficeJob(winner, state)
end

  local function collectStateWinners(state, cb)
    local positionsInState = getPositionsInState(state)
    local winners = {}
    local pending = 0

    local function done()
      if pending == 0 then
        cb(winners)
      end
    end

    for _, positionInfo in ipairs(positionsInState) do
      local jurisdiction = string.lower(positionInfo.jurisdiction)

      if jurisdiction == "state" then
        pending = pending + 1
        MySQL.query('SELECT COUNT(v.voteID) as votes, COALESCE(NULLIF(TRIM(CONCAT(COALESCE(c.firstname, ""), " ", COALESCE(c.lastname, ""))), ""), b.candidate_name) as candidate_name, b.character_id, b.position, b.id as ballot_id FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE b.position = @position and b.state = @state GROUP BY b.id ORDER BY votes DESC LIMIT 1', { ['@position'] = positionInfo.name, ['@state'] = state }, function(rows)
          if rows and #rows > 0 then
            local winner = rows[1]
            winner.term = getTermForPosition(winner.position)
            winner.state = state
            winner.scope = state
            table.insert(winners, winner)
          end
          pending = pending - 1
          done()
        end)
      elseif jurisdiction == "county" then
        pending = pending + 1
        MySQL.query('SELECT DISTINCT region FROM ballot WHERE state = @state AND position = @position', { ['@state'] = state, ['@position'] = positionInfo.name }, function(regions)
          if not regions or #regions == 0 then
            pending = pending - 1
            done()
            return
          end

          local regionPending = #regions
          for _, regionRow in ipairs(regions) do
            MySQL.query('SELECT COUNT(v.voteID) as votes, COALESCE(NULLIF(TRIM(CONCAT(COALESCE(c.firstname, ""), " ", COALESCE(c.lastname, ""))), ""), b.candidate_name) as candidate_name, b.character_id, b.position, b.id as ballot_id FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE b.position = @position AND b.region = @region AND b.state = @state GROUP BY b.id ORDER BY votes DESC LIMIT 1', { ['@position'] = positionInfo.name, ['@region'] = regionRow.region, ['@state'] = state }, function(rows)
              if rows and #rows > 0 then
                local winner = rows[1]
                winner.term = getTermForPosition(winner.position)
                winner.state = state
                winner.scope = regionRow.region
                table.insert(winners, winner)
              end

              regionPending = regionPending - 1
              if regionPending == 0 then
                pending = pending - 1
                done()
              end
            end)
          end
        end)
      else
        pending = pending + 1
        MySQL.query('SELECT DISTINCT city FROM ballot WHERE state = @state AND position = @position', { ['@state'] = state, ['@position'] = positionInfo.name }, function(cities)
          if not cities or #cities == 0 then
            pending = pending - 1
            done()
            return
          end

          local cityPending = #cities
          for _, cityRow in ipairs(cities) do
            MySQL.query('SELECT COUNT(v.voteID) as votes, COALESCE(NULLIF(TRIM(CONCAT(COALESCE(c.firstname, ""), " ", COALESCE(c.lastname, ""))), ""), b.candidate_name) as candidate_name, b.character_id, b.position, b.id as ballot_id FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID LEFT JOIN characters c ON c.charidentifier = b.character_id WHERE b.position = @position AND b.city = @city GROUP BY b.id ORDER BY votes DESC LIMIT 1', { ['@position'] = positionInfo.name, ['@city'] = cityRow.city }, function(rows)
              if rows and #rows > 0 then
                local winner = rows[1]
                winner.term = getTermForPosition(winner.position)
                winner.state = state
                winner.scope = cityRow.city
                table.insert(winners, winner)
              end

              cityPending = cityPending - 1
              if cityPending == 0 then
                pending = pending - 1
                done()
              end
            end)
          end
        end)
      end
    end

    done()
  end

  function EndElectionCycle(state, cycleId)
    print("Ending election cycle for " .. state)

    if cycleId then
      MySQL.Async.execute('UPDATE election_cycles SET end_time = NOW() WHERE id = @id', {['@id'] = cycleId})
    end

    collectStateWinners(state, function(winners)
      for _, winner in ipairs(winners) do
        StoreWinner(winner, state)
      end

      collectStateRaceResults(state, function(raceRows)
        local archiveTitle = _L('discord_results_archive_title', state)
        local archiveDescription = buildResultsArchiveText(state, raceRows)
        SendToDiscordWebhook(archiveTitle, archiveDescription, 'results')
      end)

      MySQL.Async.execute('DELETE FROM ballot WHERE state = @state', {['@state'] = state})
      MySQL.Async.execute('DELETE FROM ballot_votes WHERE state = @state', {['@state'] = state})
      MySQL.Async.execute('DELETE FROM ballot_registration WHERE state = @state', {['@state'] = state})
    end)
  end

  local function handleElectionFinalizeCommand(source, args)
    if not hasElectionControlPermission(source) then
      if source ~= 0 then
        TriggerClientEvent("vorp:TipBottom", source, (_L('no_election_officials')), 4000)
      end
      return
    end

    local target = args and args[1]
    local states = {}

    if target and target ~= '' and string.lower(target) ~= 'all' then
      table.insert(states, target)
    else
      states = getAllElectionStates()
    end

    for _, state in ipairs(states) do
      MySQL.single('SELECT id FROM election_cycles WHERE state = ? ORDER BY start_time DESC LIMIT 1', { state }, function(row)
        EndElectionCycle(state, row and row.id or nil)
      end)
    end

    if source ~= 0 then
      TriggerClientEvent("vorp:TipBottom", source, (_L('election_finalize_started')), 5000)
    end
  end

  RegisterCommand('electionfinalize', function(source, args)
    handleElectionFinalizeCommand(source, args)
  end, false)

  RegisterCommand('wahlenfinalize', function(source, args)
    handleElectionFinalizeCommand(source, args)
  end, false)

RegisterServerEvent('democracy:publishResults')
AddEventHandler('democracy:publishResults', function()
  local _source = source
  handleElectionFinalizeCommand(_source, { 'all' })
end)
