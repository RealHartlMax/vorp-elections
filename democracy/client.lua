local VORPcore = {} -- core object
local Translations = Lang[Config.Lang]

function _L(str, ...)
    if Translations[str] then
        return string.format(Translations[str], ...)
    else
        print('Translation not found in client: ' .. str)
        return 'Translation not found: ' .. str
    end
end

TriggerEvent("getCore", function(core)
    VORPcore = core
end)
local VORPMenu = {}

TriggerEvent("vorp_menu:getData",function(cb)
    VORPMenu = cb
   end)

--Following Thread looks for ped in radius of voting locations the in config and offers G for menu
Citizen.CreateThread(function()
    while true do
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        
        for k, v in pairs(Config.VotingLocations) do 
            local distance = GetDistanceBetweenCoords(coords, v.coords.x, v.coords.y, v.coords.z, true)
            
            if distance < 10.0 then
                DrawTxt(_L('press_to_vote'), 0.50, 0.85, 0.7, 0.7, true, 255, 255, 255, 255, true)
                
                if IsControlJustReleased(0, 0x760A9C6F) then
                    local city = v.city 
                    local region = v.region
                    local state = v.state
                    TriggerEvent('democracy:votingbooth',city, region, state)   
                    Citizen.Wait(1000)
                end
            end
        end
        
        Citizen.Wait(1000)
    end
end)

RegisterNetEvent('democracy:votingbooth')
AddEventHandler('democracy:votingbooth', function(city, region, state)
    local vcity = city
    local vregion = region
    local vstate = state
    local onBallot = false
    --Check if on ballot anywhere
    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:checkonballot", function(cb)
        onBallot = cb
        print("onBallot: ",onBallot)

    -- Check if registered
    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:checkRegistration", function(cb)
    
        local result = cb
       
        
        if result then
            print("Player is registered.")
            OpenStartMenu(true, vcity, vregion, onBallot, vstate)
        else
            print("Player is not registered.")
            local button = _L('register_to_vote_prompt', vcity)
            local placeholder = _L('placeholder_yes_no')

            TriggerEvent("vorpinputs:getInput", button, placeholder, function(answer)
                print("User input received:", answer)
                if answer == "y" or answer == "Y" or answer == "j" or answer == "J" then
                    TriggerServerEvent('registerVoter', vcity, vregion, vstate)
                    TriggerEvent("vorp:TipBottom", (_L('player_registered', vcity)), 4000)
                    OpenStartMenu(true, vcity, vregion,onBallot, vstate)
                else
                    TriggerEvent("vorp:TipBottom", (_L('player_not_want_vote')), 4000)
                    OpenStartMenu(false,vcity,vregion,onBallot, vstate)
                end
            end)
        end
    end, { city = vcity, region = vregion })
end)
end)

function OpenStartMenu(registered, city, region, onBallot, state)
    VORPMenu.CloseAll()
    local menuElements = {
        { label = _L('menu_exit'), value = "exit_menu", desc = "Close Menu" },
    }
    local addMenuElement
    if registered then
        addMenuElement = { label = _L('vote_in_label', city, region), value = "vote", desc = "Vote" }
        table.insert(menuElements, 1, addMenuElement)
    end
    if onBallot then
        addMenuElement = { label = _L('stop_running_for_office'), value = "stoprunning", desc = "Remove yourself from running for office" }
        table.insert(menuElements, 1, addMenuElement)
    else 
        addMenuElement = { label = _L('run_for_office'), value = "run", desc = "Run for office" }
        table.insert(menuElements, 1, addMenuElement)
    end

    -- Open the menu using VORPMenu
    VORPMenu.Open(
        "default",
        GetCurrentResourceName(),
        "votingmenu",
        {
            title = _L('vote_menu_title', city),
            subtext = _L('vote_menu_subtext', state),
            align = "top-center",
            elements = menuElements,
            itemHeight = "4vh",
        },
        function(data, menu)
            if data.current.value == "vote" then
                OpenVoteMenu(registered, city, region, onBallot, state)
            elseif data.current.value == "stoprunning" then 
                TriggerEvent("democracy:stoprunning")
                menu.close()
            elseif data.current.value == "run" then
                OpenRunMenu(registered, city, region, onBallot, state)
            elseif data.current.value == "exit_menu" then
                print("close")
                menu.close()
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end

function OpenRunMenu(registered, city, region, onBallot, state)
    VORPMenu.CloseAll()
    local vcity = city
    local vregion = region
    local vstate = state
    local menuElements = {}
    
    local addMenuElement
    for k,v in pairs(Config.Positions) do
        for i, s in ipairs(v.states) do
            if s == vstate then
                addMenuElement ={ label = v.name, value = v.name, desc = _L('run_for_office_desc', v.jurisdiction) }
                table.insert(menuElements, addMenuElement)
            end
        end
    end
    addMenuElement= { label = _L('menu_main'), value = "back", desc = "Back to Main Menu" }
    table.insert(menuElements,addMenuElement)
    addMenuElement = { label = _L('menu_exit'), value = "exit_menu", desc = "Close Menu" }
    table.insert(menuElements,addMenuElement)
    
   
    -- Open the menu using VORPMenu
    VORPMenu.Open(
        "default",
        GetCurrentResourceName(),
        "runmenu",
        {
            title = _L('run_menu_title'),
            subtext = _L('run_menu_subtext', vcity, vregion),
            align = "top-center",
            elements = menuElements,
            itemHeight = "4vh",
        },
        function(data, menu)
            if data.current.value == "back" then
                OpenStartMenu(registered, city, region, onBallot, state)
            elseif data.current.value == "exit_menu" then
                print("close")
                menu.close()
            else
                TriggerServerEvent('addballotname', vcity, vregion, data.current.value, vstate)
                local message = _L('you_are_on_ballot', data.current.value)
                TriggerEvent("vorp:TipBottom", (message), 4000)
                local nowonBallot = true
                menu.close()
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end

function OpenVoteMenu(registered, city, region, onBallot, state)
    VORPMenu.CloseAll()
    local vcity = city
    local vregion = region
    local vstate = state
    local menuElements = {}
    
    local addMenuElement
    for k,v in pairs(Config.Positions) do
        addMenuElement ={ label = v.name, value = v.name, desc = _L('vote_for_label', v.name) }
        table.insert(menuElements, addMenuElement)  
    end
    addMenuElement= { label = _L('menu_main'), value = "back", desc = "Back to Main Menu" }
    table.insert(menuElements,addMenuElement)
    addMenuElement = { label = _L('menu_exit'), value = "exit_menu", desc = "Close Menu" }
    table.insert(menuElements,addMenuElement)
    
   
    -- Open the menu using VORPMenu
    VORPMenu.Open(
        "default",
        GetCurrentResourceName(),
        "votemenu",
        {
            title = _L('vote_menu_title_short'),
            subtext = _L('vote_menu_subtext_short', vcity, vregion),
            align = "top-center",
            elements = menuElements,
            itemHeight = "4vh",
        },
        function(data, menu)
            if data.current.value == "back" then
                OpenStartMenu(registered, city, region, onBallot, state)
            elseif data.current.value == "exit_menu" then
                print("close")
                menu.close()
            else               
                --Open Candidate Menu
                OpenCandidatesMenu(registered,city,region,data.current.value,onBallot, state)

            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end

function OpenCandidatesMenu(registered, city, region, position, onBallot, state)
    VORPMenu.CloseAll()
    local vcity = city
    local vregion = region
    local vstate = state
    local position = position
    local menuElements = {}
    local addMenuElement
    local jurisdiction

    for k, v in pairs(Config.Positions) do
        if v.name == position then
            jurisdiction = string.lower(v.jurisdiction)
        end
    end

    print(vcity, vregion, position, jurisdiction)

    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:getCandidates", function(cb)
        local result = cb
        if #cb == 0 then
            print("No candidates found.")
            TriggerEvent("vorp:TipBottom", _L('no_candidates_found'), 4000)
        end

        for k, v in pairs(cb) do
            label = cb[k].name
            value = cb[k].cid
            ballotID = cb[k].ballotID
            
            addMenuElement = { label = label, value = value, ballotid =ballotID, desc = _L('vote_for_candidate_desc', label) }
            table.insert(menuElements, addMenuElement)
        end

        addMenuElement = { label = _L('vote_for_other_positions'), value = "back", desc = "Back" }
        table.insert(menuElements, addMenuElement)
        addMenuElement = { label = _L('menu_exit'), value = "exit_menu", desc = "Close Menu" }
        table.insert(menuElements, addMenuElement)

        -- Open the menu using VORPMenu
        VORPMenu.Open(
            "default",
            GetCurrentResourceName(),
            "reallyvotemenu",
            {
                title = _L('candidates_menu_title'),
                subtext = _L('candidates_menu_subtext', vcity, vregion),
                align = "top-center",
                elements = menuElements,
                itemHeight = "4vh",
            },
            function(data, menu)
                if data.current.value == "back" then
                    OpenVoteMenu(registered, city, region, onBallot, state)
                elseif data.current.value == "exit_menu" then
                    print("close")
                    menu.close()
                else
                    local selectedBallotID = data.current.ballotid
                    local selectedCandidateID = data.current.value
                    CastVote(registered,city,region,position,jurisdiction,selectedCandidateID,selectedBallotID,onBallot, state)

                end
            end,
            function(data, menu)
                menu.close()
            end
        )
    end, { city = vcity, region = vregion, jurisdiction = jurisdiction, position = position, state = vstate })
end

function CastVote(registered,city, region, position,jurisdiction,candidateid,ballotid,onballot, state)
    local vcity = city
    local vregion = region
    local vstate = state
    local position = position
    local jurisdiction = jurisdiction
    local candidateid = candidateid
    local ballotid =ballotid
    local onBallot = onballot
    print("from client:", vcity, vregion, position, jurisdiction,"ballot:", ballotId, "cand:", candidateid)

    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:hasvotervotedalready", function(cb)
        local result = cb
        if cb then 
            local button = _L('already_voted_prompt')
            local placeholder = _L('placeholder_yes_no')
            TriggerEvent("vorpinputs:getInput", button, placeholder, function(answer)
                print("User input received:", answer)
                if answer == "y" or answer == "Y" or answer == "j" or answer == "J" then
                    TriggerEvent("vorp:TipBottom", (_L('vote_reset')), 4000) 
                    TriggerServerEvent('updateVote', vcity, vregion, position, jurisdiction, candidateid, ballotid, vstate)
                    TriggerEvent("vorp:TipBottom", (_L('vote_casted', jurisdiction, position, vcity, vregion)), 4000) 
                    OpenVoteMenu(registered, city, region, onBallot, vstate)
                else
                    TriggerEvent("vorp:TipBottom", (_L('old_vote_kept')), 4000) 
                end
            end)
        
        else
            local button = _L('new_vote_confirmation', jurisdiction, position, vcity, vregion)
            local placeholder = _L('placeholder_yes_no')
            TriggerEvent("vorpinputs:getInput", button, placeholder, function(answer)
                print("User input received:", answer)
                if answer == "y" or answer == "Y" or answer == "j" or answer == "J" then
                    TriggerServerEvent('addNewVote', vcity, vregion, position, jurisdiction, candidateid, ballotid, vstate)
                    TriggerEvent("vorp:TipBottom", (_L('vote_casted', jurisdiction, position, vcity, vregion)), 4000) 
                    OpenVoteMenu(registered, city, region, onBallot, vstate)
                end
            end)    
        end
    end, { city = vcity, region = vregion, jurisdiction = jurisdiction, position = position, candidateid = candidateid, ballotid = ballotid, state = vstate })
end

function DrawTxt(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local str = CreateVarString(10, "LITERAL_STRING", str)
    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
	SetTextCentre(centre)
	SetTextFontForCurrentCommand(15) 
    if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
	--Citizen.InvokeNative(0xADA9255D, 1);
    DisplayText(str, x, y)
end
RegisterNetEvent('democracy:stoprunning')
AddEventHandler('democracy:stoprunning', function()
    --Lets get what they are running for from the database and show them.
    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:runningstatus", function(cb)
        local result = cb
        print(result)
        local button = _L('stop_running_confirmation', result)
        local placeholder = _L('placeholder_yes_no')

            TriggerEvent("vorpinputs:getInput", button, placeholder, function(answer)
                print("User input received:", answer)
                if answer == "y" or answer == "Y" or answer == "j" or answer == "J" then
                    TriggerServerEvent("removeFromBallot")
                    TriggerEvent("vorp:TipBottom", (_L('stopped_running_success', result)), 4000) 
                else
                    TriggerEvent("vorp:TipBottom", (_L('keep_running', result)), 4000) 
                end
            end)
        
    end)
end)
RegisterCommand("electionresults", function()
        TriggerEvent("vorp:ExecuteServerCallBack", "democracy:isAdmin", function(cb)
            local results=cb
            print(results)
            if results then
                TriggerServerEvent("openelectionresultsmenu")
            else
                TriggerEvent("vorp:TipBottom", (_L('no_election_officials')), 4000) 
            end  
    end)
  
end)

RegisterNetEvent('democracy:openElecResMenu')
AddEventHandler('democracy:openElecResMenu', function()
    VORPMenu.CloseAll()
    local menuElements = {}
    
    local addMenuElement
    for k,v in pairs(Config.Positions) do
        addMenuElement ={ label = v.name, value = v.name, desc = _L('show_results_desc') }
        table.insert(menuElements, addMenuElement)  
    end
    
    addMenuElement = { label = _L('menu_exit'), value = "exit_menu", desc = "Close Menu" }
    table.insert(menuElements,addMenuElement)
    
    -- Open the menu using VORPMenu
    VORPMenu.Open(
        "default",
        GetCurrentResourceName(),
        "runmenu",
        {
            title = _L('results_menu_title'),
            subtext = _L('results_menu_subtext'),
            align = "top-center",
            elements = menuElements,
            itemHeight = "4vh",
        },
        function(data, menu)
            if data.current.value == "exit_menu" then
                menu.close()
            else
                RaceSelectedResults(data.current.value)
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end)

function RaceSelectedResults(position)
    VORPMenu.CloseAll()
    local vposition = position
    local menuElements = {}
    local addMenuElement
    local jurisdiction
    local locations ={}
    local addlocation

    for k, v in pairs(Config.Positions) do
        if v.name == position then
            jurisdiction = string.lower(v.jurisdiction)
        end
    end

    for k,v in pairs(Config.VotingLocations) do
        local valueToAdd
        local labelToAdd
        local descToAdd
        local stateToAdd
    
        if jurisdiction == "local" then
            valueToAdd = Config.VotingLocations[k].city
            labelToAdd = Config.VotingLocations[k].city
            descToAdd = Config.VotingLocations[k].city
        elseif jurisdiction == "state" then
            valueToAdd = Config.VotingLocations[k].state
            labelToAdd = Config.VotingLocations[k].state
            descToAdd = Config.VotingLocations[k].state
            stateToAdd = Config.VotingLocations[k].state
        elseif jurisdiction == "federal" then
            showResults(position, "federal", "federal", nil)
            break
        end
    
        -- Check if the valueToAdd already exists in menuElements
        local exists = false
        for _, element in ipairs(menuElements) do
            if element.value == valueToAdd then
                exists = true
                break
            end
        end
    
        -- If the value doesn't exist, insert the new element
        if not exists then
            addMenuElement = { label = labelToAdd, value = valueToAdd, desc = descToAdd, position = position, jurisdiction = jurisdiction, state = stateToAdd }
            table.insert(menuElements, addMenuElement)
        end
    end
    
    addMenuElement = { label = _L('results_for_other_positions'), value = "back", desc = "Back" }
    table.insert(menuElements, addMenuElement)
    addMenuElement = { label = _L('menu_exit'), value = "exit_menu", desc = "Close Menu" }
    table.insert(menuElements, addMenuElement)

    -- Open the menu using VORPMenu
    VORPMenu.Open(
        "default",
        GetCurrentResourceName(),
        "reallyvotemenu",
        {
            title = _L('results_menu_title'),
            subtext = " for "..vposition,
            align = "top-center",
            elements = menuElements,
            itemHeight = "4vh",
        },
        function(data, menu)
            if data.current.value == "back" then
                TriggerEvent('democracy:openElecResMenu')
            elseif data.current.value == "exit_menu" then
                print("close")
                menu.close()
            else
                local position = data.current.position
                local location = data.current.value
                local jurisdiction = data.current.jurisdiction
                local state = data.current.state
                showResults(position, location, jurisdiction, state)
            end
        end,
        function(data, menu)
            menu.close()
        end
    )
end

function showResults(position, location, jurisdiction, state)
    VORPMenu.CloseAll()
    local vcity = city
    local vregion = region
    local vstate = state
    local position = position
    local menuElements = {}
    local addMenuElement
    local position  = position
    local location = location
    local jurisdiction = jurisdiction      
    local subtitle
    print(position..location..jurisdiction)
    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:getResults", function(cb)
        local result = cb
        if #cb == 0 then
            print("No candidates found.")
            TriggerEvent("vorp:TipBottom", _L('no_candidates_found'), 4000)
            subtitle = "No candidates"
        end
        for k, v in pairs(cb) do
            
            label = cb[k].candidate_name.." - "..cb[k].votes.." votes"
            value = cb[k].candidate_name
            
            addMenuElement = { label = label, value = value }
            table.insert(menuElements, addMenuElement)
        end

        addMenuElement = { label = _L('menu_back'), value = "back", desc = "Back" }
        table.insert(menuElements, addMenuElement)
        addMenuElement = { label = _L('menu_exit'), value = "exit_menu", desc = "Close Menu" }
        table.insert(menuElements, addMenuElement)

        -- Open the menu using VORPMenu
        VORPMenu.Open(
            "default",
            GetCurrentResourceName(),
            "reallyresults",
            {
                title = _L('results_for_label', position),
                subtext = "Results",
                align = "top-center",
                elements = menuElements,
                itemHeight = "4vh",
            },
            function(data, menu)
                if data.current.value == "back" then
                    if jurisdiction ~="federal" then
                        RaceSelectedResults(position)
                    else 
                        TriggerEvent('democracy:openElecResMenu')
                    end
      
                elseif data.current.value == "exit_menu" then
                    
                    menu.close()
                else
                    --donothing. it is the end of the road, finally

                end
            end,
            function(data, menu)
                menu.close()
            end
        )
    end, { location = location, position = position, jurisdiction=jurisdiction, state=vstate })
end
