-- To delete all election data for a specific state, replace 'USA' with the desired state (e.g., 'Mexico') and run the queries.

-- Delete ballots for the specified state
DELETE FROM ballot WHERE state = 'USA';

-- Delete votes for the specified state
DELETE FROM ballot_votes WHERE state = 'USA';

-- Delete registrations for the specified state
DELETE FROM ballot_registration WHERE state = 'USA';
