Config = Config or {}

-- Position hierarchy for this project:
-- Local (city) -> County (region) -> State
-- Federal level intentionally omitted.
Config.Positions = {
  -- USA state offices
  { name = 'State Governor (USA)', jurisdiction = 'State', term = 2, termlimit = 2, states = { 'USA' } },
  { name = 'State Marshal (USA)', jurisdiction = 'State', term = 2, termlimit = 2, states = { 'USA' } },
  { name = 'State Surgeon General (USA)', jurisdiction = 'State', term = 2, termlimit = 2, states = { 'USA' } },

  -- Mexico state offices
  { name = 'State Gobernador (Mexico)', jurisdiction = 'State', term = 2, termlimit = 2, states = { 'Mexico' } },
  { name = 'State Jefe Rural (Mexico)', jurisdiction = 'State', term = 2, termlimit = 2, states = { 'Mexico' } },
  { name = 'State Medico Jefe (Mexico)', jurisdiction = 'State', term = 2, termlimit = 2, states = { 'Mexico' } },

  -- USA county (region) offices
  { name = 'County Sheriff (USA)', jurisdiction = 'County', term = 2, termlimit = 2, states = { 'USA' } },
  { name = 'County Judge (USA)', jurisdiction = 'County', term = 2, termlimit = 2, states = { 'USA' } },

  -- Mexico county (region) offices
  { name = 'County Jefe de Condado (Mexico)', jurisdiction = 'County', term = 2, termlimit = 2, states = { 'Mexico' } },
  { name = 'County Juez de Condado (Mexico)', jurisdiction = 'County', term = 2, termlimit = 2, states = { 'Mexico' } },

  -- Local offices
  { name = 'City Mayor (USA)', jurisdiction = 'Local', term = 2, termlimit = 2, states = { 'USA' } },
  { name = 'City Alcalde (Mexico)', jurisdiction = 'Local', term = 2, termlimit = 2, states = { 'Mexico' } }
}

Config.WinnerJobAssignment = Config.WinnerJobAssignment or {}
Config.WinnerJobAssignment.PositionToJob = {
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
