Config = {}

Config.Lang = 'de-DE'

Config.DevDebug = true

Config.Webhooks={
  URL ='', -- Primary/default webhook URL.
  CandidateURL = '', -- Optional: candidature posts only. Falls back to URL if empty.
  ResultsURL = '', -- Optional: result/finalization posts only. Falls back to URL if empty.
  ActivityURL = '', -- Optional: vote activity posts only. Falls back to URL if empty.
    Color = '16711680',
    WebhookName = 'Election Bot',
    WebhookLogo = ''
}

Config.Prompts = {
    Prompt1 = 0x760A9C6F, -- G Key
  Prompt2 = 0xE30CD707, -- R Key (Run for Office)
}

--Job name for elections allowed folks.  Admin is allowed to run results by default
Config.ElectionOfficials={
   'electionofficial'
}

-- Term limit scope controls.
-- ByState=true means the same office in another state is counted separately.
-- WindowYears limits counting to recent wins (set nil or 0 to disable date window).
Config.TermLimitScope = {
    ByState = true,
    WindowYears = 30
}

-- Position hierarchy for this project:
-- Local (city) -> County (region) -> State
-- Federal level intentionally omitted.
Config.Positions ={
  -- USA state offices
  {name = 'State Governor (USA)', jurisdiction='State', term = 8, termlimit=2, states = {'USA'}},
  {name = 'State Marshal (USA)', jurisdiction='State', term = 8, termlimit=2, states = {'USA'}},
  {name = 'State Surgeon General (USA)', jurisdiction='State', term = 8, termlimit=2, states = {'USA'}},

   -- Mexico state offices
  {name = 'State Gobernador (Mexico)', jurisdiction='State', term = 8, termlimit=2, states = {'Mexico'}},
  {name = 'State Jefe Rural (Mexico)', jurisdiction='State', term = 8, termlimit=2, states = {'Mexico'}},
  {name = 'State Medico Jefe (Mexico)', jurisdiction='State', term = 8, termlimit=2, states = {'Mexico'}},

  -- USA county (region) offices
  {name = 'County Sheriff (USA)', jurisdiction='County', term = 8, termlimit=2, states = {'USA'}},
  {name = 'County Judge (USA)', jurisdiction='County', term = 8, termlimit=2, states = {'USA'}},

  -- Mexico county (region) offices
  {name = 'County Jefe de Condado (Mexico)', jurisdiction='County', term = 8, termlimit=2, states = {'Mexico'}},
  {name = 'County Juez de Condado (Mexico)', jurisdiction='County', term = 8, termlimit=2, states = {'Mexico'}},

   -- Local offices
   {name = 'City Mayor (USA)', jurisdiction='Local', term = 8, termlimit=2, states = {'USA'}},
   {name = 'City Alcalde (Mexico)', jurisdiction='Local', term = 8, termlimit=2, states = {'Mexico'}},
}

Config.ElectionCycle = {
    Enabled = true, -- Enable or disable automatic election cycles
    DurationDays = 7, -- How many days an election cycle lasts
    HourToRun = 3, -- 24 hour format, 3 = 3am
}

Config.WinnerJobAssignment = {
  Enabled = true, -- Assign office jobs to winners when election is finalized.
  UseMultiJob = true, -- Triggers event hook 'democracy:assignWinnerJob' for multi-job integrations.
  EquipWinnerJob = true, -- Also switch active job to the won office for online winners.
  AssignOfflineMultiJob = true, -- Writes won office into characters.multijobs for offline winners.
  DefaultGrade = 0,
  PositionToJob = {
    ['State Governor (USA)'] = 'governor_usa',
    ['State Marshal (USA)'] = 'marshal_usa',
    ['State Surgeon General (USA)'] = 'surgeon_usa',
    ['State Gobernador (Mexico)'] = 'gobernador_mexico',
    ['State Jefe Rural (Mexico)'] = 'jeferural_mexico',
    ['State Medico Jefe (Mexico)'] = 'medicojefe_mexico',
    ['County Sheriff (USA)'] = 'county_sheriff_usa',
    ['County Judge (USA)'] = 'county_judge_usa',
    ['County Jefe de Condado (Mexico)'] = 'jefe_condado_mexico',
    ['County Juez de Condado (Mexico)'] = 'juez_condado_mexico',
    ['City Mayor (USA)'] = 'mayor_usa',
    ['City Alcalde (Mexico)'] = 'alcalde_mexico'
  }
}

Config.ShowVotingBlips = true -- Show configured voting booth blips on the map.
Config.UseNUI = true -- If true, use NUI for voting and running workflows.
Config.ElectionBoothsActiveOnStart = false -- Start with voting booth prompts/blips disabled until an admin starts elections.
Config.PromptRadius = 2.0 -- Radius in meters where native help prompts are shown.
Config.VoteRadius = 2.0 -- Backward compatibility fallback if PromptRadius is missing.
Config.OnlyBlipVotingLocations = true -- If true, only locations with blip=true can be used for voting.
-- Per location: set canVote=false to keep a blip but disable voting at that location.

Config.VotingLocations = { -- https://filmcrz.github.io/blips/
    {
      name = 'Stawberry Voting Booth',
      city='Strawberry',
      region='West Elizabeth',
		state='USA',
		blip=true,
		canVote=true,
      hash = -272216216,
      scale = 1.0,
      coords = {x = -1767.5093994140625, y = -381.3931884765625, z = 157.83193969726565},
    },
    {
      name = 'Blackwater Voting Booth',
      city='Blackwater',
      region='West Elizabeth',
		state='USA',
		blip=true,
		canVote=true,
      hash = -272216216,
      scale = 1.0,
      coords = {x = -797.2415, y = -1197.8335, z = 44.1936},
    },
    {
      name = 'Armadillo Voting Booth',
      city='Armadillo',
      region='New Austin',
		state='USA',
		blip=true,
		canVote=true,
      hash = -272216216,
      scale = 1.0,
      coords = {x = -3662.2265625, y = -2624.84521484375, z = -13.48766803741455},
    },
    {
      name = 'Tumbleweed Voting Booth',
      city='Tumbleweed',
      region='New Austin',
		state='USA',
		blip=true,
		canVote=true,
      hash = -272216216,
      scale = 1.0,
      coords = {x = -5487.060546875, y = -2939.2705078125, z = -0.28708344697952},
    },
    {
      name = 'Valentine Voting Booth',
      city='Valentine',
      region='New Hanover',
		state='USA',
		blip=true,
		canVote=true,
      hash = -272216216,
      scale = 1.0,
      coords = {x = -172.77517700195312, y = 634.057373046875, z = 114.18964385986328},
    },
    {
      name = 'Rhodes Voting Booth',
      city='Rhodes',
      region='Lemoyne',
		state='USA',
		blip=true,
		canVote=true,
      hash = -272216216,
      scale = 1.0,
      coords = {x = 1289.6468505859375, y = -1300.8714599609375, z = 77.14014434814453},
    },
    {
      name = 'Saint Denis Voting Booth',
      city='St Denis',
      region='Lemoyne',
		state='USA',
		blip=true,
		canVote=true,
      hash = -272216216,
      scale = 1.0,
      coords = {x = 2744.698486328125, y = -1397.2818603515625, z = 46.2830696105957},
    },
    {
      name = 'Annesburg Voting Booth',
      city='Annesburg',
      region='New Hanover',
      state='USA',
		blip=true,
		canVote=true,
      hash = -272216216,
      scale = 0.5,
      coords = {x = 2930.1513671875, y = 1279.6221923828125, z = 44.75285339355469},
    },
    {
        name = 'Escalera Voting Booth',
        city = 'Escalera',
        region = 'Nuevo Paraiso',
        state = 'Mexico',
        blip = true,
      canVote = true,
        hash = -272216216,
        scale = 1.0,
        coords = { x = -262.8, y = -3236.7, z = 131.7 },
    },
    {
        name = 'Chuparosa Voting Booth',
        city = 'Chuparosa',
        region = 'Nuevo Paraiso',
        state = 'Mexico',
        blip = true,
      canVote = true,
        hash = -272216216,
        scale = 1.0,
        coords = { x = 442.8, y = -3172.4, z = 153.2 },
    }

}
