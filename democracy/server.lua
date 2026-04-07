VORP = exports.vorp_core:vorpAPI()
local VorpCore = {}
local ServerRPC = exports.vorp_core:ServerRpcCall() --[[@as ServerRPC]] -- for intellisense
local VORPutils = {}
local Translations = Lang[Config.Lang]

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

  local isAllowed = false
  for k, v in pairs(Config.ElectionOfficials) do
      for _, group in ipairs(v) do
          if group == user.getGroup then
              isAllowed = true
              break
          end
      end
      if isAllowed then
          break
      end
  end
  
  cb(isAllowed)
  


    cb(isAllowed)  

end)



RegisterServerEvent('registerVoter')
AddEventHandler('registerVoter', function(city, region, state)
  local _source = source
  local user = VorpCore.getUser(_source) 
  local Character = VorpCore.getUser(_source).getUsedCharacter
  local charId = user.getUsedCharacter.charIdentifier

MySQL.Async.execute('INSERT INTO ballot_registration (voterID, registrationCity, registrationRegion, state) VALUES (@character_id,  @city, @region, @state)',
  {
    ['@character_id'] = charId,
    ['@voter_name'] = playername,
    ['@city'] = city,
    ['@region'] = region,
    ['@state'] = state
  }
)
end)

RegisterServerEvent('addballotname')
AddEventHandler('addballotname', function(city,region,position, state)
  local _source = source
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
    MySQL.query('SELECT COUNT(*) as count FROM election_winners WHERE character_id = @charId AND position = @pos', {['@charId'] = charId, ['@pos'] = position}, function(result)
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

function isElectionOfficial(identifier)
  for _, official in ipairs(Config.ElectionOfficials) do
      if official[1] == identifier then
          return true
      end
  end
  return false
end

RegisterServerEvent('cleanupScript')
AddEventHandler('cleanupScript', function(state)
  local _source = source
  local user = VorpCore.getUser(_source)
  if user.getGroup() == 'admin' or isElectionOfficial(user.getJob()) then
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
      queryParams = {['@voterID'] = charId, ['@ballotID'] =ballotid, ['@position'] = position, ['jurisdiction'] = jurisdiction,['location'] = location, ['@state'] = state }
      MySQL.Async.execute(query, queryParams)


      local title = _L('discord_voted_title', playername)
      local description = _L('discord_voted_desc', playername, position, location)
      SendToDiscordWebhook(title,description)
end)


RegisterServerEvent('updateVote')
AddEventHandler('updateVote', function(city, region, position, jurisdiction, candidateid, ballotid, state)
  local _source = source
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
      queryParams = {['@ballotid'] =ballotid, ['@voterID'] = charId, ['@position'] = position, ['location'] = location, ['@state'] = state }
      MySQL.Async.execute(query, queryParams)

      local title = _L('discord_changed_vote_title', playername)
      local description = _L('discord_changed_vote_desc', playername, position, location)
      SendToDiscordWebhook(title,description)
      
end)

function isElectionOfficial(identifier)
  for _, official in ipairs(Config.ElectionOfficials) do
      if official[1] == identifier then
          return true
      end
  end
  return false
end


RegisterServerEvent('openelectionresultsmenu')
AddEventHandler('openelectionresultsmenu', function()
    local _source = source
    local user = VorpCore.getUser(_source)
    
    if user.getGroup() == 'admin' or isElectionOfficial(user.getJob()) then
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
    MySQL.single('SELECT * FROM election_cycles WHERE state = ? ORDER BY start_time DESC LIMIT 1', {state}, function(lastCycle)
        if not lastCycle then
            -- No election has ever run for this state, so let's start one.
            StartNewElectionCycle(state)
        else
            -- An election cycle exists. Check if it's time to end it.
            local cycleStartDate = lastCycle.start_time
            local daysPassed = (os.time() - cycleStartDate) / (24 * 60 * 60)

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

function EndElectionCycle(state, cycleId)
    print("Ending election cycle for " .. state)
    -- Update the end_time of the old cycle
    MySQL.Async.execute('UPDATE election_cycles SET end_time = NOW() WHERE id = @id', {['@id'] = cycleId})

    -- Tally results and store winners
    TallyAndStoreWinners(state)

    -- Clean up for the next election
    MySQL.Async.execute('DELETE FROM ballot WHERE state = @state', {['@state'] = state})
    MySQL.Async.execute('DELETE FROM ballot_votes WHERE state = @state', {['@state'] = state})
    MySQL.Async.execute('DELETE FROM ballot_registration WHERE state = @state', {['@state'] = state})
    
    -- Announce the end of the election
    local title = _L('election_ended_title', state)
    local description = _L('election_ended_desc')
    SendToDiscordWebhook(title, description)

    -- Start a new cycle
    StartNewElectionCycle(state)
end

function TallyAndStoreWinners(state)
    print("Tallying and storing winners for " .. state)
    local positionsInState = {}
    for _, pos in ipairs(Config.Positions) do
        for _, s in ipairs(pos.states) do
            if s == state then
                table.insert(positionsInState, pos)
                break
            end
        end
    end

    for _, positionInfo in ipairs(positionsInState) do
        local query, queryParams
        
        local getTerm = function(posName)
            for _,p in ipairs(Config.Positions) do
                if p.name == posName then
                    return p.term
                end
            end
            return 0
        end

        if positionInfo.jurisdiction == "federal" then
             query = 'SELECT COUNT(v.voteID) as votes, b.candidate_name, b.character_id, b.position, b.id as ballot_id FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID WHERE b.position = @position GROUP BY b.id ORDER BY votes DESC LIMIT 1'
             queryParams = { ['@position'] = positionInfo.name }
             
             MySQL.query(query, queryParams, function(winner)
                if winner and #winner > 0 then
                    winner[1].term = getTerm(winner[1].position)
                    StoreWinner(winner[1], state)
                end
            end)
        elseif positionInfo.jurisdiction == "state" then
            query = 'SELECT COUNT(v.voteID) as votes, b.candidate_name, b.character_id, b.position, b.id as ballot_id FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID WHERE b.position = @position and b.state = @state GROUP BY b.id ORDER BY votes DESC LIMIT 1'
            queryParams = { ['@position'] = positionInfo.name, ['@state'] = state }

            MySQL.query(query, queryParams, function(winner)
                if winner and #winner > 0 then
                    winner[1].term = getTerm(winner[1].position)
                    StoreWinner(winner[1], state)
                end
            end)
        elseif positionInfo.jurisdiction == "local" then
            -- For local, we need to determine the winner for each city
             local cities_query = 'SELECT DISTINCT city FROM ballot WHERE state = @state AND position = @position'
             MySQL.query(cities_query, {['@state'] = state, ['@position'] = positionInfo.name}, function(cities)
                for _, cityRow in ipairs(cities) do
                     local city_winner_query = 'SELECT COUNT(v.voteID) as votes, b.candidate_name, b.character_id, b.position, b.id as ballot_id FROM ballot b LEFT JOIN ballot_votes v ON b.id = v.ballotID WHERE b.position = @position AND b.city = @city GROUP BY b.id ORDER BY votes DESC LIMIT 1'
                     MySQL.query(city_winner_query, {['@position'] = positionInfo.name, ['@city'] = cityRow.city}, function(winners)
                        if winners and #winners > 0 then
                            local winner = winners[1]
                            winner.term = getTerm(winner.position)
                            StoreWinner(winner, state)
                        end
                     end)
                end
             end)
        end
    end
end

function StoreWinner(winner, state)
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
end
