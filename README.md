# vorp-elections

Elections script for RedM/VORP.

Based on "Democracy" by Jeffy Detexas.

## Current Scope

- Register voters at voting booths.
- Run for office (one active candidacy per character).
- Vote per office with option to change an existing vote.
- View election results in-game via officials-only menu.
- Optional Discord webhook notifications for candidacy, voting, vote changes, cycle start/end, and winner announcements.
- Multi-state data model with separate election data per state.
- Position lists are filtered by booth state in run/vote menus.
- Term-limit checks support configurable scope (per state and optional time window).
- Basic automatic election cycle processing (state-based) plus manual SQL cleanup script.

## Dependencies

- `vorp_core`
- `vorp_menu`
- `vorpinputs`
- `oxmysql`

## Installation

1. Put the `democracy` folder into your server resources.
2. Add `ensure democracy` to your server config.
3. Import `democracy/SQLSetup.sql` into your database.
4. Configure positions, locations, and state setup in `democracy/config.lua`.
5. (Optional) Configure Discord webhook values in `Config.Webhooks`.

## Commands

- `/electionresults`: Opens election results menu (admin/election official flow).

## Two-State System (USA / Mexico)

The script is already partially integrated for two states:

- State field exists in all core election tables (`ballot`, `ballot_registration`, `ballot_votes`, `election_cycles`, `election_winners`).
- Config includes distinct USA and Mexico federal/state/local office sets.
- Config includes Mexico voting booths (Escalera, Chuparosa).
- State-aware cleanup exists (`cleanupScript` event and `post_election_cleanup_script.sql`).
- Automatic cycle processor iterates states from configured voting locations.

Current limitations of the two-state setup:

- Federal/state split is done via position definitions. If you add shared position names across both states, votes will merge by office name.

## Historical Setting (1870-1899)

The default config now includes a 1870-1899 flavored office preset for both USA and Mexico.

To better match that era, adjust:

- Office titles (for example region-specific and period-appropriate roles).
- Jurisdiction naming and government structure for your lore timeline.
- Language/UI text in `lang.lua`.
- Voting locations and regions in `config.lua`.

## Known Issues (Important)

- No critical known issues at the moment.

## Manual Cleanup

Use `democracy/post_election_cleanup_script.sql` to delete election data for a specific state (default example is USA; replace with Mexico if needed).

## Support

Discord: `hannibal_lickedher`
