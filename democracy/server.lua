VORP = exports.vorp_core:vorpAPI()
local VorpCore = {}
local ServerRPC = exports.vorp_core:ServerRpcCall()
local VORPutils = {}
local Translations = Lang[Config.Lang]

---@diagnostic disable-next-line: undefined-global
local MySQL = MySQL

function _L(str, ...)
    if Translations[str] then
        return string.format(Translations[str], ...)
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

local ElectionRuntimeState = {
  Active = Config.ElectionBoothsActiveOnStart == true,
  ActivePositions = {}
}

local function getAllPositionNames()
  local names = {}
  for _, pos in ipairs(Config.Positions) do
    table.insert(names, pos.name)
  end
  return names
end

ElectionRuntimeState.ActivePositions = getAllPositionNames()

local function hasElectionControlPermission(source)
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

local function setElectionActive(active, selectedPositions)
  ElectionRuntimeState.Active = active == true
  if ElectionRuntimeState.Active then
    ElectionRuntimeState.ActivePositions = normalizeSelectedPositions(selectedPositions)
  end

  TriggerClientEvent('democracy:setElectionActive', -1, ElectionRuntimeState.Active, cloneArray(ElectionRuntimeState.ActivePositions))
end

VORP.addNewCallBack('democracy:getElectionActive', function(source, cb)
  cb({
    active = ElectionRuntimeState.Active,
    positions = cloneArray(ElectionRuntimeState.ActivePositions)
  })
end)

RegisterServerEvent('democracy:applyElectionSetup')
AddEventHandler('democracy:applyElectionSetup', function(selectedPositions)
  local _source = source
  if not hasElectionControlPermission(_source) then
    TriggerClientEvent("vorp:TipBottom", _source, (_L('no_election_officials')), 4000)
    return
  end

  setElectionActive(true, selectedPositions)
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

    TriggerClientEvent('democracy:openElectionSetup', source, positions, cloneArray(ElectionRuntimeState.ActivePositions))
    return
  end

  setElectionActive(active, ElectionRuntimeState.ActivePositions)

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
AddEventHandler('registerVoter', function(city, region, state)
  local _source = source
  local user = VorpCore.getUser(_source) 
  local Character = VorpCore.getUser(_source).getUsedCharacter
  local charId = user.getUsedCharacter.charIdentifier

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
AddEventHandler('addballotname', function(city,region,position, state)
  local _source = source
  if not isPositionActive(position) then
    TriggerClientEvent("vorp:TipBottom", _source, (_L('elections_not_active')), 4000)
    return
  end

  local user = VorpCore.getUser(_source) 
  local Character = VorpCore.getUser(_source).getUsedCharacter
  local playername = Character.firstname .. ' ' .. Character.lastname
  local charId = user.getUsedCharacter.charIdentifier
  
  local positionInfo
  for _, pos in ipairs(Config.Positions) do
    if pos.name == position then
        positionInfo = pos
        break
    end
  end

  if positionInfo and positionInfo.termlimit > 0 then
    local termLimitQuery, termLimitParams = getTermLimitQueryAndParams(charId, position, state)
    MySQL.query(termLimitQuery, termLimitParams, function(result)
        local count = result[1].count
        if count >= positionInfo.termlimit then
            TriggerClientEvent("vorp:TipBottom", _source, (_L('term_limit_reached', positionInfo.termlimit, position)), 6000)
        else
            -- Continue to add to ballot
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
          SendToDiscordWebhook(title,description)
        end
    end)
  else
      -- No term limit, just add to ballot
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
      SendToDiscordWebhook(title,description)
  end
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
  if not isPositionActive(position) then
      cb({})
      return
  end

  local jurisdiction = params.jurisdiction
  local state = params.state
 
  local query, queryParams

  if jurisdiction == "federal" then
      query = 'SELECT character_id as cid, candidate_name as name, id as ballotID  FROM ballot WHERE position=@position'
      queryParams = { ['@position'] = position }
  elseif jurisdiction == "state" then
      query = 'SELECT character_id as cid, candidate_name as name , id as ballotID FROM ballot WHERE position=@position and state=@state'
      queryParams = { ['@position'] = position, ['@state'] = state }
  elseif jurisdiction == "local" then
      query = 'SELECT character_id as cid, candidate_name as name , id as ballotID FROM ballot WHERE position=@position and city=@city'
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

  if jurisdiction == "federal" then
      query = 'SELECT * from ballot_votes where office = @position and voterID = @charid '
      queryParams = { ['@position'] = position, ['@charid'] = charId }
  elseif jurisdiction == "state" then
      query = 'SELECT * from ballot_votes WHERE office=@position and state=@state and voterID = @charid'
      queryParams = { ['@position'] = position, ['@state'] = state,['@charid'] = charId  }
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
  if jurisdiction == "federal" then
      location="federal"
  elseif jurisdiction =="state" then
      location = state
  elseif jurisdiction =="local" then
    location = city
  end
  
      query = 'INSERT INTO ballot_votes (voterID, ballotID, office, jurisdiction, location, state) VALUES (@voterID, @ballotID, @position, @jurisdiction, @location, @state) '
      queryParams = {['@voterID'] = charId, ['@ballotID'] =ballotid, ['@position'] = position, ['@jurisdiction'] = jurisdiction, ['@location'] = location, ['@state'] = state }
      MySQL.Async.execute(query, queryParams)


      local title = _L('discord_voted_title', playername)
      local description = _L('discord_voted_desc', playername, position, location)
      SendToDiscordWebhook(title,description)
end)


RegisterServerEvent('updateVote')
AddEventHandler('updateVote', function(city, region, position, jurisdiction, candidateid, ballotid, state)
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
  if jurisdiction == "federal" then
      location="federal"
  elseif jurisdiction =="state" then
      location = state
  elseif jurisdiction =="local" then
    location = city
  end
  
      query = 'Update ballot_votes set ballotID = @ballotid where voterID= @voterID AND office= @position and location = @location and state = @state'
      queryParams = {['@ballotid'] =ballotid, ['@voterID'] = charId, ['@position'] = position, ['@location'] = location, ['@state'] = state }
      MySQL.Async.execute(query, queryParams)

      local title = _L('discord_changed_vote_title', playername)
      local description = _L('discord_changed_vote_desc', playername, position, location)
      SendToDiscordWebhook(title,description)
      
    end)


RegisterServerEvent('openelectionresultsmenu')
AddEventHandler('openelectionresultsmenu', function()
    local _source = source
    local user = VorpCore.getUser(_source)
    
  if getUserGroup(user) == 'admin' or isElectionOfficial(getUserJob(user)) then
        TriggerClientEvent("vorp:TipBottom", _source, (_L('welcome_election_official')), 4000)
        TriggerClientEvent("democracy:openElecResMenu", _source)
    else
        TriggerClientEvent("vorp:TipBottom", _source, (_L('no_election_officials')), 4000)
    end
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

  if jurisdiction == "federal" then
    query = 'SELECT COUNT(voteID) as votes, candidate_name, b.position FROM ballot b ' ..
            'LEFT JOIN ballot_votes v ON b.id = v.ballotID WHERE POSITION = @position ' ..
            'GROUP BY candidate_name, v.office, jurisdiction, location, region, city ORDER BY votes DESC'
    queryParams = { ['@position'] = position }
  elseif jurisdiction == "state" then
    query = 'SELECT COUNT(voteID) as votes, candidate_name, b.position, b.city, b.region FROM ballot b ' ..
            'LEFT JOIN ballot_votes v ON b.id = v.ballotID WHERE POSITION = @position AND b.state = @state ' ..
            'GROUP BY candidate_name, v.office, region, city, b.state ORDER BY votes DESC'
    queryParams = { ['@position'] = position, ['@state'] = location }
  elseif jurisdiction == "local" then
    query = 'SELECT COUNT(voteID) as votes, candidate_name, b.position, b.city, b.region FROM ballot b ' ..
            'LEFT JOIN ballot_votes v ON b.id = v.ballotID WHERE POSITION = @position AND city = @city ' ..
            'GROUP BY candidate_name, v.office, region, city ORDER BY votes DESC'
    queryParams = { ['@position'] = position, ['@city'] = location }
  end

    MySQL.query(query, queryParams, function(result)
    cb(result)
  end)
end)

 function SendToDiscordWebhook(title, description)
  local webhook = Config.Webhooks.URL
  local color = Config.Webhooks.Color
  local name = Config.Webhooks.WebhookName
  local logo = Config.Webhooks.WebhookLogo
  if webhook and webhook ~= '' then
    VORP.AddWebhook(title, webhook, description, color, name, logo)
  end
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
  MySQL.single('SELECT id, state, UNIX_TIMESTAMP(start_time) as start_unix FROM election_cycles WHERE state = ? ORDER BY start_time DESC LIMIT 1', {state}, function(lastCycle)
        if not lastCycle then
            -- No election has ever run for this state, so let's start one.
            StartNewElectionCycle(state)
        else
            -- An election cycle exists. Check if it's time to end it.
      local cycleStartUnix = tonumber(lastCycle.start_unix) or 0
      local daysPassed = (os.time() - cycleStartUnix) / (24 * 60 * 60)

            if daysPassed >= Config.ElectionCycle.DurationDays then
                -- End the current election and start a new one
                EndElectionCycle(state, lastCycle.id)
            end
        end
    end)
end

function StartNewElectionCycle(state)
    MySQL.Async.execute('INSERT INTO election_cycles (state) VALUES (@state)', {['@state'] = state}, function()
        print("Started a new election cycle for " .. state)
        -- Announce the start of a new election
        local title = _L('new_election_started_title', state)
        local description = _L('new_election_started_desc')
        SendToDiscordWebhook(title, description)
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

local function buildResultsArchiveText(state, winners)
  if not winners or #winners == 0 then
    return _L('discord_results_archive_empty', state)
  end

  table.sort(winners, function(a, b)
    if a.position == b.position then
      return (tonumber(a.votes) or 0) > (tonumber(b.votes) or 0)
    end
    return a.position < b.position
  end)

  local lines = {}
  for _, winner in ipairs(winners) do
    table.insert(lines, string.format('%s | %s | %s | %s: %s', winner.position, winner.candidate_name, formatWinnerScope(winner), _L('nui_votes_suffix'), tostring(winner.votes or 0)))
  end

  return table.concat(lines, '\n')
end

local function StoreWinner(winner, state)
    local termInWeeks = winner.term
    -- term in weeks from config
    local termInSeconds = tonumber(termInWeeks) * 7 * 24 * 60 * 60
    local termEndDate = os.time() + termInSeconds

    MySQL.Async.execute('INSERT INTO election_winners (character_id, candidate_name, position, state, term_end_date) VALUES (@charId, @name, @pos, @state, FROM_UNIXTIME(@termEnd))',
    {
        ['@charId'] = winner.character_id,
        ['@name'] = winner.candidate_name,
        ['@pos'] = winner.position,
        ['@state'] = state,
        ['@termEnd'] = termEndDate
    })

    local title = _L('winner_announcement_title', winner.candidate_name, winner.position, state)
    local description = _L('winner_announcement_desc', termInWeeks)
    SendToDiscordWebhook(title, description)
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

      if jurisdiction == "federal" then
        pending = pending + 1
        MySQL.query('SELECT COUNT(v.voteID) as votes, b.candidate_name, b.character_id, b.position, b.id as ballot_id FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID WHERE b.position = @position GROUP BY b.id ORDER BY votes DESC LIMIT 1', { ['@position'] = positionInfo.name }, function(rows)
          if rows and #rows > 0 then
            local winner = rows[1]
            winner.term = getTermForPosition(winner.position)
            winner.state = state
            winner.scope = "federal"
            table.insert(winners, winner)
          end
          pending = pending - 1
          done()
        end)
      elseif jurisdiction == "state" then
        pending = pending + 1
        MySQL.query('SELECT COUNT(v.voteID) as votes, b.candidate_name, b.character_id, b.position, b.id as ballot_id FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID WHERE b.position = @position and b.state = @state GROUP BY b.id ORDER BY votes DESC LIMIT 1', { ['@position'] = positionInfo.name, ['@state'] = state }, function(rows)
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
            MySQL.query('SELECT COUNT(v.voteID) as votes, b.candidate_name, b.character_id, b.position, b.id as ballot_id FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID WHERE b.position = @position AND b.city = @city GROUP BY b.id ORDER BY votes DESC LIMIT 1', { ['@position'] = positionInfo.name, ['@city'] = cityRow.city }, function(rows)
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

      local archiveTitle = _L('discord_results_archive_title', state)
      local archiveDescription = buildResultsArchiveText(state, winners)
      SendToDiscordWebhook(archiveTitle, archiveDescription)

      MySQL.Async.execute('DELETE FROM ballot WHERE state = @state', {['@state'] = state})
      MySQL.Async.execute('DELETE FROM ballot_votes WHERE state = @state', {['@state'] = state})
      MySQL.Async.execute('DELETE FROM ballot_registration WHERE state = @state', {['@state'] = state})

      local title = _L('election_ended_title', state)
      local description = _L('election_ended_desc')
      SendToDiscordWebhook(title, description)

      StartNewElectionCycle(state)
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
