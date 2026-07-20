-- Residence and election lookup indexes
-- Run this on existing databases after the residence filtering update.

ALTER TABLE ballot
  ADD INDEX idx_ballot_character_id (character_id),
  ADD INDEX idx_ballot_state_position (state, position),
  ADD INDEX idx_ballot_state_region (state, region),
  ADD INDEX idx_ballot_state_city (state, city);

ALTER TABLE ballot_registration
  ADD INDEX idx_ballot_registration_voter_location (voterID, state, registrationRegion, registrationCity);

ALTER TABLE ballot_votes
  ADD INDEX idx_ballot_votes_ballotID (ballotID);
