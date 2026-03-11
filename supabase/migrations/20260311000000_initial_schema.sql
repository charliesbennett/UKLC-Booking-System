-- =============================================================================
-- Migration: Initial Schema
-- Project:   UKLC Booking System
-- Created:   2026-03-11
-- =============================================================================

-- ---------------------------------------------------------------------------
-- organisations
-- Root tenant table. All other tables reference this for isolation.
-- ---------------------------------------------------------------------------
create table organisations (
  id          uuid        primary key default gen_random_uuid(),
  name        text        not null,
  slug        text        not null unique,
  config      jsonb       not null default '{}',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- staff
-- Must be created before agents (agents FK → staff).
-- ---------------------------------------------------------------------------
create table staff (
  id               uuid        primary key default gen_random_uuid(),
  organisation_id  uuid        not null references organisations(id),
  user_id          uuid        references auth.users(id),
  name             text        not null,
  code             text,                      -- e.g. 'CA', 'JG', 'SH'
  role             text,                      -- admin | sales | operations | coordinator | centre_manager
  active           boolean     not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- centres
-- ---------------------------------------------------------------------------
create table centres (
  id               uuid        primary key default gen_random_uuid(),
  organisation_id  uuid        not null references organisations(id),
  name             text        not null,
  short_name       text,
  location         text,
  capacity         integer,
  active           boolean     not null default true,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- programmes
-- ---------------------------------------------------------------------------
create table programmes (
  id               uuid        primary key default gen_random_uuid(),
  organisation_id  uuid        not null references organisations(id),
  name             text        not null,
  type             text        not null,      -- junior_group | junior_out_of_summer | junior_individual | ministay
  year             integer     not null,
  start_date       date,
  end_date         date,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- programme_weeks
-- One row per centre per week of a programme.
-- booked_count / allocated_count are maintained by application logic.
-- ---------------------------------------------------------------------------
create table programme_weeks (
  id               uuid        primary key default gen_random_uuid(),
  programme_id     uuid        not null references programmes(id),
  centre_id        uuid        not null references centres(id),
  week_start       date        not null,
  capacity         integer     not null default 0,
  booked_count     integer     not null default 0,
  allocated_count  integer     not null default 0,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- agents
-- ---------------------------------------------------------------------------
create table agents (
  id                        uuid        primary key default gen_random_uuid(),
  organisation_id           uuid        not null references organisations(id),
  code                      text,              -- e.g. '001501' legacy system code
  name                      text        not null,
  country                   text,
  nationality_group         text,              -- Italian | Non-Italian | etc.
  contact_name              text,
  contact_email             text,
  contact_phone             text,
  account_manager_id        uuid        references staff(id),
  booking_coordinator_id    uuid        references staff(id),
  status                    text        not null default 'active',  -- active | lead | lapsed | new
  priority                  integer,           -- 1–4 sales priority
  notes                     text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- groups
-- Core booking entity — a group of students from one agent at one centre.
-- ---------------------------------------------------------------------------
create table groups (
  id                         uuid        primary key default gen_random_uuid(),
  organisation_id            uuid        not null references organisations(id),
  group_number               text        unique,    -- e.g. '006742', auto-generated
  name                       text,                  -- e.g. 'Sunho Business'
  agent_id                   uuid        references agents(id),
  centre_id                  uuid        references centres(id),
  programme_id               uuid        references programmes(id),
  coordinator_id             uuid        references staff(id),
  status                     text        not null default 'provisional',  -- provisional | confirmed | cancelled
  nationality                text,
  arrival_date               date,
  departure_date             date,
  arrival_flight             text,
  arrival_time               time,
  arrival_airport            text,
  arrival_meal               text,              -- breakfast | lunch | dinner | none
  arrival_transfer           boolean     not null default false,
  arrival_transfer_provider  text,
  departure_flight           text,
  departure_time             time,
  departure_airport          text,
  departure_meal             text,              -- breakfast | lunch | dinner | none
  departure_transfer         boolean     not null default false,
  gl_mobile                  text,
  agent_emergency_contact    text,
  non_standard_programme     boolean     not null default false,
  gcs_notes                  text,
  internal_notes             text,
  programme_notes            text,
  date_confirmed             date,
  year                       integer,
  created_at                 timestamptz not null default now(),
  updated_at                 timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- group_weeks
-- Links a group to specific programme weeks; tracks headcount per week.
-- ---------------------------------------------------------------------------
create table group_weeks (
  id                  uuid        primary key default gen_random_uuid(),
  group_id            uuid        not null references groups(id),
  programme_week_id   uuid        not null references programme_weeks(id),
  student_count       integer     not null default 0,
  gl_count            integer     not null default 0,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- students
-- ---------------------------------------------------------------------------
create table students (
  id                        uuid        primary key default gen_random_uuid(),
  organisation_id           uuid        not null references organisations(id),
  student_code              text,              -- e.g. '044566'
  group_id                  uuid        references groups(id),
  forename                  text,
  surname                   text,
  date_of_birth             date,
  gender                    text,              -- Male | Female | Other
  is_group_leader           boolean     not null default false,
  nationality               text,
  country                   text,
  passport_number           text,
  passport_expiry           date,
  level_of_english          text,              -- Beginner | Elementary | Pre-Int | Intermediate | Upper-Int | Advanced
  swimming_ability          text,
  accommodation_type        text,
  medical_dietary_notes     text,
  contact_name              text,              -- Parent/guardian
  contact_phone             text,
  contact_level_of_english  text,
  marketing_consent         boolean,
  arrival_comments          text,
  created_at                timestamptz not null default now(),
  updated_at                timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- transfers
-- Arrival or departure transfer record for a group.
-- ---------------------------------------------------------------------------
create table transfers (
  id               uuid        primary key default gen_random_uuid(),
  group_id         uuid        not null references groups(id),
  type             text        not null,      -- arrival | departure
  date             date,
  flight_number    text,
  flight_time      time,
  airport          text,
  driver           text,                      -- Driver/coach company name
  is_own_transfer  boolean     not null default false,
  total_students   integer,
  group_diff       integer,                   -- difference from group total (late arrivals etc.)
  individual_name  text,                      -- for individual transfers not part of group
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- allocation_slots
-- Pre-agreed capacity allocations per agent per programme week.
-- ---------------------------------------------------------------------------
create table allocation_slots (
  id                  uuid           primary key default gen_random_uuid(),
  organisation_id     uuid           not null references organisations(id),
  agent_id            uuid           not null references agents(id),
  programme_week_id   uuid           not null references programme_weeks(id),
  allocated_students  integer        not null default 0,
  price_per_student   numeric(8, 2),
  status              text           not null default 'not_contacted',  -- not_contacted | in_discussion | prices_confirmed | booked | cancelled
  notes               text,
  created_at          timestamptz    not null default now(),
  updated_at          timestamptz    not null default now()
);

-- ---------------------------------------------------------------------------
-- leads
-- Prospective agents before a formal agent record is created.
-- ---------------------------------------------------------------------------
create table leads (
  id                   uuid        primary key default gen_random_uuid(),
  organisation_id      uuid        not null references organisations(id),
  agent_name           text,
  account_manager_id   uuid        references staff(id),
  nationality          text,
  status               text        not null default 'not_contacted',  -- not_contacted | engaged | in_discussion | converted | lapsed
  priority             integer,           -- 1–4
  notes_2026           text,
  historic_notes       text,
  last_booked_year     integer,
  converted_agent_id   uuid        references agents(id),
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- =============================================================================
-- updated_at trigger function
-- =============================================================================
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- Apply trigger to all tables with updated_at
do $$
declare
  t text;
begin
  foreach t in array array[
    'organisations',
    'staff',
    'centres',
    'programmes',
    'programme_weeks',
    'agents',
    'groups',
    'group_weeks',
    'students',
    'transfers',
    'allocation_slots',
    'leads'
  ]
  loop
    execute format(
      'create trigger trg_%s_updated_at
       before update on %s
       for each row execute function set_updated_at()',
      t, t
    );
  end loop;
end;
$$;

-- =============================================================================
-- Indexes
-- =============================================================================

-- Tenant isolation — most queries filter by organisation_id
create index idx_staff_org               on staff(organisation_id);
create index idx_centres_org             on centres(organisation_id);
create index idx_programmes_org          on programmes(organisation_id);
create index idx_agents_org              on agents(organisation_id);
create index idx_groups_org              on groups(organisation_id);
create index idx_students_org            on students(organisation_id);
create index idx_allocation_slots_org    on allocation_slots(organisation_id);
create index idx_leads_org               on leads(organisation_id);

-- Programme weeks
create index idx_programme_weeks_programme  on programme_weeks(programme_id);
create index idx_programme_weeks_centre     on programme_weeks(centre_id);
create index idx_programme_weeks_week_start on programme_weeks(week_start);

-- Groups
create index idx_groups_agent      on groups(agent_id);
create index idx_groups_centre     on groups(centre_id);
create index idx_groups_programme  on groups(programme_id);
create index idx_groups_status     on groups(status);

-- Group weeks
create index idx_group_weeks_group           on group_weeks(group_id);
create index idx_group_weeks_programme_week  on group_weeks(programme_week_id);

-- Students
create index idx_students_group  on students(group_id);

-- Transfers
create index idx_transfers_group  on transfers(group_id);
create index idx_transfers_type   on transfers(type);

-- Allocation slots
create index idx_allocation_slots_agent          on allocation_slots(agent_id);
create index idx_allocation_slots_programme_week on allocation_slots(programme_week_id);
create index idx_allocation_slots_status         on allocation_slots(status);

-- Agents
create index idx_agents_status  on agents(status);
create index idx_agents_code    on agents(code);

-- Leads
create index idx_leads_status              on leads(status);
create index idx_leads_account_manager    on leads(account_manager_id);
create index idx_leads_converted_agent    on leads(converted_agent_id);

-- Staff
create index idx_staff_user_id  on staff(user_id);
