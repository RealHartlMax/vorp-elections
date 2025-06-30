Config = {}

Config.Lang = 'en-EN'

Config.DevDebug = true

Config.Webhooks={
    URL ='https://discord.com/api/webhooks/1378336296321290260/WB2JX8ZL7NMFCiGcryH7rkokfMvV8sOA2Lg0jsQGkN65SYgbVEG70thYzG9VSVJHx8zh',
    Color = '16711680',
    WebhookName = 'Election Bot',
    WebhookLogo = ''
}

Config.Prompts = {
    Prompt1 = 0x760A9C6F, -- G Key
}

--Job name for elections allowed folks.  Admin is allowed to run results by default
Config.ElectionOfficials={
   {'electionofficial'}
}

--Position name and the term in weeks
--jurisdiction can be Federal, Regional or Local, termlimit not yet functional
Config.Positions ={
    {name = 'President', jurisdiction='Federal', term = 8, termlimit=2}, 
    {name = 'Chief Marshall', jurisdiction='Federal', term = 8, termlimit=2},
    {name = 'Chief Justice', jurisdiction='Federal', term = 8, termlimit=2},
    {name = 'Congress East',jurisdiction='Federal', term = 8, termlimit=2},
    {name = 'Congress West', jurisdiction='Federal', term = 8, termlimit=2},
    {name = 'Governor', jurisdiction='Regional', term = 8, termlimit=2},
    {name = 'Head Doctor', jurisdiction='Regional', term = 8, termlimit=2},
    {name = 'Mayor', jurisdiction='Local', term = 8, termlimit=2},
}

Config.VoteRadius = 2.0

Config.VotingLocations = { -- https://filmcrz.github.io/blips/
    {
      name = 'Stawberry Voting Booth',
      city='Strawberry',
      region='West Elizabeth',
		state='USA',
		blip=true,
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
      hash = -272216216,
      scale = 0.5,
      coords = {x = 2930.1513671875, y = 1279.6221923828125, z = 44.75285339355469},
    }

}
