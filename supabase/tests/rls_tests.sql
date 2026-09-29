-- RLS / hierarchy test suite. Runs inside one transaction that is rolled back,
-- so it leaves the seeded database untouched. Requires migrations + seed.
--   psql -v ON_ERROR_STOP=1 -f tests/rls_tests.sql
-- Clients are impersonated exactly as PostgREST does it: set the JWT claims
-- GUC, then SET LOCAL ROLE authenticated / anon.
\set QUIET on
\pset tuples_only on
\pset format unaligned
begin;

create schema tests;
grant usage on schema tests to anon, authenticated;

-- ------------------------------------------------------------ harness
create function tests.log(line text) returns void language plpgsql as $$
begin
  perform set_config('tests.log', coalesce(current_setting('tests.log', true), '') || line || E'\n', false);
end $$;

create function tests.ok(name text, cond boolean, detail text default null) returns void
language plpgsql as $$
declare k text := case when coalesce(cond, false) then 'pass' else 'fail' end;
begin
  perform set_config('tests.' || k,
    (coalesce(nullif(current_setting('tests.' || k, true), ''), '0')::int + 1)::text, false);
  perform tests.log(case when k = 'pass' then '  PASS  ' else '  FAIL  ' end || name
                    || coalesce('   -- ' || detail, ''));
end $$;

create function tests.section(title text) returns void language sql as $$
  select tests.log(E'\n' || title)
$$;

create function tests.eq(name text, actual bigint, expected bigint) returns void language sql as $$
  select tests.ok(name || ' (' || actual || ')', actual = expected, 'expected ' || expected || ', got ' || actual)
$$;

create function tests.n(q text) returns bigint language plpgsql as $$
declare c bigint;
begin
  execute 'select count(*) from (' || q || ') q' into c;
  return c;
end $$;

-- statement must fail with the given SQLSTATE
create function tests.raises(name text, stmt text, expected_state text) returns void
language plpgsql as $$
begin
  execute stmt;
  perform tests.ok(name, false, 'no error raised');
exception when others then
  perform tests.ok(name || ' [' || sqlstate || ']', sqlstate = expected_state,
                   'expected ' || expected_state || ', got ' || sqlstate || ': ' || sqlerrm);
end $$;

-- statement must succeed and touch exactly n rows
create function tests.affects(name text, stmt text, expected bigint) returns void
language plpgsql as $$
declare c bigint;
begin
  execute stmt;
  get diagnostics c = row_count;
  perform tests.ok(name || ' (' || c || ' row' || case when c = 1 then '' else 's' end || ')',
                   c = expected, 'expected ' || expected || ' rows, got ' || c);
exception when others then
  perform tests.ok(name, false, 'unexpected error ' || sqlstate || ': ' || sqlerrm);
end $$;

create function tests.who(nm text) returns uuid language sql immutable as $$
  select case nm
    when 'founder' then 'f0000000-0000-0000-0000-000000000001'
    when 'mgrA' then 'a0000000-0000-0000-0000-000000000001'
    when 'mgrB' then 'b0000000-0000-0000-0000-000000000001'
    when 'a1' then 'a1000000-0000-0000-0000-000000000001'
    when 'a2' then 'a1000000-0000-0000-0000-000000000002'
    when 'a3' then 'a1000000-0000-0000-0000-000000000003'
    when 'b1' then 'b1000000-0000-0000-0000-000000000001'
    when 'b2' then 'b1000000-0000-0000-0000-000000000002'
    when 'b3' then 'b1000000-0000-0000-0000-000000000003'
  end::uuid
$$;
create function tests.branch(mgr text) returns uuid[] language sql immutable as $$
  select case mgr
    when 'A' then array[tests.who('mgrA'), tests.who('a1'), tests.who('a2'), tests.who('a3')]
    when 'B' then array[tests.who('mgrB'), tests.who('b1'), tests.who('b2'), tests.who('b3')]
  end
$$;

create function tests.logout() returns void language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', '', true);
end $$;
create function tests.login(agent uuid) returns void language plpgsql as $$
begin
  perform tests.logout();
  perform set_config('request.jwt.claims',
    json_build_object('sub', agent, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
end $$;
create function tests.login_anon() returns void language plpgsql as $$
begin
  perform tests.logout();
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  execute 'set local role anon';
end $$;

-- Ground truth for the closure table: an independent recursive CTE over agents.
-- (Only the tests use a recursive CTE; the schema never does at query time.)
create function tests.closure_diff() returns bigint language sql as $$
  with recursive t(a, d, depth) as (
    select id, id, 0 from public.agents
    union all
    select t.a, ag.id, t.depth + 1 from t join public.agents ag on ag.upline_id = t.d
  ),
  diff as (
    (select a, d, depth from t except select ancestor_id, descendant_id, depth from public.agent_closure)
    union all
    (select ancestor_id, descendant_id, depth from public.agent_closure except select a, d, depth from t)
  )
  select count(*) from diff
$$;

create function tests.add_agent(id uuid, nm text, upline uuid) returns void language plpgsql as $$
begin
  insert into auth.users (id, aud, role, email) values (id, 'authenticated', 'authenticated', nm || '@agency.test');
  insert into public.agents (id, full_name, email, upline_id) values (id, nm, nm || '@agency.test', upline);
end $$;

-- ------------------------------------------------------------ 1. structure
select tests.section('1. Structural guarantees');
do $$
declare t record; p text; c bigint;
begin
  perform tests.eq('9 public tables exist',
    tests.n($q$select 1 from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r'$q$), 9);
  perform tests.eq('every public table has RLS enabled',
    tests.n($q$select 1 from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r'
                 and not relrowsecurity$q$), 0);
  perform tests.eq('no policy uses USING (true) / WITH CHECK (true)',
    tests.n($q$select 1 from pg_policies where schemaname = 'public'
                 and (lower(trim(both '() ' from coalesce(qual, ''))) = 'true'
                   or lower(trim(both '() ' from coalesce(with_check, ''))) = 'true')$q$), 0);
  perform tests.eq('every policy has an expression',
    tests.n($q$select 1 from pg_policies where schemaname = 'public'
                 and qual is null and with_check is null$q$), 0);
  perform tests.eq('every policy targets authenticated only',
    tests.n($q$select 1 from pg_policies where schemaname = 'public' and roles <> '{authenticated}'$q$), 0);
  perform tests.eq('every policy scopes through a hierarchy helper',
    tests.n($q$select 1 from pg_policies where schemaname = 'public'
                 and coalesce(qual, '') || coalesce(with_check, '') !~
                     '(can_see_agent|is_founder|is_agent|current_agent_id)'$q$), 0);

  perform tests.eq('helpers are SECURITY DEFINER + STABLE + search_path=""',
    tests.n($q$select 1 from pg_proc where pronamespace = 'public'::regnamespace
                 and proname in ('current_agent_id','is_founder','is_agent','can_see_agent')
                 and prosecdef and provolatile = 's' and proconfig @> array['search_path=""']$q$), 4);
  perform tests.eq('anon has EXECUTE on no function in public',
    tests.n($q$select 1 from pg_proc where pronamespace = 'public'::regnamespace
                 and has_function_privilege('anon', oid, 'execute')$q$), 0);
  perform tests.eq('trigger/definer functions are not callable by authenticated',
    tests.n($q$select 1 from pg_proc where pronamespace = 'public'::regnamespace
                 and proname in ('set_updated_at','agents_reject_cycle','agents_closure_maintain',
                                 'agents_guard_privileged_columns')
                 and has_function_privilege('authenticated', oid, 'execute')$q$), 0);

  for t in select relname from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r' loop
    foreach p in array array['select','insert','update','delete','truncate','references','trigger'] loop
      if has_table_privilege('anon', 'public.' || t.relname, p) then
        perform tests.ok('anon has no ' || p || ' on ' || t.relname, false);
      end if;
    end loop;
  end loop;
  perform tests.ok('anon holds no privilege on any table', true);
  perform tests.eq('service_role is not referenced by any policy',
    tests.n($q$select 1 from pg_policies where schemaname = 'public' and roles::text like '%service_role%'$q$), 0);

  perform tests.eq('every foreign key has a supporting index',
    tests.n($q$select 1 from pg_constraint c
               where c.contype = 'f' and c.connamespace = 'public'::regnamespace
                 and not exists (
                   select 1 from pg_index i
                   where i.indrelid = c.conrelid
                     and (string_to_array(i.indkey::text, ' ')::int2[])[1:cardinality(c.conkey)] = c.conkey)$q$), 0);
  perform tests.eq('leads(owner_agent_id, disposition) index exists',
    tests.n($q$select 1 from pg_indexes where indexname = 'leads_owner_disposition_idx'$q$), 1);
  perform tests.eq('policies(writing_agent_id, status) index exists',
    tests.n($q$select 1 from pg_indexes where indexname = 'policies_writing_agent_status_idx'$q$), 1);
  perform tests.eq('every table with updated_at has an updated_at trigger',
    tests.n($q$select 1 from information_schema.columns col
               where col.table_schema = 'public' and col.column_name = 'updated_at'
                 and not exists (select 1 from pg_trigger g
                                  where g.tgrelid = ('public.' || col.table_name)::regclass
                                    and g.tgname like '%set_updated_at' and not g.tgisinternal)$q$), 0);
end $$;

-- ------------------------------------------------------------ 2. seed sanity
select tests.section('2. Seed data and closure integrity');
do $$
begin
  perform tests.eq('9 agents',            tests.n('select 1 from public.agents'), 9);
  perform tests.eq('46 leads',            tests.n('select 1 from public.leads'), 46);
  perform tests.eq('9 policies',          tests.n('select 1 from public.policies'), 9);
  perform tests.eq('4 carriers',          tests.n('select 1 from public.carriers'), 4);
  perform tests.eq('8 products',          tests.n('select 1 from public.products'), 8);
  perform tests.eq('2 lead vendors',      tests.n('select 1 from public.lead_vendors'), 2);
  perform tests.eq('every agent has a depth-0 self row',
    tests.n('select 1 from public.agent_closure where ancestor_id = descendant_id and depth = 0'), 9);
  perform tests.eq('closure has 9 self + 8 depth-1 + 6 depth-2 rows',
    tests.n('select 1 from public.agent_closure'), 23);
  perform tests.eq('closure matches recursive-CTE ground truth', tests.closure_diff(), 0);
  perform tests.eq('all six agents hold leads across varied dispositions',
    tests.n('select distinct owner_agent_id from public.leads where owner_agent_id not in (select id from public.agents where role <> ''agent'')'), 6);
  perform tests.ok('seed has every lead disposition',
    (select count(distinct disposition) from public.leads) = 8);
  perform tests.ok('seed has several policy statuses',
    (select count(distinct status) from public.policies) = 5);
end $$;

-- ------------------------------------------------------------ 3. founder
select tests.section('3. Founder sees everything');
do $$
declare a bigint; l bigint; p bigint; act bigint; cl bigint;
begin
  a := tests.n('select 1 from public.agents'); l := tests.n('select 1 from public.leads');
  p := tests.n('select 1 from public.policies'); act := tests.n('select 1 from public.lead_activity');
  cl := tests.n('select 1 from public.agent_closure');
  perform tests.login(tests.who('founder'));
  perform tests.eq('founder sees all agents',        tests.n('select 1 from public.agents'), a);
  perform tests.eq('founder sees all leads',         tests.n('select 1 from public.leads'), l);
  perform tests.eq('founder sees all lead_activity', tests.n('select 1 from public.lead_activity'), act);
  perform tests.eq('founder sees all policies',      tests.n('select 1 from public.policies'), p);
  perform tests.eq('founder sees all closure rows',  tests.n('select 1 from public.agent_closure'), cl);
  perform tests.ok('is_founder() true for founder', public.is_founder());
  perform tests.logout();
end $$;

-- ------------------------------------------------------------ 4. manager A
select tests.section('4. Manager A: own branch only');
do $$
declare
  A uuid[] := tests.branch('A'); B uuid[] := tests.branch('B');
  ea bigint; el bigint; eact bigint; ep bigint;
begin
  ea   := tests.n(format('select 1 from public.agents where id = any(%L)', A));
  el   := tests.n(format('select 1 from public.leads where owner_agent_id = any(%L)', A));
  eact := tests.n(format('select 1 from public.lead_activity where agent_id = any(%L)', A));
  ep   := tests.n(format('select 1 from public.policies where writing_agent_id = any(%L)', A));
  perform tests.login(tests.who('mgrA'));

  perform tests.eq('agents: manager A sees exactly self + 3 agents', tests.n('select 1 from public.agents'), 4);
  perform tests.eq('agents: ... which are the branch-A ids',
    tests.n(format('select 1 from public.agents where id = any(%L)', A)), 4);
  perform tests.eq('agents: no manager-B branch rows',
    tests.n(format('select 1 from public.agents where id = any(%L)', B)), 0);
  perform tests.eq('agents: founder row not visible',
    tests.n(format('select 1 from public.agents where id = %L', tests.who('founder'))), 0);

  perform tests.eq('leads: manager A sees the whole branch-A book',
    tests.n('select 1 from public.leads'), el);
  perform tests.ok('leads: branch-A book is non-trivial', el > 20);
  perform tests.eq('leads: none owned outside branch A',
    tests.n(format('select 1 from public.leads where not owner_agent_id = any(%L)', A)), 0);
  perform tests.eq('leads: none owned by branch B',
    tests.n(format('select 1 from public.leads where owner_agent_id = any(%L)', B)), 0);

  perform tests.eq('lead_activity: manager A sees the whole branch-A activity',
    tests.n('select 1 from public.lead_activity'), eact);
  perform tests.eq('lead_activity: none by anyone outside branch A',
    tests.n(format('select 1 from public.lead_activity where not agent_id = any(%L)', A)), 0);
  perform tests.eq('lead_activity: none on branch-B leads',
    tests.n(format('select 1 from public.lead_activity where lead_id in (select id from public.leads where owner_agent_id = any(%L))', B)), 0);

  perform tests.eq('policies: manager A sees the whole branch-A policies',
    tests.n('select 1 from public.policies'), ep);
  perform tests.ok('policies: branch-A policies non-empty', ep > 0);
  perform tests.eq('policies: none written outside branch A',
    tests.n(format('select 1 from public.policies where not writing_agent_id = any(%L)', A)), 0);
  perform tests.eq('policies: none written by branch B',
    tests.n(format('select 1 from public.policies where writing_agent_id = any(%L)', B)), 0);

  perform tests.eq('agent_closure: no rows for branch-B descendants',
    tests.n(format('select 1 from public.agent_closure where descendant_id = any(%L)', B)), 0);
  perform tests.eq('can_see_agent(B1) is false',  case when public.can_see_agent(tests.who('b1')) then 1 else 0 end, 0);
  perform tests.eq('can_see_agent(A3) is true',   case when public.can_see_agent(tests.who('a3')) then 1 else 0 end, 1);
  perform tests.logout();
end $$;

-- ------------------------------------------------------------ 5. leaf agent
select tests.section('5. Leaf agent A1: own rows only');
do $$
declare A uuid[] := tests.branch('A'); a1 uuid := tests.who('a1');
  el bigint; eact bigint; ep bigint;
begin
  el   := tests.n(format('select 1 from public.leads where owner_agent_id = %L', a1));
  eact := tests.n(format('select 1 from public.lead_activity where agent_id = %L', a1));
  ep   := tests.n(format('select 1 from public.policies where writing_agent_id = %L', a1));
  perform tests.login(a1);
  perform tests.eq('agents: sees only self', tests.n('select 1 from public.agents'), 1);
  perform tests.eq('agents: and it is A1', tests.n(format('select 1 from public.agents where id = %L', a1)), 1);
  perform tests.eq('leads: sees only own leads', tests.n('select 1 from public.leads'), el);
  perform tests.ok('leads: own book non-empty', el = 7);
  perform tests.eq('leads: none owned by siblings/manager',
    tests.n(format('select 1 from public.leads where owner_agent_id <> %L', a1)), 0);
  perform tests.eq('lead_activity: sees only own activity', tests.n('select 1 from public.lead_activity'), eact);
  perform tests.eq('lead_activity: none by others',
    tests.n(format('select 1 from public.lead_activity where agent_id <> %L', a1)), 0);
  perform tests.eq('policies: sees only own policies', tests.n('select 1 from public.policies'), ep);
  perform tests.ok('policies: own policies non-empty', ep > 0);
  perform tests.eq('policies: none written by others',
    tests.n(format('select 1 from public.policies where writing_agent_id <> %L', a1)), 0);
  perform tests.eq('agent_closure: only rows that end at A1',
    tests.n(format('select 1 from public.agent_closure where descendant_id <> %L', a1)), 0);
  perform tests.eq('can_see_agent(sibling A2) is false', case when public.can_see_agent(tests.who('a2')) then 1 else 0 end, 0);
  perform tests.eq('can_see_agent(own manager) is false', case when public.can_see_agent(tests.who('mgrA')) then 1 else 0 end, 0);
  perform tests.logout();
  -- a leaf in the other branch, for symmetry
  perform tests.login(tests.who('b3'));
  perform tests.eq('B3 sees only self', tests.n('select 1 from public.agents'), 1);
  perform tests.eq('B3 sees nothing owned by branch A',
    tests.n(format('select 1 from public.leads where owner_agent_id = any(%L)', A)), 0);
  perform tests.logout();
end $$;

-- ------------------------------------------------------------ 6. anon
select tests.section('6. anon role has zero access');
do $$
declare t record; ok boolean; c bigint;
begin
  perform tests.login_anon();
  for t in select relname from pg_class where relnamespace = 'public'::regnamespace and relkind = 'r' order by 1 loop
    begin
      execute format('select count(*) from public.%I', t.relname) into c;
      perform tests.ok('anon reads ' || t.relname || ' -> zero rows', c = 0, 'returned ' || c || ' rows');
    exception when insufficient_privilege then
      perform tests.ok('anon reads ' || t.relname || ' -> permission denied [42501]', true);
    end;
  end loop;
  perform tests.raises('anon cannot INSERT into leads',
    $q$insert into public.leads (owner_agent_id) values ('a1000000-0000-0000-0000-000000000001')$q$, '42501');
  perform tests.raises('anon cannot INSERT into opt_outs',
    $q$insert into public.opt_outs (phone) values ('+15550000000')$q$, '42501');
  perform tests.raises('anon cannot call can_see_agent()',
    $q$select public.can_see_agent('a1000000-0000-0000-0000-000000000001')$q$, '42501');
  perform tests.raises('anon cannot call is_founder()', $q$select public.is_founder()$q$, '42501');
  perform tests.logout();
end $$;

-- ------------------------------------------------------------ 7. column protection
select tests.section('7. Agents cannot escalate their own privileges');
do $$
declare a1 uuid := tests.who('a1'); a2 uuid := tests.who('a2');
begin
  perform tests.login(a1);
  perform tests.affects('agent can update own full_name',
    format('update public.agents set full_name = ''Alice Renamed'' where id = %L', a1), 1);
  perform tests.ok('updated_at trigger advanced updated_at',
    (select updated_at > created_at from public.agents where id = a1));
  perform tests.raises('agent cannot UPDATE own comp_level',
    format('update public.agents set comp_level = 130 where id = %L', a1), '42501');
  perform tests.raises('agent cannot UPDATE own role',
    format('update public.agents set role = ''founder'' where id = %L', a1), '42501');
  perform tests.raises('agent cannot UPDATE own upline_id',
    format('update public.agents set upline_id = %L where id = %L', tests.who('founder'), a1), '42501');
  perform tests.raises('agent cannot UPDATE own status',
    format('update public.agents set status = ''terminated'' where id = %L', a1), '42501');
  perform tests.raises('agent cannot smuggle a forbidden column into an otherwise legal UPDATE',
    format('update public.agents set full_name = ''X'', comp_level = 999 where id = %L', a1), '42501');
  perform tests.raises('agent cannot change agents.id (no column grant)',
    format('update public.agents set id = %L where id = %L', gen_random_uuid(), a1), '42501');
  perform tests.affects('agent cannot UPDATE a sibling (RLS filters the row)',
    format('update public.agents set full_name = ''pwned'' where id = %L', a2), 0);
  perform tests.raises('agent cannot INSERT agents', format(
    'insert into public.agents (id, full_name, email) values (%L, ''x'', ''x@x'')', gen_random_uuid()), '42501');
  perform tests.raises('agent cannot DELETE agents', format('delete from public.agents where id = %L', a1), '42501');
  perform tests.logout();

  perform tests.login(tests.who('mgrA'));
  perform tests.affects('manager cannot change a downline agent (RLS filters the row)',
    format('update public.agents set comp_level = 120 where id = %L', a1), 0);
  perform tests.raises('manager cannot UPDATE own comp_level',
    format('update public.agents set comp_level = 999 where id = %L', tests.who('mgrA')), '42501');
  perform tests.raises('manager cannot UPDATE own role to founder',
    format('update public.agents set role = ''founder'' where id = %L', tests.who('mgrA')), '42501');
  perform tests.logout();

  perform tests.eq('A1 comp_level, role, upline_id, status unchanged after all attempts',
    tests.n(format($q$select 1 from public.agents where id = %L and comp_level = 100.00
      and role = 'agent' and status = 'active' and upline_id = %L$q$, a1, tests.who('mgrA'))), 1);
  perform tests.eq('A2 untouched by A1 and manager attempts',
    tests.n(format($q$select 1 from public.agents where id = %L and full_name = 'Aaron Agent-A2' and comp_level = 90.00$q$, a2)), 1);

  perform tests.login(tests.who('founder'));
  perform tests.affects('founder CAN update comp_level',
    format('update public.agents set comp_level = 95.50 where id = %L', a1), 1);
  perform tests.affects('founder CAN update role',
    format('update public.agents set role = ''manager'' where id = %L', a1), 1);
  perform tests.affects('founder CAN update upline_id',
    format('update public.agents set upline_id = %L where id = %L', tests.who('mgrB'), a1), 1);
  perform tests.affects('founder CAN update status',
    format('update public.agents set status = ''inactive'' where id = %L', a1), 1);
  perform tests.logout();
  perform tests.eq('founder changes persisted',
    tests.n(format($q$select 1 from public.agents where id = %L and comp_level = 95.50
      and role = 'manager' and status = 'inactive' and upline_id = %L$q$, a1, tests.who('mgrB'))), 1);
  perform tests.eq('closure still matches ground truth after founder edits', tests.closure_diff(), 0);
  -- restore for later sections
  update public.agents set upline_id = tests.who('mgrA'), role = 'agent', status = 'active', comp_level = 100
   where id = a1;
end $$;

-- ------------------------------------------------------------ 8. hierarchy maintenance
select tests.section('8. Closure maintenance: moves rebuild the whole subtree');
do $$
declare
  f uuid := tests.who('founder'); mA uuid := tests.who('mgrA'); mB uuid := tests.who('mgrB');
  a1 uuid := tests.who('a1'); a2 uuid := tests.who('a2');
  x uuid := '99000000-0000-0000-0000-000000000001'; y uuid := '99000000-0000-0000-0000-000000000002';
  function_depth bigint;
begin
  -- deepen the tree: founder > mgrA > A1 > X > Y
  perform tests.add_agent(x, 'agent.x', a1);
  perform tests.add_agent(y, 'agent.y', x);
  perform tests.eq('new agent X: 4 closure rows (self, A1, mgrA, founder)',
    tests.n(format('select 1 from public.agent_closure where descendant_id = %L', x)), 4);
  perform tests.eq('depth founder->Y is 4',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = %L and depth = 4', f, y)), 1);
  perform tests.eq('closure matches ground truth after inserts', tests.closure_diff(), 0);

  -- move mgrA (with A1..A3, X, Y beneath) under mgrB, as the founder would from the UI
  perform tests.login(f);
  perform tests.affects('founder moves manager A under manager B',
    format('update public.agents set upline_id = %L where id = %L', mB, mA), 1);
  perform tests.logout();
  perform tests.eq('closure matches ground truth after move', tests.closure_diff(), 0);
  perform tests.eq('mgrA now at depth 1 under mgrB',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = %L and depth = 1', mB, mA)), 1);
  perform tests.eq('founder->mgrA re-parented to depth 2',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = %L and depth = 2', f, mA)), 1);
  perform tests.eq('mgrB->Y depth 4 (deep descendant followed the move)',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = %L and depth = 4', mB, y)), 1);
  perform tests.eq('founder->Y depth 5',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = %L and depth = 5', f, y)), 1);
  perform tests.eq('subtree-internal rows untouched: mgrA->Y depth 3',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = %L and depth = 3', mA, y)), 1);
  perform tests.eq('Y has exactly 6 ancestors incl. self (Y,X,A1,mgrA,mgrB,founder)',
    tests.n(format('select 1 from public.agent_closure where descendant_id = %L', y)), 6);
  perform tests.eq('no stale founder->mgrA depth-1 link',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = any(%L) and depth = 1',
      f, array[mA, a1, x, y])), 0);
  perform tests.eq('mgrB does not gain unrelated rows: B branch has no rows for A2 at depth 1',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = %L and depth = 1', mB, a2)), 0);

  -- visibility follows the move
  perform tests.login(mB);
  perform tests.eq('mgrB now sees B branch + A branch + X + Y = 10 agents', tests.n('select 1 from public.agents'), 10);
  perform tests.logout();
  perform tests.login(mA);
  perform tests.eq('mgrA now sees itself, A1..A3, X, Y = 6 agents', tests.n('select 1 from public.agents'), 6);
  perform tests.eq('mgrA still sees nothing of B1..B3',
    tests.n(format('select 1 from public.agents where id = any(%L)', array[tests.who('b1'), tests.who('b2'), tests.who('b3'), mB])), 0);
  perform tests.logout();

  -- move a mid-level agent (A1 with X, Y) to be a root, then back
  perform tests.login(f);
  perform tests.affects('founder detaches A1 (upline_id = NULL)',
    format('update public.agents set upline_id = null where id = %L', a1), 1);
  perform tests.logout();
  perform tests.eq('closure matches ground truth after detach', tests.closure_diff(), 0);
  perform tests.eq('detached subtree has no rows from old ancestors',
    tests.n(format('select 1 from public.agent_closure where descendant_id = any(%L) and ancestor_id = any(%L)',
      array[a1, x, y], array[mA, mB, f])), 0);
  perform tests.eq('A1 subtree keeps internal rows (A1->Y depth 2)',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = %L and depth = 2', a1, y)), 1);
  perform tests.login(f);
  perform tests.affects('founder re-attaches A1 under A2',
    format('update public.agents set upline_id = %L where id = %L', a2, a1), 1);
  perform tests.logout();
  perform tests.eq('closure matches ground truth after re-attach', tests.closure_diff(), 0);
  perform tests.eq('founder->Y depth 7 (founder>mgrB>mgrA>A2>A1>X>Y)',
    tests.n(format('select 1 from public.agent_closure where ancestor_id = %L and descendant_id = %L and depth = 6', f, y)), 1);

  -- no-op update of upline_id does not disturb anything
  update public.agents set upline_id = a2 where id = a1;
  perform tests.eq('closure matches ground truth after no-op update', tests.closure_diff(), 0);
end $$;

-- ------------------------------------------------------------ 9. cycle rejection
select tests.section('9. Cycles are rejected');
do $$
declare
  f uuid := tests.who('founder'); mA uuid := tests.who('mgrA'); mB uuid := tests.who('mgrB');
  a1 uuid := tests.who('a1'); a2 uuid := tests.who('a2');
  x uuid := '99000000-0000-0000-0000-000000000001'; y uuid := '99000000-0000-0000-0000-000000000002';
  before_rows bigint;
begin
  before_rows := tests.n('select 1 from public.agent_closure');
  perform tests.login(f);
  perform tests.raises('upline = own direct child rejected',
    format('update public.agents set upline_id = %L where id = %L', a1, a2), '23514');
  perform tests.raises('upline = own deep descendant rejected (mgrA under Y)',
    format('update public.agents set upline_id = %L where id = %L', y, mA), '23514');
  perform tests.raises('founder cannot be placed under own descendant',
    format('update public.agents set upline_id = %L where id = %L', mB, f), '23514');
  perform tests.raises('upline = self rejected',
    format('update public.agents set upline_id = %L where id = %L', x, x), '23514');
  perform tests.logout();
  perform tests.raises('cycle rejected even for a trusted (non-RLS) role',
    format('update public.agents set upline_id = %L where id = %L', y, mB), '23514');
  perform tests.eq('agent_closure row count unchanged by rejected moves',
    tests.n('select 1 from public.agent_closure'), before_rows);
  perform tests.eq('closure matches ground truth after rejected moves', tests.closure_diff(), 0);
  perform tests.eq('rejected moves left upline_id unchanged',
    tests.n(format($q$select 1 from public.agents where (id = %L and upline_id = %L) or (id = %L and upline_id = %L)
      or (id = %L and upline_id is null)$q$, a2, mA, mA, mB, f)), 3);
end $$;

-- ------------------------------------------------------------ 10. writes
select tests.section('10. Write policies');
do $$
declare
  a1 uuid := tests.who('a1'); a2 uuid := tests.who('a2'); b1 uuid := tests.who('b1');
  mA uuid := tests.who('mgrA'); mB uuid := tests.who('mgrB');
  a1_lead uuid; a2_lead uuid; a1_client uuid; a2_client uuid; a2_policy uuid; a1_policy uuid;
begin
  -- NB: section 8 moved mgrA under mgrB and A1 under A2; put A1 back so this section tests the seed shape
  update public.agents set upline_id = mA where id = a1;
  update public.agents set upline_id = tests.who('founder') where id = mB;  -- unchanged, keeps founder root
  select id into a1_lead   from public.leads where owner_agent_id = a1 and stage = 'lead' limit 1;
  select id into a2_lead   from public.leads where owner_agent_id = a2 and stage = 'lead' limit 1;
  select id into a1_client from public.leads where owner_agent_id = a1 and stage = 'client' limit 1;
  select id into a2_client from public.leads where owner_agent_id = a2 and stage = 'client' limit 1;
  select id into a2_policy from public.policies where writing_agent_id = a2 limit 1;
  select id into a1_policy from public.policies where writing_agent_id = a1 limit 1;
  -- restore the original shape: mgrA under founder
  update public.agents set upline_id = tests.who('founder') where id = mA;

  -- leads
  perform tests.login(a1);
  perform tests.affects('A1 inserts a lead for self',
    format('insert into public.leads (owner_agent_id, first_name) values (%L, ''New'')', a1), 1);
  perform tests.raises('A1 cannot insert a lead owned by sibling A2',
    format('insert into public.leads (owner_agent_id, first_name) values (%L, ''X'')', a2), '42501');
  perform tests.affects('A1 updates own lead disposition',
    format('update public.leads set disposition = ''follow_up'' where id = %L', a1_lead), 1);
  perform tests.affects('A1 cannot update sibling lead (row invisible)',
    format('update public.leads set disposition = ''sold'' where id = %L', a2_lead), 0);
  perform tests.raises('A1 cannot hand own lead to sibling A2',
    format('update public.leads set owner_agent_id = %L where id = %L', a2, a1_lead), '42501');
  perform tests.raises('A1 cannot DELETE leads (no grant)', format('delete from public.leads where id = %L', a1_lead), '42501');
  perform tests.logout();

  perform tests.login(mA);
  perform tests.affects('manager A inserts a lead for downline agent A3',
    format('insert into public.leads (owner_agent_id, first_name) values (%L, ''ForA3'')', tests.who('a3')), 1);
  perform tests.raises('manager A cannot insert a lead for branch-B agent',
    format('insert into public.leads (owner_agent_id, first_name) values (%L, ''X'')', b1), '42501');
  perform tests.affects('manager A updates a downline lead',
    format('update public.leads set disposition = ''must_call'' where id = %L', a1_lead), 1);
  perform tests.raises('manager A cannot move a downline lead into branch B',
    format('update public.leads set owner_agent_id = %L where id = %L', b1, a1_lead), '42501');
  perform tests.logout();

  -- lead_activity
  perform tests.login(a1);
  perform tests.affects('A1 logs activity on own lead',
    format('insert into public.lead_activity (lead_id, agent_id, type, body) values (%L, %L, ''note'', ''hi'')', a1_lead, a1), 1);
  perform tests.raises('A1 cannot log activity on sibling lead',
    format('insert into public.lead_activity (lead_id, agent_id, type) values (%L, %L, ''note'')', a2_lead, a1), '42501');
  perform tests.raises('A1 cannot forge activity as sibling A2',
    format('insert into public.lead_activity (lead_id, agent_id, type) values (%L, %L, ''note'')', a1_lead, a2), '42501');
  perform tests.raises('activity is not updatable',
    format('update public.lead_activity set body = ''x'' where agent_id = %L', a1), '42501');
  perform tests.logout();
  perform tests.login(mA);
  perform tests.affects('manager A logs activity as downline A1 on A1 lead',
    format('insert into public.lead_activity (lead_id, agent_id, type) values (%L, %L, ''note'')', a1_lead, a1), 1);
  perform tests.logout();

  -- policies
  perform tests.login(a1);
  perform tests.affects('A1 writes a policy for own client',
    format($q$insert into public.policies (client_id, writing_agent_id, carrier_id, product_id, annual_premium)
      values (%L, %L, 'c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000011', 1000)$q$, a1_client, a1), 1);
  perform tests.raises('A1 cannot write a policy for sibling client',
    format($q$insert into public.policies (client_id, writing_agent_id, carrier_id, product_id)
      values (%L, %L, 'c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000011')$q$, a2_client, a1), '42501');
  perform tests.raises('A1 cannot write a policy as sibling A2',
    format($q$insert into public.policies (client_id, writing_agent_id, carrier_id, product_id)
      values (%L, %L, 'c0000000-0000-0000-0000-000000000001', 'd0000000-0000-0000-0000-000000000011')$q$, a1_client, a2), '42501');
  perform tests.raises('policy product must belong to policy carrier',
    format($q$insert into public.policies (client_id, writing_agent_id, carrier_id, product_id)
      values (%L, %L, 'c0000000-0000-0000-0000-000000000002', 'd0000000-0000-0000-0000-000000000011')$q$, a1_client, a1), '23503');
  perform tests.affects('A1 updates own policy status',
    format('update public.policies set status = ''active'' where id = %L', a1_policy), 1);
  perform tests.affects('A1 cannot update sibling policy (row invisible)',
    format('update public.policies set status = ''cancelled'' where id = %L', a2_policy), 0);
  perform tests.raises('A1 cannot re-point own policy at a sibling client',
    format('update public.policies set client_id = %L where id = %L', a2_client, a1_policy), '42501');
  perform tests.raises('A1 cannot DELETE policies', format('delete from public.policies where id = %L', a1_policy), '42501');
  perform tests.logout();

  -- reference data
  perform tests.login(a1);
  perform tests.eq('agent reads all carriers', tests.n('select 1 from public.carriers'), 4);
  perform tests.eq('agent reads all products', tests.n('select 1 from public.products'), 8);
  perform tests.eq('agent reads all lead_vendors', tests.n('select 1 from public.lead_vendors'), 2);
  perform tests.raises('agent cannot insert carrier', $q$insert into public.carriers (name) values ('Evil Life')$q$, '42501');
  perform tests.raises('agent cannot insert product',
    $q$insert into public.products (carrier_id, name, type) values ('c0000000-0000-0000-0000-000000000001', 'x', 'fex')$q$, '42501');
  perform tests.raises('agent cannot insert lead vendor', $q$insert into public.lead_vendors (name) values ('x')$q$, '42501');
  perform tests.affects('agent cannot update carriers (rows filtered)', $q$update public.carriers set name = 'pwned'$q$, 0);
  perform tests.affects('agent cannot delete products (rows filtered)', $q$delete from public.products$q$, 0);
  perform tests.affects('agent cannot update lead vendors (rows filtered)', $q$update public.lead_vendors set cost_per_lead = 0$q$, 0);
  perform tests.logout();
  perform tests.login(mA);
  perform tests.raises('manager cannot insert carrier', $q$insert into public.carriers (name) values ('x')$q$, '42501');
  perform tests.logout();
  perform tests.login(tests.who('founder'));
  perform tests.affects('founder inserts a carrier', $q$insert into public.carriers (name) values ('New Carrier')$q$, 1);
  perform tests.affects('founder updates a carrier', $q$update public.carriers set name = 'Renamed' where name = 'New Carrier'$q$, 1);
  perform tests.affects('founder inserts a product',
    $q$insert into public.products (carrier_id, name, type) select id, 'P', 'iul' from public.carriers where name = 'Renamed'$q$, 1);
  perform tests.affects('founder inserts a lead vendor', $q$insert into public.lead_vendors (name, cost_per_lead) values ('V3', 5)$q$, 1);
  perform tests.affects('founder deletes a lead vendor', $q$delete from public.lead_vendors where name = 'V3'$q$, 1);
  perform tests.logout();

  -- closure is not client-writable, even for a founder
  perform tests.login(tests.who('founder'));
  perform tests.raises('founder cannot INSERT into agent_closure',
    format('insert into public.agent_closure values (%L, %L, 1)', a1, mB), '42501');
  perform tests.raises('founder cannot UPDATE agent_closure', $q$update public.agent_closure set depth = 9$q$, '42501');
  perform tests.raises('founder cannot DELETE agent_closure', $q$delete from public.agent_closure$q$, '42501');
  perform tests.raises('founder cannot INSERT agents (auth users are provisioned server-side)',
    format('insert into public.agents (id, full_name, email) values (%L, ''x'', ''x'')', gen_random_uuid()), '42501');
  perform tests.logout();
end $$;

-- ------------------------------------------------------------ 11. opt_outs
select tests.section('11. opt_outs: global, append-only');
do $$
declare a1 uuid := tests.who('a1'); b2 uuid := tests.who('b2');
begin
  perform tests.login(a1);
  perform tests.eq('agent sees every seeded opt-out (global, not per agent)', tests.n('select 1 from public.opt_outs'), 3);
  perform tests.affects('agent records an opt-out', $q$insert into public.opt_outs (phone, source) values ('+15551112222', 'STOP reply')$q$, 1);
  perform tests.raises('same phone cannot be opted out twice (global unique)',
    $q$insert into public.opt_outs (phone) values ('+15551112222')$q$, '23505');
  perform tests.raises('agent cannot UPDATE opt_outs', $q$update public.opt_outs set source = 'x'$q$, '42501');
  perform tests.raises('agent cannot DELETE opt_outs', $q$delete from public.opt_outs$q$, '42501');
  perform tests.logout();
  perform tests.login(b2);
  perform tests.eq('another branch sees the opt-out immediately', tests.n('select 1 from public.opt_outs where phone = ''+15551112222'''), 1);
  perform tests.raises('same phone from another branch also rejected',
    $q$insert into public.opt_outs (phone) values ('+15551112222')$q$, '23505');
  perform tests.logout();
  perform tests.login(tests.who('founder'));
  perform tests.raises('even a founder cannot DELETE opt_outs', $q$delete from public.opt_outs$q$, '42501');
  perform tests.raises('even a founder cannot UPDATE opt_outs', $q$update public.opt_outs set source = 'x'$q$, '42501');
  perform tests.logout();
end $$;

-- ------------------------------------------------------------ 12. unprovisioned users
select tests.section('12. Signed-in user with no agents row');
do $$
declare ghost uuid := gen_random_uuid(); t text;
begin
  perform tests.login(ghost);
  foreach t in array array['agents','agent_closure','leads','lead_activity','policies','carriers','products','lead_vendors','opt_outs'] loop
    perform tests.eq('unprovisioned user sees 0 rows of ' || t, tests.n('select 1 from public.' || t), 0);
  end loop;
  perform tests.raises('unprovisioned user cannot record an opt-out',
    $q$insert into public.opt_outs (phone) values ('+15559998888')$q$, '42501');
  -- RLS passes (target = own uid); the FK to agents is what stops it
  perform tests.raises('unprovisioned user cannot create a lead for themselves (FK to agents)',
    format('insert into public.leads (owner_agent_id) values (%L)', ghost), '23503');
  perform tests.logout();
end $$;

-- ------------------------------------------------------------ report
select tests.section('Result');
select tests.log(format('  %s passed, %s failed',
  coalesce(nullif(current_setting('tests.pass', true), ''), '0'),
  coalesce(nullif(current_setting('tests.fail', true), ''), '0')));
select current_setting('tests.log');
do $$ begin
  if coalesce(nullif(current_setting('tests.fail', true), ''), '0')::int > 0 then
    raise exception 'RLS TESTS FAILED';
  end if;
end $$;
rollback;
