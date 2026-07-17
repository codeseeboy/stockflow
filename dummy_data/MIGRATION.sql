-- ============================================================
-- SUPERSEDED — everything below is now folded into supabase/schema.sql,
-- which also has the newer zone-scoped items column and the order status
-- timeline column this file was missing. Run that one instead; this file
-- is kept only for history and is safe to ignore.
-- ============================================================
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

-- Full order timeline: every status change, who made it, and when — powers
-- the "created / viewed / accepted / processing / fulfilled" tracker.
alter table orders add column if not exists status_history jsonb not null default '[]'::jsonb;

-- The order_status enum needs the fuller lifecycle too (bare statements —
-- ALTER TYPE ADD VALUE can't run inside a DO block; IF NOT EXISTS makes each
-- safe to re-run).
alter type order_status add value if not exists 'viewed';
alter type order_status add value if not exists 'accepted';
alter type order_status add value if not exists 'rejected';
alter type order_status add value if not exists 'processing';
