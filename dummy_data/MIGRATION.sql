-- ============================================================
-- StockFlow — migration for the meeting requirements
-- (fresh/dry demands, entitlement month, per-demand item list,
--  and the customer's zone/designation).
--
-- RUN THIS ONCE on your LIVE Supabase project BEFORE using the
-- new app/website, or demands and zone assignments won't save.
--   Supabase → SQL Editor → New query → paste all of this → Run.
-- Every statement is idempotent — safe to run more than once.
-- ============================================================

-- Demand fields on the order cycle
alter table order_cycles add column if not exists designation       text  not null default '';
alter table order_cycles add column if not exists demand_type       text  not null default 'fresh';
alter table order_cycles add column if not exists days              int   not null default 10;
alter table order_cycles add column if not exists entitlement_month text  not null default '';
alter table order_cycles add column if not exists item_ids          jsonb not null default '[]'::jsonb;

-- The customer's zone (designation) — decides their entitlement scale
alter table profiles add column if not exists zone text not null default '';

-- Short human-readable order numbers (shown as SF-101). bigserial backfills
-- every existing row automatically.
alter table orders add column if not exists order_no bigserial;
