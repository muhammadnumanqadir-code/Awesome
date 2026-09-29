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
