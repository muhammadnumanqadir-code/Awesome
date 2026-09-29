-- Seed: 1 founder, 2 managers, 3 agents per manager, 4 carriers x 2 products,
-- 2 lead vendors, 46 leads, activity, 9 policies, a few opt-outs.
-- Fixed UUIDs so tests and the frontend can refer to people by id.
--   founder f0000000-…-0001
--   manager A a0000000-…-0001   agents A1..A3 a1000000-…-0001..0003
--   manager B b0000000-…-0001   agents B1..B3 b1000000-…-0001..0003

insert into auth.users (instance_id, id, aud, role, email, email_confirmed_at)
select '00000000-0000-0000-0000-000000000000', id, 'authenticated', 'authenticated', email, now()
from (values
  ('f0000000-0000-0000-0000-000000000001'::uuid, 'founder@agency.test'),
  ('a0000000-0000-0000-0000-000000000001', 'manager.a@agency.test'),
  ('b0000000-0000-0000-0000-000000000001', 'manager.b@agency.test'),
  ('a1000000-0000-0000-0000-000000000001', 'agent.a1@agency.test'),
  ('a1000000-0000-0000-0000-000000000002', 'agent.a2@agency.test'),
  ('a1000000-0000-0000-0000-000000000003', 'agent.a3@agency.test'),
  ('b1000000-0000-0000-0000-000000000001', 'agent.b1@agency.test'),
  ('b1000000-0000-0000-0000-000000000002', 'agent.b2@agency.test'),
  ('b1000000-0000-0000-0000-000000000003', 'agent.b3@agency.test')
) as u(id, email);

-- parents first, so each agent's upline already has its closure rows
insert into public.agents (id, full_name, email, npn, resident_state, comp_level, role, upline_id) values
  ('f0000000-0000-0000-0000-000000000001', 'Frank Founder', 'founder@agency.test',   '1000001', 'TX', 130.00, 'founder', null);
insert into public.agents (id, full_name, email, npn, resident_state, comp_level, role, upline_id) values
  ('a0000000-0000-0000-0000-000000000001', 'Maya Manager-A', 'manager.a@agency.test', '2000001', 'TX', 120.00, 'manager', 'f0000000-0000-0000-0000-000000000001'),
  ('b0000000-0000-0000-0000-000000000001', 'Ben Manager-B',  'manager.b@agency.test', '2000002', 'FL', 120.00, 'manager', 'f0000000-0000-0000-0000-000000000001');
insert into public.agents (id, full_name, email, npn, resident_state, comp_level, role, upline_id) values
  ('a1000000-0000-0000-0000-000000000001', 'Alice Agent-A1', 'agent.a1@agency.test', '3000001', 'TX', 100.00, 'agent', 'a0000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000002', 'Aaron Agent-A2', 'agent.a2@agency.test', '3000002', 'OK', 90.00,  'agent', 'a0000000-0000-0000-0000-000000000001'),
  ('a1000000-0000-0000-0000-000000000003', 'Amy Agent-A3',   'agent.a3@agency.test', '3000003', 'TX', 90.00,  'agent', 'a0000000-0000-0000-0000-000000000001'),
  ('b1000000-0000-0000-0000-000000000001', 'Bella Agent-B1', 'agent.b1@agency.test', '3000004', 'FL', 100.00, 'agent', 'b0000000-0000-0000-0000-000000000001'),
  ('b1000000-0000-0000-0000-000000000002', 'Blake Agent-B2', 'agent.b2@agency.test', '3000005', 'GA', 90.00,  'agent', 'b0000000-0000-0000-0000-000000000001'),
  ('b1000000-0000-0000-0000-000000000003', 'Bria Agent-B3',  'agent.b3@agency.test', '3000006', 'FL', 80.00,  'agent', 'b0000000-0000-0000-0000-000000000001');

-- carriers and products
insert into public.carriers (id, name) values
  ('c0000000-0000-0000-0000-000000000001', 'Americo'),
  ('c0000000-0000-0000-0000-000000000002', 'Mutual of Omaha'),
  ('c0000000-0000-0000-0000-000000000003', 'Corebridge'),
  ('c0000000-0000-0000-0000-000000000004', 'Foresters');

insert into public.products (id, carrier_id, name, type) values
  ('d0000000-0000-0000-0000-000000000011', 'c0000000-0000-0000-0000-000000000001', 'Eagle Premier FEX',   'fex'),
  ('d0000000-0000-0000-0000-000000000012', 'c0000000-0000-0000-0000-000000000001', 'Americo Term',        'term'),
  ('d0000000-0000-0000-0000-000000000021', 'c0000000-0000-0000-0000-000000000002', 'Living Promise FEX',  'fex'),
  ('d0000000-0000-0000-0000-000000000022', 'c0000000-0000-0000-0000-000000000002', 'Income Advantage IUL','iul'),
  ('d0000000-0000-0000-0000-000000000031', 'c0000000-0000-0000-0000-000000000003', 'Max Accumulator IUL', 'iul'),
  ('d0000000-0000-0000-0000-000000000032', 'c0000000-0000-0000-0000-000000000003', 'SI Term',             'term'),
  ('d0000000-0000-0000-0000-000000000041', 'c0000000-0000-0000-0000-000000000004', 'Advantage Plus FEX',  'fex'),
  ('d0000000-0000-0000-0000-000000000042', 'c0000000-0000-0000-0000-000000000004', 'Accidental Death Rider','adb');

insert into public.lead_vendors (id, name, cost_per_lead) values
  ('e0000000-0000-0000-0000-000000000001', 'LeadBridge Direct', 12.50),
  ('e0000000-0000-0000-0000-000000000002', 'Prime Aged Leads',   7.25);

-- leads: 7 for each of the six agents + 2 for each manager = 46.
-- Dispositions rotate through all eight values; 'sold' leads become clients.
with owners(n, agent_id) as (values
  (1, 'a1000000-0000-0000-0000-000000000001'::uuid), (2, 'a1000000-0000-0000-0000-000000000002'),
  (3, 'a1000000-0000-0000-0000-000000000003'),       (4, 'b1000000-0000-0000-0000-000000000001'),
  (5, 'b1000000-0000-0000-0000-000000000002'),       (6, 'b1000000-0000-0000-0000-000000000003')),
disps(i, d) as (values
  (0,'new'::public.disposition),(1,'text_campaign'),(2,'response'),(3,'must_call'),
  (4,'no_answer'),(5,'not_interested'),(6,'follow_up'),(7,'sold')),
rows_ as (
  select o.n as o_n, k, o.agent_id, ds.d
  from owners o
  cross join generate_series(1, 7) k
  join disps ds on ds.i = (o.n + k) % 8
  union all
  select 10 + m.n, k, m.agent_id, ds.d
  from (values (1, 'a0000000-0000-0000-0000-000000000001'::uuid),
               (2, 'b0000000-0000-0000-0000-000000000001')) m(n, agent_id)
  cross join generate_series(1, 2) k
  join disps ds on ds.i = (m.n * 3 + k) % 7          -- never 'sold' for managers
)
insert into public.leads (id, owner_agent_id, first_name, last_name, phone, email, date_of_birth,
                          state, stage, disposition, lead_vendor_id)
select md5('lead-' || o_n || '-' || k)::uuid,
       agent_id,
       (array['James','Mary','Robert','Patricia','John','Jennifer','Michael','Linda'])[1 + (o_n + k) % 8],
       (array['Smith','Johnson','Williams','Brown','Jones','Garcia','Miller','Davis'])[1 + (o_n * 3 + k) % 8],
       '+1555' || lpad((o_n * 100 + k)::text, 7, '0'),
       'lead' || o_n || '_' || k || '@example.test',
       date '1955-01-01' + ((o_n * 397 + k * 211) % 9000),
       (array['TX','FL','GA','OK','OH','NC'])[1 + (o_n + k) % 6],
       case when d = 'sold' then 'client'::public.lead_stage else 'lead'::public.lead_stage end,
       d,
       case when k % 2 = 0 then 'e0000000-0000-0000-0000-000000000001'::uuid
            else 'e0000000-0000-0000-0000-000000000002'::uuid end
from rows_;

-- activity: a call on every lead, underwriting on clients, one manager note on a downline lead
insert into public.lead_activity (lead_id, agent_id, type, body, occurred_at)
select id, owner_agent_id, 'call', 'Initial outreach call', created_at + interval '1 hour'
from public.leads;
insert into public.lead_activity (lead_id, agent_id, type, body, occurred_at)
select id, owner_agent_id, 'underwriting', 'Application submitted', created_at + interval '2 days'
from public.leads where stage = 'client';
insert into public.lead_activity (lead_id, agent_id, type, body)
select l.id, 'a0000000-0000-0000-0000-000000000001', 'note', 'Manager review: push for follow-up'
from public.leads l
where l.owner_agent_id = 'a1000000-0000-0000-0000-000000000002' and l.disposition = 'follow_up'
limit 1;

-- policies: each client (sold lead) gets one; three get a second, statuses vary
with clients as (
  select l.id, l.owner_agent_id, row_number() over (order by l.id) as rn from public.leads l where l.stage = 'client'
),
plan(rn, extra, status, product_id, carrier_id, ap) as (values
  (1, 0, 'active'::public.policy_status,               'd0000000-0000-0000-0000-000000000011'::uuid, 'c0000000-0000-0000-0000-000000000001'::uuid, 1800.00),
  (2, 0, 'pending_underwriting',                       'd0000000-0000-0000-0000-000000000022', 'c0000000-0000-0000-0000-000000000002', 4200.00),
  (3, 0, 'active',                                     'd0000000-0000-0000-0000-000000000031', 'c0000000-0000-0000-0000-000000000003', 6000.00),
  (4, 0, 'declined',                                   'd0000000-0000-0000-0000-000000000041', 'c0000000-0000-0000-0000-000000000004', 1500.00),
  (5, 0, 'lapsed',                                     'd0000000-0000-0000-0000-000000000021', 'c0000000-0000-0000-0000-000000000002', 2400.00),
  (6, 0, 'cancelled',                                  'd0000000-0000-0000-0000-000000000012', 'c0000000-0000-0000-0000-000000000001',  900.00),
  (1, 1, 'pending_underwriting',                       'd0000000-0000-0000-0000-000000000032', 'c0000000-0000-0000-0000-000000000003',  720.00),
  (3, 1, 'active',                                     'd0000000-0000-0000-0000-000000000042', 'c0000000-0000-0000-0000-000000000004',  240.00),
  (5, 1, 'pending_underwriting',                       'd0000000-0000-0000-0000-000000000011', 'c0000000-0000-0000-0000-000000000001', 1200.00)
)
insert into public.policies (client_id, writing_agent_id, carrier_id, product_id, policy_number,
                             face_amount, annual_premium, monthly_premium, status, effective_date)
select c.id, c.owner_agent_id, p.carrier_id, p.product_id,
       'POL-' || lpad((p.rn * 10 + p.extra)::text, 5, '0'),
       p.ap * 12, p.ap, round(p.ap / 12, 2), p.status,
       case when p.status in ('active', 'lapsed', 'cancelled') then date '2026-01-15' + p.rn * 9 end
from clients c join plan p using (rn);

insert into public.opt_outs (phone, source) values
  ('+15550009001', 'text reply STOP'),
  ('+15550009002', 'phone request'),
  ('+15550009003', 'carrier DNC list');
