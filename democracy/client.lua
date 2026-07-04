local VORPcore = {} -- core object
local Translations = Lang[Config.Lang]

---@diagnostic disable-next-line: undefined-global
local CreateVarString = CreateVarString

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

local votePrompt
local runPrompt
local votePromptGroup = GetRandomIntInRange(0, 0xFFFFFF)
local votePromptReady = false
local votingBlips = {}
local nuiOpen = false
local currentBoothContext = nil
local currentOnBallot = false
local electionActive = false
local nextPromptUseAt = 0
local activePositionLookup = {}

local function IsPositionEnabled(positionName)
    if not electionActive then
        return false
    end

    if not positionName then
        return false
    end

    if next(activePositionLookup) == nil then
        return true
    end

    return activePositionLookup[positionName] == true
end

local function AddBlipForCoordNative(blipType, x, y, z)
    return Citizen.InvokeNative(0x554D9D53F696D002, blipType, x, y, z)
end

local function SetBlipSpriteNative(blip, sprite, p2)
    Citizen.InvokeNative(0x74F74D3207ED525C, blip, sprite, p2)
end

local function SetBlipScaleNative(blip, scale)
    Citizen.InvokeNative(0xD38744167B2FA257, blip, scale)
end

local function SetBlipNameNative(blip, name)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, name)
end

local function RemoveBlipNative(blip)
    -- Reliable RedM/CFX HUD remove blip native.
    Citizen.InvokeNative(0x86A652570E5F25DD, blip)

    -- Fallback for runtimes exposing RemoveBlip directly.
    if RemoveBlip then
        RemoveBlip(blip)
    end
end

local function PromptRegisterBeginNative()
    return Citizen.InvokeNative(0x04F97DE45A519419)
end

local function PromptSetControlActionNative(prompt, control)
    Citizen.InvokeNative(0xB5352B7494A08258, prompt, control)
end

local function PromptSetTextNative(prompt, text)
    Citizen.InvokeNative(0x5DD02A8318420DD7, prompt, text)
end

local function PromptSetEnabledNative(prompt, enabled)
    Citizen.InvokeNative(0x8A0FB4D03A630D21, prompt, enabled)
end

local function PromptSetVisibleNative(prompt, visible)
    Citizen.InvokeNative(0x71215ACCFDE075EE, prompt, visible)
end

local function PromptSetStandardModeNative(prompt, standard)
    Citizen.InvokeNative(0xCC6656799977741B, prompt, standard)
end

local function PromptSetGroupNative(prompt, group)
    Citizen.InvokeNative(0x2F11D3A254169EA4, prompt, group, 0)
end

local function PromptRegisterEndNative(prompt)
    Citizen.InvokeNative(0xF7AA2696A22AD8B9, prompt)
end

local function PromptSetActiveGroupThisFrameNative(group, label)
    Citizen.InvokeNative(0xC65A45D4453C2627, group, label)
end

local function PromptHasStandardModeCompletedNative(prompt)
    return Citizen.InvokeNative(0xC92AC953F0A982AE, prompt)
end

local function SetPromptVisibility(enabled)
    if votePrompt then
        PromptSetEnabledNative(votePrompt, enabled)
        PromptSetVisibleNative(votePrompt, enabled)
    end

    if runPrompt then
        PromptSetEnabledNative(runPrompt, enabled)
        PromptSetVisibleNative(runPrompt, enabled)
    end
end

local function GetPositionJurisdiction(positionName)
    for _, v in pairs(Config.Positions) do
        if v.name == positionName then
            return string.lower(v.jurisdiction)
        end
    end
    return "local"
end

local function GetPositionsForState(state)
    local positions = {}
    for _, v in pairs(Config.Positions) do
        if IsPositionEnabled(v.name) then
        for _, s in ipairs(v.states) do
            if s == state then
                table.insert(positions, { name = v.name, jurisdiction = v.jurisdiction })
                break
            end
        end
        end
    end
    return positions
end

local function GetAllPositions(includeInactive)
    local positions = {}
    for _, v in pairs(Config.Positions) do
        if includeInactive or IsPositionEnabled(v.name) then
            table.insert(positions, { name = v.name, jurisdiction = v.jurisdiction })
        end
    end
    return positions
end

local function BuildResultScopes(position)
    local jurisdiction = GetPositionJurisdiction(position)
    local scopes = {}
    local seen = {}

    if jurisdiction == "federal" then
        table.insert(scopes, { label = _L('nui_results_federal'), value = "federal", state = nil })
        return scopes, jurisdiction
    end

    for _, v in pairs(Config.VotingLocations) do
        if jurisdiction == "state" then
            if not seen[v.state] then
                seen[v.state] = true
                table.insert(scopes, { label = v.state, value = v.state, state = v.state })
            end
        else
            local key = v.city
            if not seen[key] then
                seen[key] = true
                table.insert(scopes, {
                    label = string.format("%s (%s)", v.city, v.state),
                    value = v.city,
                    state = v.state
                })
            end
        end
    end

    return scopes, jurisdiction
end

local function SetNuiOpenState(isOpen)
    nuiOpen = isOpen
    SetNuiFocus(isOpen, isOpen)

    if not isOpen then
        nextPromptUseAt = GetGameTimer() + 700
    end
end

local function OpenElectionNui(mode, city, region, state, onBallot, autoSelectFirst, customPositions, selectedPositions)
    if mode == "results" or mode == "admin" then
        currentBoothContext = nil
    else
        currentBoothContext = {
            city = city,
            region = region,
            state = state
        }
    end

    currentOnBallot = onBallot == true
    local subtitleCity = city or "-"
    local subtitleRegion = region or "-"
    local subtitleState = state or "-"
    local positions = customPositions or (mode == "results" and GetAllPositions(true) or GetPositionsForState(state))

    local labels = {
        title = _L('nui_title'),
        vote = _L('nui_vote'),
        run = _L('nui_run'),
        results = _L('nui_results'),
        register = _L('nui_register'),
        admin = _L('nui_admin_setup'),
        close = _L('nui_close'),
        select_position = _L('nui_select_position'),
        select_candidate = _L('nui_select_candidate'),
        select_scope = _L('nui_select_scope'),
        submit_vote = _L('nui_submit_vote'),
        submit_run = _L('nui_submit_run'),
        submit_admin = _L('nui_submit_admin'),
        admin_select_required = _L('nui_admin_select_required'),
        register_prompt = _L('register_to_vote_prompt', subtitleCity),
        register_now = _L('nui_register_now'),
        results_empty = _L('nui_results_empty'),
        results_for = _L('results_for_label', "%s"),
        votes_suffix = _L('nui_votes_suffix'),
        scope_federal = _L('nui_results_federal'),
        no_candidates = _L('no_candidates_found')
    }

    SendNUIMessage({
        action = "open",
        resourceName = GetCurrentResourceName(),
        mode = mode,
        city = city,
        region = region,
        state = state,
        subtitleCity = subtitleCity,
        subtitleRegion = subtitleRegion,
        subtitleState = subtitleState,
        onBallot = currentOnBallot,
        autoSelectFirst = autoSelectFirst == true,
        selectedPositions = selectedPositions or {},
        positions = positions,
        labels = labels
    })

    SetNuiOpenState(true)
end

RegisterNUICallback('close', function(_, cb)
    SetNuiOpenState(false)
    currentBoothContext = nil
    cb({ ok = true })
end)

RegisterNUICallback('runForOffice', function(data, cb)
    if not currentBoothContext or not data or not data.position then
        cb({ ok = false })
        return
    end

    TriggerServerEvent('addballotname', currentBoothContext.city, currentBoothContext.region, data.position, currentBoothContext.state)
    TriggerEvent("vorp:TipBottom", (_L('you_are_on_ballot', data.position)), 4000)
    SetNuiOpenState(false)
    currentBoothContext = nil
    cb({ ok = true })
end)

RegisterNUICallback('registerToVote', function(_, cb)
    if not currentBoothContext then
        cb({ ok = false })
        return
    end

    TriggerServerEvent('registerVoter', currentBoothContext.city, currentBoothContext.region, currentBoothContext.state)
    TriggerEvent("vorp:TipBottom", (_L('player_registered', currentBoothContext.city)), 4000)
    cb({ ok = true, message = _L('nui_register_success') })
end)

RegisterNUICallback('getCandidates', function(data, cb)
    if not currentBoothContext or not data or not data.position then
        cb({ ok = false, candidates = {} })
        return
    end

    local jurisdiction = GetPositionJurisdiction(data.position)
    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:getCandidates", function(result)
        local candidates = {}
        for _, entry in pairs(result) do
            table.insert(candidates, {
                name = entry.name,
                cid = entry.cid,
                ballotID = entry.ballotID
            })
        end
        cb({ ok = true, candidates = candidates, jurisdiction = jurisdiction })
    end, {
        city = currentBoothContext.city,
        region = currentBoothContext.region,
        jurisdiction = jurisdiction,
        position = data.position,
        state = currentBoothContext.state
    })
end)

RegisterNUICallback('getResultsScopes', function(data, cb)
    if not data or not data.position then
        cb({ ok = false, scopes = {} })
        return
    end

    local scopes, jurisdiction = BuildResultScopes(data.position)
    cb({ ok = true, scopes = scopes, jurisdiction = jurisdiction })
end)

RegisterNUICallback('getResultsData', function(data, cb)
    if not data or not data.position or not data.jurisdiction then
        cb({ ok = false, rows = {} })
        return
    end

    local location = data.location or "federal"
    local state = data.state

    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:getResults", function(result)
        local rows = {}
        for _, entry in pairs(result) do
            table.insert(rows, {
                name = entry.candidate_name,
                votes = tonumber(entry.votes) or 0
            })
        end
        cb({ ok = true, rows = rows })
    end, {
        location = location,
        position = data.position,
        jurisdiction = data.jurisdiction,
        state = state
    })
end)

RegisterNUICallback('castVote', function(data, cb)
    if not currentBoothContext or not data or not data.position or not data.jurisdiction or not data.candidateid or not data.ballotid then
        cb({ ok = false })
        return
    end

    SetNuiOpenState(false)
    CastVote(true, currentBoothContext.city, currentBoothContext.region, data.position, data.jurisdiction, data.candidateid, data.ballotid, currentOnBallot, currentBoothContext.state, true)
    currentBoothContext = nil
    cb({ ok = true })
end)

local function CreateVotingBlips()
    if Config.ShowVotingBlips == false then
        return
    end

    if #votingBlips > 0 then
        for _, blip in ipairs(votingBlips) do
            RemoveBlipNative(blip)
        end
        votingBlips = {}
    end

    for _, v in pairs(Config.VotingLocations) do
        if v.blip and v.coords then
            local blip = AddBlipForCoordNative(1664425300, v.coords.x, v.coords.y, v.coords.z)
            SetBlipSpriteNative(blip, v.hash or -272216216, true)
            SetBlipScaleNative(blip, v.scale or 1.0)
            SetBlipNameNative(blip, v.name or _L('press_to_vote'))
            table.insert(votingBlips, blip)
        end
    end
end

local function RemoveVotingBlips()
    if #votingBlips == 0 then
        return
    end

    for _, blip in ipairs(votingBlips) do
        RemoveBlipNative(blip)
    end
    votingBlips = {}
end

local function ApplyElectionState(isActive, activePositions)
    electionActive = isActive == true
    activePositionLookup = {}

    if type(activePositions) == 'table' then
        for _, name in ipairs(activePositions) do
            activePositionLookup[name] = true
        end
    end

    if electionActive then
        CreateVotingBlips()
    else
        RemoveVotingBlips()
        SetPromptVisibility(false)
        SendNUIMessage({ action = "close" })
        if nuiOpen then
            SetNuiOpenState(false)
            currentBoothContext = nil
        end
    end
end

RegisterNetEvent('democracy:setElectionActive')
AddEventHandler('democracy:setElectionActive', function(isActive, activePositions)
    ApplyElectionState(isActive, activePositions)
end)

local function SetupVotePrompt()
    if votePromptReady then
        return
    end

    local votePromptLabel = CreateVarString(10, "LITERAL_STRING", _L('press_to_vote'))
    votePrompt = PromptRegisterBeginNative()
    PromptSetControlActionNative(votePrompt, Config.Prompts.Prompt1)
    PromptSetTextNative(votePrompt, votePromptLabel)
    PromptSetEnabledNative(votePrompt, false)
    PromptSetVisibleNative(votePrompt, false)
    PromptSetStandardModeNative(votePrompt, true)
    PromptSetGroupNative(votePrompt, votePromptGroup)
    PromptRegisterEndNative(votePrompt)

    if Config.Prompts and Config.Prompts.Prompt2 then
        local runPromptLabel = CreateVarString(10, "LITERAL_STRING", _L('press_to_run'))
        runPrompt = PromptRegisterBeginNative()
        PromptSetControlActionNative(runPrompt, Config.Prompts.Prompt2)
        PromptSetTextNative(runPrompt, runPromptLabel)
        PromptSetEnabledNative(runPrompt, false)
        PromptSetVisibleNative(runPrompt, false)
        PromptSetStandardModeNative(runPrompt, true)
        PromptSetGroupNative(runPrompt, votePromptGroup)
        PromptRegisterEndNative(runPrompt)
    end

    votePromptReady = true
end

-- Following thread looks for ped in radius of voting locations and shows a native prompt.
Citizen.CreateThread(function()
    SetupVotePrompt()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
    ApplyElectionState(Config.ElectionBoothsActiveOnStart == true, nil)

    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:getElectionActive", function(stateData)
        local active = stateData
        local positions = nil

        if type(stateData) == 'table' then
            active = stateData.active
            positions = stateData.positions
        end

        ApplyElectionState(active, positions)
    end)

    while true do
        if not electionActive then
            SetPromptVisibility(false)
            Citizen.Wait(1000)
            goto continue_loop
        end

        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local closestLocation
        local closestDistance = math.huge
        local requiresBlip = Config.OnlyBlipVotingLocations == true

        for _, v in pairs(Config.VotingLocations) do
            local locationCanVote = v.canVote ~= false
            if locationCanVote and ((not requiresBlip) or v.blip) then
                local boothCoords = vector3(v.coords.x, v.coords.y, v.coords.z)
                local distance = #(coords - boothCoords)

                if distance < closestDistance then
                    closestDistance = distance
                    closestLocation = v
                end
            end
        end

        local promptRadius = Config.PromptRadius or Config.VoteRadius or 2.0
        local inRange = (closestLocation ~= nil) and (closestDistance <= promptRadius)
        local promptActive = inRange and (not nuiOpen) and (GetGameTimer() >= nextPromptUseAt)
        PromptSetEnabledNative(votePrompt, promptActive)
        PromptSetVisibleNative(votePrompt, promptActive)
        if runPrompt then
            PromptSetEnabledNative(runPrompt, promptActive)
            PromptSetVisibleNative(runPrompt, promptActive)
        end

        if promptActive then
            local groupLabel = CreateVarString(10, "LITERAL_STRING", _L('vote_in_label', closestLocation.city, closestLocation.region))
            PromptSetActiveGroupThisFrameNative(votePromptGroup, groupLabel)

            local votePressed = PromptHasStandardModeCompletedNative(votePrompt) or IsControlJustReleased(0, Config.Prompts.Prompt1)
            local runPressed = runPrompt and (PromptHasStandardModeCompletedNative(runPrompt) or IsControlJustReleased(0, Config.Prompts.Prompt2))

            if votePressed then
                TriggerEvent('democracy:votingbooth', closestLocation.city, closestLocation.region, closestLocation.state)
                Citizen.Wait(1000)
            elseif runPressed then
                TriggerEvent('democracy:runbooth', closestLocation.city, closestLocation.region, closestLocation.state)
                Citizen.Wait(1000)
            else
                Citizen.Wait(0)
            end
        else
            Citizen.Wait(500)
        end

        ::continue_loop::
    end
end)

RegisterNetEvent('democracy:votingbooth')
AddEventHandler('democracy:votingbooth', function(city, region, state)
    if not electionActive then
        TriggerEvent("vorp:TipBottom", (_L('elections_not_active')), 4000)
        return
    end

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
            if Config.UseNUI == false then
                OpenStartMenu(true, vcity, vregion, onBallot, vstate)
            else
                OpenElectionNui("vote", vcity, vregion, vstate, onBallot)
            end
        else
            print("Player is not registered.")
            if Config.UseNUI == false then
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
            else
                OpenElectionNui("register", vcity, vregion, vstate, onBallot)
            end
        end
    end, { city = vcity, region = vregion })
end)
end)

RegisterNetEvent('democracy:runbooth')
AddEventHandler('democracy:runbooth', function(city, region, state)
    if not electionActive then
        TriggerEvent("vorp:TipBottom", (_L('elections_not_active')), 4000)
        return
    end

    local vcity = city
    local vregion = region
    local vstate = state
    local onBallot = false

    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:checkonballot", function(cb)
        onBallot = cb

        TriggerEvent("vorp:ExecuteServerCallBack", "democracy:checkRegistration", function(registered)
            if Config.UseNUI == false then
                if onBallot then
                    OpenStartMenu(registered, vcity, vregion, onBallot, vstate)
                else
                    OpenRunMenu(registered, vcity, vregion, onBallot, vstate)
                end
            else
                OpenElectionNui("run", vcity, vregion, vstate, onBallot)
            end
        end, { city = vcity, region = vregion })
    end)
end)

RegisterNUICallback('applyElectionSetup', function(data, cb)
    if not data or type(data.positions) ~= 'table' then
        cb({ ok = false })
        return
    end

    TriggerServerEvent('democracy:applyElectionSetup', data.positions)
    SetNuiOpenState(false)
    currentBoothContext = nil
    cb({ ok = true })
end)

RegisterNetEvent('democracy:openElectionSetup')
AddEventHandler('democracy:openElectionSetup', function(positions, selectedPositions)
    OpenElectionNui("admin", nil, nil, nil, false, false, positions or {}, selectedPositions or {})
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
        if IsPositionEnabled(v.name) then
        for i, s in ipairs(v.states) do
            if s == vstate then
                addMenuElement ={ label = v.name, value = v.name, desc = _L('run_for_office_desc', v.jurisdiction) }
                table.insert(menuElements, addMenuElement)
            end
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
        if IsPositionEnabled(v.name) then
        for i, s in ipairs(v.states) do
            if s == vstate then
                addMenuElement ={ label = v.name, value = v.name, desc = _L('vote_for_label', v.name) }
                table.insert(menuElements, addMenuElement)
                break
            end
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
            local label = cb[k].name
            local value = cb[k].cid
            local ballotID = cb[k].ballotID
            
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

function CastVote(registered,city, region, position,jurisdiction,candidateid,ballotid,onballot, state, fromNui)
    local vcity = city
    local vregion = region
    local vstate = state
    local position = position
    local jurisdiction = jurisdiction
    local candidateid = candidateid
    local ballotid =ballotid
    local onBallot = onballot
    print("from client:", vcity, vregion, position, jurisdiction,"ballot:", ballotid, "cand:", candidateid)

    TriggerEvent("vorp:ExecuteServerCallBack", "democracy:hasvotervotedalready", function(cb)
        if fromNui then
            if cb then
                TriggerEvent("vorp:TipBottom", (_L('vote_reset')), 4000)
                TriggerServerEvent('updateVote', vcity, vregion, position, jurisdiction, candidateid, ballotid, vstate)
            else
                TriggerServerEvent('addNewVote', vcity, vregion, position, jurisdiction, candidateid, ballotid, vstate)
            end

            TriggerEvent("vorp:TipBottom", (_L('vote_casted', jurisdiction, position, vcity, vregion)), 4000)
            return
        end

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
                    if not fromNui then
                        OpenVoteMenu(registered, city, region, onBallot, vstate)
                    end
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
                    if not fromNui then
                        OpenVoteMenu(registered, city, region, onBallot, vstate)
                    end
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
  
end, false)

RegisterNetEvent('democracy:openElecResMenu')
AddEventHandler('democracy:openElecResMenu', function()
    if Config.UseNUI ~= false then
        OpenElectionNui("results", nil, nil, nil, false, false)
        return
    end

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

local showResults

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

showResults = function(position, location, jurisdiction, state)
    VORPMenu.CloseAll()
    local vstate = state
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
            local label = cb[k].candidate_name.." - "..cb[k].votes.." votes"
            local value = cb[k].candidate_name
            
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
