Config = Config or {}

Config.Lang = 'de-DE'
Config.DevDebug = true

Config.Webhooks = {
  URL = '', -- Primary/default webhook URL.
  CandidateURL = '', -- Optional: candidature posts only. Falls back to URL if empty.
  ResultsURL = '', -- Optional: result/finalization posts only. Falls back to URL if empty.
  ActivityURL = '', -- Optional: vote activity posts only. Falls back to URL if empty.
  Color = '16711680',
  WebhookName = 'Election Bot',
  WebhookLogo = ''
}

Config.Prompts = {
  Prompt1 = 0x760A9C6F, -- G Key
  Prompt2 = 0xE30CD707 -- R Key (Run for Office)
}

-- Job names allowed to run election controls. Admin is always allowed.
Config.ElectionOfficials = {
  'electionofficial'
}

-- Term limit scope controls.
-- ByState=true means the same office in another state is counted separately.
-- WindowYears limits counting to recent wins (set nil or 0 to disable date window).
Config.TermLimitScope = {
  ByState = true,
  WindowYears = 30
}

Config.ElectionCycle = {
  Enabled = true, -- Enable or disable automatic election cycles
  DurationDays = 7, -- How many days an election cycle lasts
  HourToRun = 3 -- 24 hour format, 3 = 3am
}

Config.WinnerJobAssignment = {
  Enabled = true, -- Assign office jobs to winners when election is finalized.
  UseMultiJob = true, -- Triggers event hook 'democracy:assignWinnerJob' for multi-job integrations.
  EquipWinnerJob = true, -- Also switch active job to the won office for online winners.
  AssignOfflineMultiJob = true, -- Writes won office into characters.multijobs for offline winners.
  DefaultGrade = 0,
  PositionToJob = {}
}

Config.ShowVotingBlips = true -- Show configured voting booth blips on the map.
Config.UseNUI = true -- If true, use NUI for voting and running workflows.
Config.ElectionBoothsActiveOnStart = false -- Start with voting booth prompts/blips disabled until an admin starts elections.
Config.PromptRadius = 2.0 -- Radius in meters where native help prompts are shown.
Config.VoteRadius = 2.0 -- Backward compatibility fallback if PromptRadius is missing.
Config.OnlyBlipVotingLocations = true -- If true, only locations with blip=true can be used for voting.
-- Per location: set canVote=false to keep a blip but disable voting at that location.
