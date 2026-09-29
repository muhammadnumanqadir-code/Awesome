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
