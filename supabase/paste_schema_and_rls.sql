-- 0001_schema.sql — enums, tables, indexes, closure + updated_at triggers.
-- RLS is enabled on every table here, at creation time. Policies, grants and
-- the hierarchy helper functions live in 0002_rls.sql; until that runs every
-- table is deny-all.

-- Hygiene: objects this role creates from now on are not exposed to anon.
alter default privileges in schema public revoke all on tables    from anon;
alter default privileges in schema public revoke all on sequences from anon;
alter default privileges in schema public revoke all on functions from anon;

-- ---------------------------------------------------------------- enums
create type public.agent_role    as enum ('agent', 'manager', 'founder');
create type public.agent_status  as enum ('active', 'inactive', 'terminated');
create type public.lead_stage    as enum ('lead', 'client');
create type public.disposition   as enum ('new', 'text_campaign', 'response', 'must_call',
                                           'no_answer', 'not_interested', 'follow_up', 'sold');
create type public.activity_type as enum ('call', 'text', 'email', 'underwriting', 'note');
create type public.product_type  as enum ('fex', 'iul', 'term', 'adb');
create type public.policy_status as enum ('pending_underwriting', 'active', 'lapsed',
                                          'declined', 'cancelled');

-- ---------------------------------------------------------------- tables
create table public.agents (
  id             uuid primary key references auth.users (id),
  full_name      text not null,
  email          text not null,
  npn            text,
  resident_state text,
  comp_level     numeric(5,2),                       -- contract percentage, e.g. 90.00
  role           public.agent_role   not null default 'agent',
  status         public.agent_status not null default 'active',
  upline_id      uuid references public.agents (id),
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint agents_not_own_upline check (upline_id is distinct from id)
);

-- Materialised hierarchy: one row per (ancestor, descendant) pair, including
-- a depth-0 self row per agent. Maintained only by triggers on agents.
create table public.agent_closure (
  ancestor_id   uuid not null references public.agents (id) on delete cascade,
  descendant_id uuid not null references public.agents (id) on delete cascade,
  depth         int  not null check (depth >= 0),
  primary key (ancestor_id, descendant_id)
);

create table public.lead_vendors (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  cost_per_lead numeric(10,2),
  created_at    timestamptz not null default now()
);

-- Lead and client are one record, distinguished by stage.
create table public.leads (
  id              uuid primary key default gen_random_uuid(),
  owner_agent_id  uuid not null references public.agents (id),
  first_name      text,
  last_name       text,
  phone           text,
  email           text,
  date_of_birth   date,
  state           text,
  stage           public.lead_stage  not null default 'lead',
  disposition     public.disposition not null default 'new',
  lead_vendor_id  uuid references public.lead_vendors (id),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.lead_activity (
  id          uuid primary key default gen_random_uuid(),
  lead_id     uuid not null references public.leads (id) on delete cascade,
  agent_id    uuid not null references public.agents (id),
  type        public.activity_type not null,
  body        text,
  occurred_at timestamptz not null default now()
);

create table public.carriers (
  id         uuid primary key default gen_random_uuid(),
  name       text not null,
  created_at timestamptz not null default now()
);

create table public.products (
  id         uuid primary key default gen_random_uuid(),
  carrier_id uuid not null references public.carriers (id),
  name       text not null,
  type       public.product_type not null,
  -- lets policies prove (product, carrier) belong together
  constraint products_id_carrier_key unique (id, carrier_id)
);

create table public.policies (
  id               uuid primary key default gen_random_uuid(),
  client_id        uuid not null references public.leads (id),
  writing_agent_id uuid not null references public.agents (id),
  carrier_id       uuid not null references public.carriers (id),
  product_id       uuid not null references public.products (id),
  policy_number    text,
  face_amount      numeric(12,2),
  annual_premium   numeric(12,2),                    -- AP
  monthly_premium  numeric(10,2),
  status           public.policy_status not null default 'pending_underwriting',
  effective_date   date,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint policies_product_matches_carrier
    foreign key (product_id, carrier_id) references public.products (id, carrier_id)
);

-- GLOBAL per person, never per campaign (consent revocation must apply everywhere).
create table public.opt_outs (
  id          uuid primary key default gen_random_uuid(),
  phone       text not null unique,
  opted_out_at timestamptz not null default now(),
  source      text
);

-- ---------------------------------------------------------------- RLS on, everywhere
alter table public.agents        enable row level security;
alter table public.agent_closure enable row level security;
alter table public.lead_vendors  enable row level security;
alter table public.leads         enable row level security;
alter table public.lead_activity enable row level security;
alter table public.carriers      enable row level security;
alter table public.products      enable row level security;
alter table public.policies      enable row level security;
alter table public.opt_outs      enable row level security;

-- ---------------------------------------------------------------- indexes (every FK)
create index agents_upline_id_idx            on public.agents (upline_id);
create index agent_closure_descendant_idx    on public.agent_closure (descendant_id);  -- ancestor_id is the PK prefix
create index leads_owner_disposition_idx     on public.leads (owner_agent_id, disposition);
create index leads_lead_vendor_id_idx        on public.leads (lead_vendor_id);
create index lead_activity_lead_id_idx       on public.lead_activity (lead_id);
create index lead_activity_agent_id_idx      on public.lead_activity (agent_id);
create index products_carrier_id_idx         on public.products (carrier_id);
create index policies_client_id_idx          on public.policies (client_id);
create index policies_writing_agent_status_idx on public.policies (writing_agent_id, status);
create index policies_carrier_id_idx         on public.policies (carrier_id);
create index policies_product_carrier_idx    on public.policies (product_id, carrier_id);

-- ---------------------------------------------------------------- updated_at
create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger agents_set_updated_at   before update on public.agents
  for each row execute function public.set_updated_at();
create trigger leads_set_updated_at    before update on public.leads
  for each row execute function public.set_updated_at();
create trigger policies_set_updated_at before update on public.policies
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------- hierarchy triggers
-- Cycle guard. Runs before the row is written, so a rejected change leaves
-- both agents and agent_closure untouched.
create function public.agents_reject_cycle() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.upline_id is null then
    return new;
  end if;

  -- serialise hierarchy edits so two concurrent moves cannot jointly create a cycle
  perform pg_advisory_xact_lock(hashtext('public.agent_closure'));

  if new.upline_id = new.id
     or exists (select 1 from public.agent_closure
                 where ancestor_id = new.id and descendant_id = new.upline_id) then
    raise exception 'agent hierarchy cycle: % cannot report to % (own descendant)',
      new.id, new.upline_id
      using errcode = 'check_violation', constraint = 'agents_no_hierarchy_cycle';
  end if;
  return new;
end $$;

create trigger agents_reject_cycle
  before insert or update of upline_id on public.agents
  for each row when (new.upline_id is not null)
  execute function public.agents_reject_cycle();

-- Rebuilds closure rows for the agent and its whole subtree.
--   1. drop every link from the agent's OLD strict ancestors into its subtree
--   2. link every ancestor of the NEW upline (incl. the upline) to every
--      member of the subtree, depth = up.depth + sub.depth + 1
create function public.agents_closure_maintain() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(hashtext('public.agent_closure'));

  if tg_op = 'INSERT' then
    insert into public.agent_closure (ancestor_id, descendant_id, depth)
    values (new.id, new.id, 0);
  else
    delete from public.agent_closure ac
     where ac.descendant_id in (select descendant_id from public.agent_closure
                                 where ancestor_id = new.id)
       and ac.ancestor_id   in (select ancestor_id from public.agent_closure
                                 where descendant_id = new.id and ancestor_id <> new.id);
  end if;

  if new.upline_id is not null then
    insert into public.agent_closure (ancestor_id, descendant_id, depth)
    select up.ancestor_id, sub.descendant_id, up.depth + sub.depth + 1
      from public.agent_closure up
      join public.agent_closure sub on sub.ancestor_id = new.id
     where up.descendant_id = new.upline_id;
  end if;
  return null;
end $$;

create trigger agents_closure_insert
  after insert on public.agents
  for each row execute function public.agents_closure_maintain();
create trigger agents_closure_update
  after update of upline_id on public.agents
  for each row when (old.upline_id is distinct from new.upline_id)
  execute function public.agents_closure_maintain();

revoke all on function public.set_updated_at(), public.agents_reject_cycle(),
  public.agents_closure_maintain() from public, anon, authenticated;
-- 0002_rls.sql — hierarchy helpers, privilege grants, RLS policies.

-- ---------------------------------------------------------------- helpers
-- SECURITY DEFINER so they can read agents / agent_closure without recursing
-- through those tables' own policies. STABLE, empty search_path, no anon.

create function public.current_agent_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select auth.uid()
$$;

create function public.is_founder() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.agents
                  where id = auth.uid() and role = 'founder')
$$;

-- True for any authenticated user that has an agents row. Keeps self-signed-up
-- auth users (no agent record) away from shared reference data and opt_outs.
create function public.is_agent() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.agents where id = auth.uid())
$$;

create function public.can_see_agent(target uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select public.is_founder()
      or target = public.current_agent_id()
      or exists (select 1 from public.agent_closure
                  where ancestor_id = public.current_agent_id()
                    and descendant_id = target)
$$;

-- Guard for the founder-only columns on agents. SECURITY INVOKER on purpose:
-- current_user is the real caller. Trusted server-side roles (migrations,
-- service_role) pass; everyone else must be a founder.
create function public.agents_guard_privileged_columns() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (new.role, new.comp_level, new.upline_id, new.status)
       is distinct from (old.role, old.comp_level, old.upline_id, old.status)
     and not public.is_founder()
     and current_user not in ('postgres', 'supabase_admin', 'service_role') then
    raise exception 'role, comp_level, upline_id and status can only be changed by a founder'
      using errcode = 'insufficient_privilege';
  end if;
  return new;
end $$;

create trigger agents_guard_privileged_columns
  before update on public.agents
  for each row execute function public.agents_guard_privileged_columns();

-- Nobody but signed-in users may call helpers or guard functions.
revoke all on function public.current_agent_id(), public.is_founder(), public.is_agent(),
  public.can_see_agent(uuid), public.agents_guard_privileged_columns()
  from public, anon, authenticated;
grant execute on function public.current_agent_id(), public.is_founder(), public.is_agent(),
  public.can_see_agent(uuid) to authenticated;

-- ---------------------------------------------------------------- grants
-- Default Supabase privileges hand ALL on new tables to anon/authenticated.
-- Strip that and grant only what the policies below can actually use.
revoke all on table public.agents, public.agent_closure, public.lead_vendors,
  public.leads, public.lead_activity, public.carriers, public.products,
  public.policies, public.opt_outs from public, anon, authenticated;

grant select on public.agents, public.agent_closure to authenticated;
-- id and created_at are immutable to clients; role/comp_level/upline_id/status
-- are grantable here and gated to founders by the trigger above.
grant update (full_name, email, npn, resident_state, comp_level, role, status,
              upline_id, updated_at) on public.agents to authenticated;

grant select, insert, update on public.leads    to authenticated;
grant select, insert         on public.lead_activity to authenticated;
grant select, insert, update on public.policies to authenticated;
grant select, insert, update, delete on public.carriers, public.products,
  public.lead_vendors to authenticated;
grant select, insert         on public.opt_outs to authenticated;

-- ---------------------------------------------------------------- policies
-- agents
create policy agents_select on public.agents for select to authenticated
  using (public.can_see_agent(id));
create policy agents_update on public.agents for update to authenticated
  using      (id = public.current_agent_id() or public.is_founder())
  with check (id = public.current_agent_id() or public.is_founder());

-- agent_closure: read-only for clients
create policy agent_closure_select on public.agent_closure for select to authenticated
  using (public.can_see_agent(descendant_id));

-- leads
create policy leads_select on public.leads for select to authenticated
  using (public.can_see_agent(owner_agent_id));
create policy leads_insert on public.leads for insert to authenticated
  with check (public.can_see_agent(owner_agent_id));
create policy leads_update on public.leads for update to authenticated
  using      (public.can_see_agent(owner_agent_id))
  with check (public.can_see_agent(owner_agent_id));

-- lead_activity. Inserts must also target a lead the caller can see: FK checks
-- bypass RLS, so without this an agent could attach rows to (and probe the
-- existence of) another branch's leads.
create policy lead_activity_select on public.lead_activity for select to authenticated
  using (public.can_see_agent(agent_id));
create policy lead_activity_insert on public.lead_activity for insert to authenticated
  with check (public.can_see_agent(agent_id)
              and exists (select 1 from public.leads l where l.id = lead_id));

-- policies (same reasoning for client_id; the leads subquery runs under the caller's RLS)
create policy policies_select on public.policies for select to authenticated
  using (public.can_see_agent(writing_agent_id));
create policy policies_insert on public.policies for insert to authenticated
  with check (public.can_see_agent(writing_agent_id)
              and exists (select 1 from public.leads l where l.id = client_id));
create policy policies_update on public.policies for update to authenticated
  using      (public.can_see_agent(writing_agent_id))
  with check (public.can_see_agent(writing_agent_id)
              and exists (select 1 from public.leads l where l.id = client_id));

-- carriers / products / lead_vendors: agents read, founders write
create policy carriers_select on public.carriers for select to authenticated
  using (public.is_agent());
create policy carriers_insert on public.carriers for insert to authenticated
  with check (public.is_founder());
create policy carriers_update on public.carriers for update to authenticated
  using (public.is_founder()) with check (public.is_founder());
create policy carriers_delete on public.carriers for delete to authenticated
  using (public.is_founder());

create policy products_select on public.products for select to authenticated
  using (public.is_agent());
create policy products_insert on public.products for insert to authenticated
  with check (public.is_founder());
create policy products_update on public.products for update to authenticated
  using (public.is_founder()) with check (public.is_founder());
create policy products_delete on public.products for delete to authenticated
  using (public.is_founder());

create policy lead_vendors_select on public.lead_vendors for select to authenticated
  using (public.is_agent());
create policy lead_vendors_insert on public.lead_vendors for insert to authenticated
  with check (public.is_founder());
create policy lead_vendors_update on public.lead_vendors for update to authenticated
  using (public.is_founder()) with check (public.is_founder());
create policy lead_vendors_delete on public.lead_vendors for delete to authenticated
  using (public.is_founder());

-- opt_outs: append-only for agents
create policy opt_outs_select on public.opt_outs for select to authenticated
  using (public.is_agent());
create policy opt_outs_insert on public.opt_outs for insert to authenticated
  with check (public.is_agent());
