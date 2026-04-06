VORP = exports.vorp_core:vorpAPI()
local VorpCore = {}
local ServerRPC = exports.vorp_core:ServerRpcCall() --[[@as ServerRPC]] -- for intellisense
local VORPutils = {}

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
  local title = playername.."is running for office!"
  local description = playername.." entered the race for "..position.." of "..city..", "..region.." in "..state
  SendToDiscordWebhook(title,description)

end)

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
    TriggerClientEvent("vorp:TipBottom", _source, ('Election Officials Only'), 4000)
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


      local title = playername.."has Voted!"
      local description = playername.." voted for  "..position.." of "..location
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

      local title = playername.."changed vote!"
      local description = playername.." voted for  "..position.." of "..location
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
        TriggerClientEvent("vorp:TipBottom", _source, ('Welcome Election Official'), 4000)
        TriggerClientEvent("democracy:openElecResMenu", _source)
    else
        TriggerClientEvent("vorp:TipBottom", _source, ('Election Officials Only'), 4000)
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

