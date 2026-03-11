-- =============================================================================
-- Seed: UKLC Organisation + First Admin User
-- Project:   UKLC Booking System
-- Created:   2026-03-11
--
-- HOW TO USE:
--   1. Go to Supabase → Authentication → Users
--   2. Copy your user's UUID
--   3. Replace <<YOUR_AUTH_USER_UUID>> below with that UUID
--   4. Run in the SQL editor (runs as postgres, bypasses RLS)
-- =============================================================================

-- Step 1: Insert the UKLC organisation
insert into organisations (id, name, slug, config)
values (
  gen_random_uuid(),
  'UKLC',
  'uklc',
  '{
    "branding": {
      "primary_colour": "#003366"
    },
    "terminology": {
      "group": "group",
      "centre": "centre",
      "programme": "programme"
    }
  }'
);

-- Step 2: Insert your staff record as admin
-- Replace <<YOUR_AUTH_USER_UUID>> with your UUID from Supabase Auth → Users
insert into staff (id, organisation_id, user_id, name, code, role, active)
values (
  gen_random_uuid(),
  (select id from organisations where slug = 'uklc'),
  '<<YOUR_AUTH_USER_UUID>>',   -- ← replace this
  'Charlie Sterndale-Bennett',
  'CS',
  'admin',
  true
);

-- Verify
select
  o.name  as organisation,
  s.name  as staff_name,
  s.role,
  s.code,
  s.user_id
from staff s
join organisations o on o.id = s.organisation_id
where o.slug = 'uklc';
