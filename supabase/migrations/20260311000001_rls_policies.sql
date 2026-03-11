-- =============================================================================
-- Migration: Row Level Security Policies
-- Project:   UKLC Booking System
-- Created:   2026-03-11
-- =============================================================================
-- Roles (stored in staff.role):
--   admin           — full access everywhere
--   sales           — full access to Sales Pipeline; read-only on Bookings
--   operations      — full access to Bookings & Centre View; read-only on Sales
--   coordinator     — full access to their assigned groups + associated records
--   centre_manager  — read-only for their centre's groups and students
--                     NOTE: centre scoping requires staff.centre_id (not yet in
--                     schema). Until added, centre_manager gets org-wide read.
-- =============================================================================


-- =============================================================================
-- Helper functions
-- security definer so they run as the function owner (bypassing RLS on staff),
-- preventing infinite recursion when staff itself has RLS enabled.
-- =============================================================================

create or replace function auth_org_id()
returns uuid
language sql
security definer
stable
as $$
  select organisation_id
  from   staff
  where  user_id = auth.uid()
  limit  1
$$;

create or replace function auth_role()
returns text
language sql
security definer
stable
as $$
  select role
  from   staff
  where  user_id = auth.uid()
  limit  1
$$;

create or replace function auth_staff_id()
returns uuid
language sql
security definer
stable
as $$
  select id
  from   staff
  where  user_id = auth.uid()
  limit  1
$$;


-- =============================================================================
-- Enable RLS on all tables
-- =============================================================================

alter table organisations      enable row level security;
alter table staff              enable row level security;
alter table centres            enable row level security;
alter table programmes         enable row level security;
alter table programme_weeks    enable row level security;
alter table agents             enable row level security;
alter table groups             enable row level security;
alter table group_weeks        enable row level security;
alter table students           enable row level security;
alter table transfers          enable row level security;
alter table allocation_slots   enable row level security;
alter table leads              enable row level security;


-- =============================================================================
-- Grant table-level permissions to authenticated users
-- RLS policies then restrict what each role can actually see/do.
-- =============================================================================

grant select, insert, update, delete on organisations      to authenticated;
grant select, insert, update, delete on staff              to authenticated;
grant select, insert, update, delete on centres            to authenticated;
grant select, insert, update, delete on programmes         to authenticated;
grant select, insert, update, delete on programme_weeks    to authenticated;
grant select, insert, update, delete on agents             to authenticated;
grant select, insert, update, delete on groups             to authenticated;
grant select, insert, update, delete on group_weeks        to authenticated;
grant select, insert, update, delete on students           to authenticated;
grant select, insert, update, delete on transfers          to authenticated;
grant select, insert, update, delete on allocation_slots   to authenticated;
grant select, insert, update, delete on leads              to authenticated;


-- =============================================================================
-- organisations
-- =============================================================================

create policy "organisations: authenticated users read own org"
  on organisations for select
  using (id = auth_org_id());

create policy "organisations: admin can update"
  on organisations for update
  using (id = auth_org_id() and auth_role() = 'admin');

-- INSERT/DELETE intentionally omitted — done via service role during onboarding.


-- =============================================================================
-- staff
-- =============================================================================

create policy "staff: read own org"
  on staff for select
  using (organisation_id = auth_org_id());

create policy "staff: admin can insert"
  on staff for insert
  with check (organisation_id = auth_org_id() and auth_role() = 'admin');

create policy "staff: admin can update"
  on staff for update
  using (organisation_id = auth_org_id() and auth_role() = 'admin');

create policy "staff: admin can delete"
  on staff for delete
  using (organisation_id = auth_org_id() and auth_role() = 'admin');


-- =============================================================================
-- centres
-- =============================================================================

create policy "centres: all authenticated can read own org"
  on centres for select
  using (organisation_id = auth_org_id());

create policy "centres: admin can insert"
  on centres for insert
  with check (organisation_id = auth_org_id() and auth_role() = 'admin');

create policy "centres: admin or operations can update"
  on centres for update
  using (organisation_id = auth_org_id() and auth_role() in ('admin', 'operations'));

create policy "centres: admin can delete"
  on centres for delete
  using (organisation_id = auth_org_id() and auth_role() = 'admin');


-- =============================================================================
-- programmes
-- =============================================================================

create policy "programmes: all authenticated can read own org"
  on programmes for select
  using (organisation_id = auth_org_id());

create policy "programmes: admin can insert"
  on programmes for insert
  with check (organisation_id = auth_org_id() and auth_role() = 'admin');

create policy "programmes: admin can update"
  on programmes for update
  using (organisation_id = auth_org_id() and auth_role() = 'admin');

create policy "programmes: admin can delete"
  on programmes for delete
  using (organisation_id = auth_org_id() and auth_role() = 'admin');


-- =============================================================================
-- programme_weeks
-- =============================================================================

create policy "programme_weeks: all authenticated can read own org"
  on programme_weeks for select
  using (
    exists (
      select 1 from programmes p
      where  p.id = programme_weeks.programme_id
      and    p.organisation_id = auth_org_id()
    )
  );

create policy "programme_weeks: admin or operations can insert"
  on programme_weeks for insert
  with check (
    exists (
      select 1 from programmes p
      where  p.id = programme_weeks.programme_id
      and    p.organisation_id = auth_org_id()
    )
    and auth_role() in ('admin', 'operations')
  );

create policy "programme_weeks: admin or operations can update"
  on programme_weeks for update
  using (
    exists (
      select 1 from programmes p
      where  p.id = programme_weeks.programme_id
      and    p.organisation_id = auth_org_id()
    )
    and auth_role() in ('admin', 'operations')
  );

create policy "programme_weeks: admin can delete"
  on programme_weeks for delete
  using (
    exists (
      select 1 from programmes p
      where  p.id = programme_weeks.programme_id
      and    p.organisation_id = auth_org_id()
    )
    and auth_role() = 'admin'
  );


-- =============================================================================
-- agents
-- =============================================================================

create policy "agents: all authenticated can read own org"
  on agents for select
  using (organisation_id = auth_org_id());

create policy "agents: admin or sales can insert"
  on agents for insert
  with check (organisation_id = auth_org_id() and auth_role() in ('admin', 'sales'));

create policy "agents: admin or sales can update"
  on agents for update
  using (organisation_id = auth_org_id() and auth_role() in ('admin', 'sales'));

create policy "agents: admin can delete"
  on agents for delete
  using (organisation_id = auth_org_id() and auth_role() = 'admin');


-- =============================================================================
-- groups
-- Read access:
--   admin, sales, operations  — all groups in the org
--   coordinator               — only groups assigned to them
--   centre_manager            — all groups in org (centre scoping: see TODO above)
-- Write access:
--   admin, operations         — any group in org
--   coordinator               — only their assigned groups
-- =============================================================================

create policy "groups: admin/sales/operations/centre_manager read all in org"
  on groups for select
  using (
    organisation_id = auth_org_id()
    and auth_role() in ('admin', 'sales', 'operations', 'centre_manager')
  );

create policy "groups: coordinator reads own groups"
  on groups for select
  using (
    organisation_id = auth_org_id()
    and auth_role() = 'coordinator'
    and coordinator_id = auth_staff_id()
  );

create policy "groups: admin or operations can insert"
  on groups for insert
  with check (organisation_id = auth_org_id() and auth_role() in ('admin', 'operations'));

create policy "groups: admin or operations can update any group"
  on groups for update
  using (organisation_id = auth_org_id() and auth_role() in ('admin', 'operations'));

create policy "groups: coordinator can update own groups"
  on groups for update
  using (
    organisation_id = auth_org_id()
    and auth_role() = 'coordinator'
    and coordinator_id = auth_staff_id()
  );

create policy "groups: admin can delete"
  on groups for delete
  using (organisation_id = auth_org_id() and auth_role() = 'admin');


-- =============================================================================
-- group_weeks
-- No organisation_id column — scope via parent groups table.
-- =============================================================================

create policy "group_weeks: admin/sales/operations/centre_manager read"
  on group_weeks for select
  using (
    exists (
      select 1 from groups g
      where  g.id = group_weeks.group_id
      and    g.organisation_id = auth_org_id()
    )
    and auth_role() in ('admin', 'sales', 'operations', 'centre_manager')
  );

create policy "group_weeks: coordinator reads own group weeks"
  on group_weeks for select
  using (
    auth_role() = 'coordinator'
    and exists (
      select 1 from groups g
      where  g.id = group_weeks.group_id
      and    g.organisation_id = auth_org_id()
      and    g.coordinator_id = auth_staff_id()
    )
  );

create policy "group_weeks: admin or operations can insert"
  on group_weeks for insert
  with check (
    auth_role() in ('admin', 'operations')
    and exists (
      select 1 from groups g
      where  g.id = group_weeks.group_id
      and    g.organisation_id = auth_org_id()
    )
  );

create policy "group_weeks: admin or operations can update"
  on group_weeks for update
  using (
    auth_role() in ('admin', 'operations')
    and exists (
      select 1 from groups g
      where  g.id = group_weeks.group_id
      and    g.organisation_id = auth_org_id()
    )
  );

create policy "group_weeks: coordinator can update own group weeks"
  on group_weeks for update
  using (
    auth_role() = 'coordinator'
    and exists (
      select 1 from groups g
      where  g.id = group_weeks.group_id
      and    g.organisation_id = auth_org_id()
      and    g.coordinator_id = auth_staff_id()
    )
  );

create policy "group_weeks: admin can delete"
  on group_weeks for delete
  using (
    auth_role() = 'admin'
    and exists (
      select 1 from groups g
      where  g.id = group_weeks.group_id
      and    g.organisation_id = auth_org_id()
    )
  );


-- =============================================================================
-- students
-- No organisation_id column — scope via parent groups table.
-- centre_manager gets org-wide read (centre scoping: see TODO above).
-- sales gets read-only (they need student counts; not write access).
-- =============================================================================

create policy "students: admin/sales/operations/centre_manager read"
  on students for select
  using (
    organisation_id = auth_org_id()
    and auth_role() in ('admin', 'sales', 'operations', 'centre_manager')
  );

create policy "students: coordinator reads own group students"
  on students for select
  using (
    organisation_id = auth_org_id()
    and auth_role() = 'coordinator'
    and exists (
      select 1 from groups g
      where  g.id = students.group_id
      and    g.coordinator_id = auth_staff_id()
    )
  );

create policy "students: admin or operations can insert"
  on students for insert
  with check (organisation_id = auth_org_id() and auth_role() in ('admin', 'operations'));

create policy "students: coordinator can insert into own groups"
  on students for insert
  with check (
    organisation_id = auth_org_id()
    and auth_role() = 'coordinator'
    and exists (
      select 1 from groups g
      where  g.id = students.group_id
      and    g.coordinator_id = auth_staff_id()
    )
  );

create policy "students: admin or operations can update"
  on students for update
  using (organisation_id = auth_org_id() and auth_role() in ('admin', 'operations'));

create policy "students: coordinator can update own group students"
  on students for update
  using (
    organisation_id = auth_org_id()
    and auth_role() = 'coordinator'
    and exists (
      select 1 from groups g
      where  g.id = students.group_id
      and    g.coordinator_id = auth_staff_id()
    )
  );

create policy "students: admin or operations can delete"
  on students for delete
  using (organisation_id = auth_org_id() and auth_role() in ('admin', 'operations'));


-- =============================================================================
-- transfers
-- No organisation_id column — scope via parent groups table.
-- =============================================================================

create policy "transfers: admin/sales/operations/centre_manager read"
  on transfers for select
  using (
    auth_role() in ('admin', 'sales', 'operations', 'centre_manager')
    and exists (
      select 1 from groups g
      where  g.id = transfers.group_id
      and    g.organisation_id = auth_org_id()
    )
  );

create policy "transfers: coordinator reads own group transfers"
  on transfers for select
  using (
    auth_role() = 'coordinator'
    and exists (
      select 1 from groups g
      where  g.id = transfers.group_id
      and    g.organisation_id = auth_org_id()
      and    g.coordinator_id = auth_staff_id()
    )
  );

create policy "transfers: admin or operations can insert"
  on transfers for insert
  with check (
    auth_role() in ('admin', 'operations')
    and exists (
      select 1 from groups g
      where  g.id = transfers.group_id
      and    g.organisation_id = auth_org_id()
    )
  );

create policy "transfers: coordinator can insert for own groups"
  on transfers for insert
  with check (
    auth_role() = 'coordinator'
    and exists (
      select 1 from groups g
      where  g.id = transfers.group_id
      and    g.organisation_id = auth_org_id()
      and    g.coordinator_id = auth_staff_id()
    )
  );

create policy "transfers: admin or operations can update"
  on transfers for update
  using (
    auth_role() in ('admin', 'operations')
    and exists (
      select 1 from groups g
      where  g.id = transfers.group_id
      and    g.organisation_id = auth_org_id()
    )
  );

create policy "transfers: coordinator can update own group transfers"
  on transfers for update
  using (
    auth_role() = 'coordinator'
    and exists (
      select 1 from groups g
      where  g.id = transfers.group_id
      and    g.organisation_id = auth_org_id()
      and    g.coordinator_id = auth_staff_id()
    )
  );

create policy "transfers: admin can delete"
  on transfers for delete
  using (
    auth_role() = 'admin'
    and exists (
      select 1 from groups g
      where  g.id = transfers.group_id
      and    g.organisation_id = auth_org_id()
    )
  );


-- =============================================================================
-- allocation_slots
-- Sales Pipeline data — admin and sales have full access; operations read-only.
-- coordinators and centre_managers have no access.
-- =============================================================================

create policy "allocation_slots: admin/sales/operations can read"
  on allocation_slots for select
  using (organisation_id = auth_org_id() and auth_role() in ('admin', 'sales', 'operations'));

create policy "allocation_slots: admin or sales can insert"
  on allocation_slots for insert
  with check (organisation_id = auth_org_id() and auth_role() in ('admin', 'sales'));

create policy "allocation_slots: admin or sales can update"
  on allocation_slots for update
  using (organisation_id = auth_org_id() and auth_role() in ('admin', 'sales'));

create policy "allocation_slots: admin can delete"
  on allocation_slots for delete
  using (organisation_id = auth_org_id() and auth_role() = 'admin');


-- =============================================================================
-- leads
-- Sales Pipeline data — admin and sales only.
-- =============================================================================

create policy "leads: admin or sales can read"
  on leads for select
  using (organisation_id = auth_org_id() and auth_role() in ('admin', 'sales'));

create policy "leads: admin or sales can insert"
  on leads for insert
  with check (organisation_id = auth_org_id() and auth_role() in ('admin', 'sales'));

create policy "leads: admin or sales can update"
  on leads for update
  using (organisation_id = auth_org_id() and auth_role() in ('admin', 'sales'));

create policy "leads: admin can delete"
  on leads for delete
  using (organisation_id = auth_org_id() and auth_role() = 'admin');
