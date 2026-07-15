-- ============================================================
-- StockFlow — CLEAR ALL DATA (fresh start)
--
-- Deletes every item, order, demand, stock movement, broadcast
-- and customer account. KEEPS admin/staff logins so you can
-- still sign in to the console.
--
--   Supabase → SQL Editor → New query → paste → Run.
--
-- WARNING: this cannot be undone.
-- ============================================================

-- Orders first (children before parents)
delete from order_items;
delete from orders;
delete from stock_movements;
delete from customer_broadcasts;
delete from order_cycles;
delete from items;

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
