-- Vote uniqueness migration
-- Goal: enforce one vote per voter/race (office + jurisdiction + location + state)

-- 1) Remove duplicates first, keep the oldest vote row per race.
DELETE v1
FROM ballot_votes v1
JOIN ballot_votes v2
  ON v1.voterID = v2.voterID
 AND IFNULL(v1.office, '') = IFNULL(v2.office, '')
 AND IFNULL(v1.jurisdiction, '') = IFNULL(v2.jurisdiction, '')
 AND IFNULL(v1.location, '') = IFNULL(v2.location, '')
 AND IFNULL(v1.state, '') = IFNULL(v2.state, '')
 AND v1.voteID > v2.voteID;

-- 2) Add database-level uniqueness guard.
ALTER TABLE ballot_votes
  ADD UNIQUE KEY uq_ballot_votes_voter_race (voterID, office, jurisdiction, location, state);
