-- Keep every successful application as a traceable reference record, then
-- create one reporting member for each membership ID.
--
-- Section 1's ID is last name + a truncated birthday hash, so collisions are
-- possible. The lowest loaded reference key is chosen deterministically for
-- dim_member; the complete source set remains in the reference table.

CREATE TEMP TABLE successful_member_stage (
    first_name TEXT,
    last_name TEXT,
    email TEXT,
    date_of_birth TEXT,
    mobile_no TEXT,
    above_18 TEXT,
    membership_id TEXT,
    validation_errors TEXT
);

COPY successful_member_stage
FROM '/seed/successful_applications.csv'
WITH (FORMAT csv, HEADER true);

INSERT INTO analytics.member_application_reference (
    membership_id,
    first_name,
    last_name,
    email,
    date_of_birth,
    mobile_no,
    above_18
)
SELECT
    membership_id,
    first_name,
    last_name,
    email,
    TO_DATE(date_of_birth, 'YYYYMMDD'),
    mobile_no,
    above_18::BOOLEAN
FROM successful_member_stage;

INSERT INTO analytics.dim_member (
    membership_id,
    first_name,
    last_name,
    email,
    above_18
)
SELECT DISTINCT ON (membership_id)
    membership_id,
    first_name,
    last_name,
    email,
    above_18
FROM analytics.member_application_reference
ORDER BY membership_id, application_reference_key;
