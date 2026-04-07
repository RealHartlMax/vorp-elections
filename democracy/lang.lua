-- lang.lua
-- Hier werden alle sichtbaren Texte zentral abgelegt.
-- Der aktive Sprach-Code wird über Config.Lang gesteuert.

Lang = {
    ["en-EN"] = {
        -- Allgemeine Texte
        press_to_vote                = "Press G to Vote",
        placeholder_yes_no           = "y or n",

        -- Registration / Tippmeldungen
        player_registered            = "You have registered to vote in %s",
        player_not_want_vote         = "You don't want to vote?",
        already_voted_prompt         = "You have already voted in this race. Do you wish to remove your vote and vote again?",
        vote_reset                   = "Your vote has been reset for this position",
        vote_casted                  = "You have cast your vote for %s %s in %s %s",
        new_vote_confirmation        = "You are about to place a vote for %s %s in %s %s. Press y to confirm.",
        old_vote_kept                = "Ok, your old vote stands, your new vote has been cancelled",

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
        winner_announcement_title    = "%s has won the election for %s in %s!",
        winner_announcement_desc     = "They will serve a term of %s weeks.",

        -- Admin / Election Officials
        no_election_officials        = "Only Election Officials are authorized to use this command.",
        welcome_election_official    = "Welcome Election Official",
        term_limit_reached           = "You have reached the term limit of %s for the position of %s."
    },

    ["de-DE"] = {
        -- Allgemeine Texte
        press_to_vote                = "Drücke G zum Abstimmen",
        placeholder_yes_no           = "j oder n",

        -- Registration / Tippmeldungen
        player_registered            = "Du bist jetzt registriert, um in %s abzustimmen",
        player_not_want_vote         = "Du möchtest nicht wählen?",
        already_voted_prompt         = "Du hast bereits in diesem Rennen abgestimmt. Möchtest du deine Stimme entfernen und erneut abstimmen?",
        vote_reset                   = "Deine Stimme für diese Position wurde zurückgesetzt",
        vote_casted                  = "Du hast deine Stimme für %s %s in %s %s abgegeben",
        new_vote_confirmation        = "Du bist im Begriff, für %s %s in %s %s abzustimmen. Drücke j zum Bestätigen.",
        old_vote_kept                = "Okay, deine alte Stimme bleibt gültig, deine neue Stimme wurde abgebrochen",

        -- Running / Stop Running
        register_to_vote_prompt      = "Melde dich zum Wählen in %s an",
        run_for_office               = "Für ein Amt kandidieren",
        run_for_office_desc          = "Für dieses Amt auf Ebene %s kandidieren",
        stop_running_for_office      = "Kandidatur beenden",
        stop_running_confirmation    = "Bist du sicher, dass du nicht mehr für %s kandidieren willst? Das kann nicht rückgängig gemacht werden.",
        stopped_running_success      = "Dein Name wurde von der Liste für %s entfernt",
        keep_running                 = "Okay, du bleibst im Rennen für %s",
        you_are_on_ballot            = "Du stehst jetzt offiziell für %s auf dem Stimmzettel",

        -- Election-Menu
        menu_exit                    = "Menü schließen",
        menu_main                    = "Hauptmenü",
        menu_back                    = "Zurück",
        vote_menu_title              = "%s Wahlbüro",
        vote_menu_subtext            = "Abstimmen oder Kandidieren",
        vote_in_label                = "Abstimmen in %s – %s",
        results_menu_title           = "Wahlergebnisse",
        results_menu_subtext         = "Nur Wahlbeamte",

        -- Run-Submenu
        run_menu_title               = "Für ein Amt kandidieren",
        run_menu_subtext             = "in %s, %s",

        -- Vote-Submenu
        vote_menu_title_short        = "Abstimmen",
        vote_menu_subtext_short      = "in %s, %s",
        vote_for_label               = "Abstimmen für %s",
        vote_for_other_positions     = "Für andere Positionen abstimmen",

        -- Candidates-Submenu
        candidates_menu_title        = "Für Kandidaten abstimmen",
        candidates_menu_subtext      = "in %s, %s",
        vote_for_candidate_desc      = "Stimme ab für %s",

        -- Election Results
        results_for_label            = "Ergebnisse für %s",
        no_candidates_found          = "Keine Kandidaten für diese Position gefunden.",
        show_results_desc            = "Ergebnisse anzeigen",
        results_for_other_positions  = "Ergebnisse für andere Positionen",

        -- Discord-Webhook (Server)
        discord_running_title        = "%s kandidiert für ein Amt!",
        discord_running_desc         = "%s tritt an für %s von %s, %s",

        discord_voted_title          = "%s hat abgestimmt!",
        discord_voted_desc           = "%s hat abgestimmt für %s von %s",

        discord_changed_vote_title   = "%s hat seine Stimme geändert!",
        discord_changed_vote_desc    = "%s hat abgestimmt für %s von %s",
        new_election_started_title   = "Eine neue Wahl hat in %s begonnen!",
        new_election_started_desc    = "Besuche eine Wahlkabine, um dich zu registrieren, für ein Amt zu kandidieren oder deine Stimme abzugeben.",
        election_ended_title         = "Die Wahl in %s ist beendet!",
        election_ended_desc          = "Die Ergebnisse werden in Kürze bekannt gegeben.",
        winner_announcement_title    = "%s hat die Wahl zum %s in %s gewonnen!",
        winner_announcement_desc     = "Er/Sie wird eine Amtszeit von %s Wochen haben.",

        -- Admin / Election Officials
        no_election_officials        = "Nur Wahlbeamte dürfen diesen Befehl benutzen.",
        welcome_election_official    = "Willkommen Wahlbeamter",
        term_limit_reached           = "Du hast das Amtszeitlimit von %s für die Position %s erreicht."
    },
}

return Lang
