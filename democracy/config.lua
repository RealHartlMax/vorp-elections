Config = {}

Config.Lang = 'de-DE'

Config.DevDebug = true

Config.Webhooks={
    URL ='',
    Color = '16711680',
    WebhookName = 'Election Bot',
    WebhookLogo = ''
}

Config.Prompts = {
    Prompt1 = 0x760A9C6F, -- G Key
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

--Position name and the term in weeks
--jurisdiction can be Federal, Regional or Local, termlimit not yet functional
Config.Positions ={
   -- USA federal offices (1870-1899 flavor)
   {name = 'President (USA)', jurisdiction='Federal', term = 8, termlimit=2, states = {'USA'}},
   {name = 'Secretary of War (USA)', jurisdiction='Federal', term = 8, termlimit=2, states = {'USA'}},
   {name = 'Chief Justice (USA)', jurisdiction='Federal', term = 8, termlimit=2, states = {'USA'}},
   {name = 'Senator East (USA)', jurisdiction='Federal', term = 8, termlimit=2, states = {'USA'}},
   {name = 'Senator West (USA)', jurisdiction='Federal', term = 8, termlimit=2, states = {'USA'}},

   -- Mexico federal offices (1870-1899 flavor)
   {name = 'Presidente (Mexico)', jurisdiction='Federal', term = 8, termlimit=2, states = {'Mexico'}},
   {name = 'Ministro de Guerra (Mexico)', jurisdiction='Federal', term = 8, termlimit=2, states = {'Mexico'}},
   {name = 'Presidente de la Suprema Corte (Mexico)', jurisdiction='Federal', term = 8, termlimit=2, states = {'Mexico'}},
   {name = 'Diputado del Norte (Mexico)', jurisdiction='Federal', term = 8, termlimit=2, states = {'Mexico'}},
   {name = 'Diputado del Sur (Mexico)', jurisdiction='Federal', term = 8, termlimit=2, states = {'Mexico'}},

   -- USA state offices
   {name = 'Governor (USA)', jurisdiction='State', term = 8, termlimit=2, states = {'USA'}},
   {name = 'State Marshal (USA)', jurisdiction='State', term = 8, termlimit=2, states = {'USA'}},
   {name = 'Surgeon General (USA)', jurisdiction='State', term = 8, termlimit=2, states = {'USA'}},

   -- Mexico state offices
   {name = 'Gobernador (Mexico)', jurisdiction='State', term = 8, termlimit=2, states = {'Mexico'}},
   {name = 'Jefe Rural (Mexico)', jurisdiction='State', term = 8, termlimit=2, states = {'Mexico'}},
   {name = 'Medico Jefe (Mexico)', jurisdiction='State', term = 8, termlimit=2, states = {'Mexico'}},

   -- Local offices
   {name = 'Mayor (USA)', jurisdiction='Local', term = 8, termlimit=2, states = {'USA'}},
   {name = 'Alcalde (Mexico)', jurisdiction='Local', term = 8, termlimit=2, states = {'Mexico'}},
}

Config.ElectionCycle = {
    Enabled = true, -- Enable or disable automatic election cycles
    DurationDays = 7, -- How many days an election cycle lasts
    HourToRun = 3, -- 24 hour format, 3 = 3am
}

Config.ShowVotingBlips = true -- Show configured voting booth blips on the map.
Config.VoteRadius = 2.0
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
