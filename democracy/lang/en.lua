Lang = Lang or {}

Lang["en-EN"] = {
    -- Allgemeine Texte
    press_to_vote                = "Press G to Vote",
    press_to_run                 = "Press R to Run for Office",
    nui_title                    = "Election Booth",
    nui_vote                     = "Vote",
    nui_run                      = "Run for Office",
    nui_results                  = "Results",
    nui_register                 = "Register",
    nui_admin_setup              = "Election Setup",
    nui_close                    = "Close",
    nui_select_position          = "Select Office",
    nui_select_candidate         = "Select Candidate",
    nui_select_scope             = "Select Scope",
    nui_select_scope_city        = "Select City",
    nui_select_scope_county      = "Select County",
    nui_select_scope_state       = "Select State",
    nui_jurisdiction_city        = "City",
    nui_jurisdiction_county      = "County",
    nui_jurisdiction_state       = "State",
    nui_submit_vote              = "Cast Vote",
    nui_submit_run               = "Join Ballot",
    nui_submit_admin             = "Start Election",
    nui_publish_results          = "Publish Results",
    nui_publish_confirm_message  = "Publish all election results now?",
    nui_publish_confirm_yes      = "Yes",
    nui_publish_confirm_no       = "No",
    nui_loading                  = "Loading...",
    nui_admin_select_required    = "Please select at least one office.",
    nui_admin_scope_type         = "Election Scope",
    nui_admin_scope_all          = "All regions and cities",
    nui_scope_state              = "State",
    nui_scope_region             = "County",
    nui_scope_city               = "City",
    nui_scope_all_label          = "All regions and cities",
    nui_active_scope_prefix      = "Active election scope",
    nui_admin_select_scope       = "Select election scope",
    nui_admin_scope_select_required = "Please select an election scope.",
    nui_register_now             = "Register Now",
    nui_register_success         = "Registration successful. You can now vote.",
    nui_results_empty            = "No results found for this selection.",
    nui_no_positions_scope       = "No offices available for this election scope.",
    nui_no_positions_vote        = "No offices are currently up for election at this location.",
    nui_no_positions_results     = "No active election results are available right now.",
    nui_results_federal          = "Federal",
    nui_votes_suffix             = "votes",
    placeholder_yes_no           = "y or n",

    -- Registration / Tippmeldungen
    player_registered            = "You have registered to vote in %s",
    player_not_want_vote         = "You don't want to vote?",
    already_voted_prompt         = "You have already voted in this race. Do you wish to remove your vote and vote again?",
    vote_reset                   = "Your vote has been reset for this position",
    vote_casted                  = "You have cast your vote for %s %s in %s %s",
    new_vote_confirmation        = "You are about to place a vote for %s %s in %s %s. Press y to confirm.",
    old_vote_kept                = "Ok, your old vote stands, your new vote has been cancelled",
    vote_already_cast_locked     = "You have already voted in this race. Vote changes are not allowed.",

    -- Running / Stop Running
    register_to_vote_prompt      = "Register to Vote in %s",
    run_for_office               = "Run for Office",
    run_for_office_desc          = "Run for this %s office",
    stop_running_for_office      = "Stop Running for Office",
    stop_running_confirmation    = "Are you sure you wish to stop running for %s? This cannot be undone.",
    stopped_running_success      = "You have removed your name from the slate for %s",
    keep_running                 = "Ok, you will remain in the running for %s",
    you_are_on_ballot            = "You are now officially on the ballot for %s",

    -- Election-Menu
    menu_exit                    = "Exit Menu",
    menu_main                    = "Main Menu",
    menu_back                    = "Back",
    vote_menu_title              = "%s Voting Booth",
    vote_menu_subtext            = "Vote or Run",
    vote_in_label                = "Vote in %s - %s",
    results_menu_title           = "Election Results",
    results_menu_subtext         = "Election Officials Only",

    -- Run-Submenu
    run_menu_title               = "Run for Office",
    run_menu_subtext             = "in %s, %s",

    -- Vote-Submenu
    vote_menu_title_short        = "Vote",
    vote_menu_subtext_short      = "in %s, %s",
    vote_for_label               = "Vote for %s",
    vote_for_other_positions     = "Vote for Other Positions",

    -- Candidates-Submenu
    candidates_menu_title        = "Vote for Candidate",
    candidates_menu_subtext      = "in %s, %s",
    vote_for_candidate_desc      = "Vote for %s",

    -- Election Results
    results_for_label            = "Results for %s",
    no_candidates_found          = "No candidates found for this position.",
    show_results_desc            = "Show results",
    results_for_other_positions  = "Results for Other Positions",

    -- Voting booth names
    booth_strawberry             = "Strawberry Voting Booth",
    booth_blackwater             = "Blackwater Voting Booth",
    booth_armadillo              = "Armadillo Voting Booth",
    booth_tumbleweed             = "Tumbleweed Voting Booth",
    booth_valentine              = "Valentine Voting Booth",
    booth_rhodes                 = "Rhodes Voting Booth",
    booth_saint_denis            = "Saint Denis Voting Booth",
    booth_annesburg              = "Annesburg Voting Booth",
    booth_escalera               = "Escalera Voting Booth",
    booth_chuparosa              = "Chuparosa Voting Booth",

    -- Discord-Webhook (Server)
    discord_running_title        = "%s is running for office!",
    discord_running_desc         = "%s entered the race for %s of %s, %s",

    discord_voted_title          = "%s has Voted!",
    discord_voted_desc           = "%s voted for %s of %s",

    discord_changed_vote_title   = "%s changed vote!",
    discord_changed_vote_desc    = "%s voted for %s of %s",

    new_election_started_title   = "A new election has begun in %s!",
    new_election_started_desc    = "Visit a voting booth to register, run for office, or cast your vote.",
    election_ended_title         = "The election has ended in %s!",
    election_ended_desc          = "Results will be announced shortly.",
    discord_results_archive_title = "Election Archive for %s",
    discord_results_archive_empty = "No result data available for %s.",
    discord_results_total_votes   = "Total votes cast: %s",
    winner_announcement_title    = "%s has won the election for %s in %s!",
    winner_announcement_desc     = "They will serve a term of %s months.",
    election_commands_enabled    = "Elections have been started. Voting booths are now active.",
    election_global_announcement = "A new election has started. Voting booths are now open for everyone.",
    election_commands_disabled   = "Elections have been ended. Voting booths are now inactive.",
    election_finalize_started    = "Election finalization started. Results archive and cleanup are processing.",
    elections_not_active         = "Elections are currently inactive.",
    winner_job_assigned          = "You received office %s (job: %s).",

    -- Admin / Election Officials
    no_election_officials        = "Only Election Officials are authorized to use this command.",
    welcome_election_official    = "Welcome Election Official",
    term_limit_reached           = "You have reached the term limit of %s for the position of %s."
}
