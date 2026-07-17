-- ============================================================
-- StockFlow — FULL RESET (fresh install state)
--
-- Deletes every item, demand/order-cycle, order (and its status
-- timeline), stock movement, broadcast, and customer account —
-- there is nothing left to compute a balance or entitlement
-- from, so those reset to zero automatically; they are not
-- stored separately. Also restarts the SF-xxx order numbering
-- at 1. Admin/staff logins are KEPT so you can still sign in.
--
--   Supabase → SQL Editor → New query → paste all of this → Run.
--
-- WARNING: this cannot be undone.
--
-- This script only reaches the database. It cannot clear what's
-- cached on a phone (on-device order history, saved profile,
-- dismissed notifications, "already nudged" flags). For a truly
-- clean device to test against, uninstall the app and reinstall
-- the latest build — scripts/install-phone.bat does both.
-- ============================================================

-- Orders and their timeline (children before parents)
delete from order_items;
delete from orders;
delete from stock_movements;
delete from customer_broadcasts;
delete from order_cycles;
delete from items;

-- Fresh SF-1, SF-2… numbering after the reset, not a continuation
-- of whatever test orders existed before.
alter sequence if exists orders_order_no_seq restart with 1;

-- Customer accounts (their auth logins too). Admin/staff are kept.
delete from auth.users u
where exists (
  select 1 from profiles p
  where p.id = u.id and p.role = 'customer'
);
delete from profiles where role = 'customer';

-- ============================================================
-- OPTIONAL: also remove staff/admin accounts (full reset).
-- Only run this block if you want to recreate the admin login
-- from scratch in Supabase → Authentication afterwards.
-- ============================================================
-- delete from auth.users;
-- delete from profiles;
