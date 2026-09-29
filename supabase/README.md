# Insurance agency CRM — database foundation

Postgres schema for Supabase. Structure and security only. Hierarchy scoping is enforced by Row Level Security; nothing depends on application code or the `service_role` key.

```
supabase/migrations/0001_schema.sql   enums, tables, indexes, triggers, RLS enabled on every table
supabase/migrations/0002_rls.sql      helper functions, grants, policies, founder-only column guard
supabase/seed.sql                     1 founder, 2 managers, 6 agents, 4 carriers, 8 products, 46 leads, 9 policies
supabase/tests/rls_tests.sql          195 assertions, runs in one rolled-back transaction
scripts/run_tests.sh                  rebuild + test (`--supabase` for `supabase start`)
```

## Helper functions
All `SECURITY DEFINER`, `STABLE`, `SET search_path = ''`; EXECUTE revoked from `anon`/PUBLIC, granted to `authenticated`.

| Function | Returns |
|---|---|
| `current_agent_id()` | `auth.uid()` |
| `is_founder()` | caller's `agents.role = 'founder'` |
| `is_agent()` | caller has an `agents` row (added: keeps self-signed-up auth users out of shared data) |
| `can_see_agent(target)` | founder, or `target` is the caller, or the caller is an ancestor of `target` in `agent_closure` |

## Tables, RLS status and policies
RLS is **enabled on all 9 tables**. `anon` holds no privilege on any table. All policies are `TO authenticated`; there is no `USING (true)`. A missing policy means deny. Operations with no grant fail with `42501` instead of silently returning 0 rows.

| Table | RLS | Policy → USING / WITH CHECK in plain English |
|---|---|---|
| `agents` | on | **SELECT**: the row's agent is the caller, in the caller's downline, or the caller is a founder. **UPDATE**: row is the caller's own, or caller is a founder (both USING and CHECK). A trigger further restricts `role`, `comp_level`, `upline_id`, `status` to founders. No INSERT/DELETE. |
| `agent_closure` | on | **SELECT**: the descendant is visible to the caller (`can_see_agent(descendant_id)`). No writes; only the triggers maintain it. |
| `leads` | on | **SELECT / INSERT / UPDATE**: the lead's owner is visible to the caller (CHECK applies the same test to the new row, so leads cannot be handed outside your subtree). No DELETE. |
| `lead_activity` | on | **SELECT**: the activity's author is visible to the caller. **INSERT**: author is visible **and** the target lead is visible to the caller. No UPDATE/DELETE. |
| `policies` | on | **SELECT**: the writing agent is visible. **INSERT / UPDATE**: writing agent is visible **and** the client lead is visible (new row also checked on UPDATE). No DELETE. |
| `carriers` | on | **SELECT**: caller is an agent. **INSERT / UPDATE / DELETE**: caller is a founder. |
| `products` | on | Same as carriers. |
| `lead_vendors` | on | Same as carriers. |
| `opt_outs` | on | **SELECT / INSERT**: caller is an agent. UPDATE and DELETE are not granted to anyone, founders included. `phone` is globally unique. |

## Deviations / decisions to review
- **Shared-data policies use `is_agent()`**, not "any authenticated user": with open Supabase sign-ups, anyone could otherwise read carriers or write opt-outs. Change to `current_agent_id() is not null` if you want the literal reading.
- **Founders can UPDATE any agent** (policy above), otherwise the founder-only edits of `role`/`comp_level`/`upline_id` are impossible. Enforcement is column grant + `agents_guard_privileged_columns` trigger (trusted `postgres`/`service_role`/`supabase_admin` pass; everyone else must be founder). I also put `status` in the guard so a terminated agent cannot reactivate themselves.
- **`lead_activity` and `policies` INSERT also require the referenced lead to be visible.** FK checks bypass RLS, so the spec's `can_see_agent(agent_id)` alone lets an agent attach rows to, and probe for, another branch's leads.
- `policies (product_id, carrier_id)` is a composite FK to `products (id, carrier_id)`, so a policy cannot mix a carrier and another carrier's product.
- No client can INSERT agents: `agents.id` references `auth.users`, so onboarding must run server-side (admin API / edge function).
- `is_founder()` follows the spec literally (role only). A `terminated` founder/agent keeps access until a founder changes their role/deletes the auth user; add `status = 'active'` to the helpers if you want status to gate access.
- Activity visibility follows `agent_id` (spec), so a manager's note on a downline lead is not visible to that downline agent.

## Running the tests
`scripts/run_tests.sh --supabase` (after `supabase start`) or `scripts/run_tests.sh` for plain Postgres 15+, where `tests/00_local_shim.sql` supplies the `anon`/`authenticated`/`service_role` roles, `auth.users` and `auth.uid()` (never run it on real Supabase). The last output is in `tests/last_run_output.txt`.
