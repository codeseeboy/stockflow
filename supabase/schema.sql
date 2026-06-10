-- ============================================================
-- StockFlow — Supabase schema
-- Run this in your Supabase project: SQL Editor → New query → paste → Run.
-- ============================================================

-- ---------- Enums ----------
do $$ begin
  create type user_role    as enum ('admin','worker','customer');
exception when duplicate_object then null; end $$;
do $$ begin
  create type order_status as enum ('pending','confirmed','fulfilled','cancelled');
exception when duplicate_object then null; end $$;
do $$ begin
  create type cycle_status as enum ('draft','open','closed');
exception when duplicate_object then null; end $$;

-- ---------- Profiles (extends auth.users) ----------
create table if not exists profiles (
  id          uuid primary key references auth.users on delete cascade,
  name        text not null,
  role        user_role not null default 'customer',
  phone       text,
  unit        text,
  created_at  timestamptz not null default now()
);

-- ---------- Items (master stock + live qty) ----------
create table if not exists items (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  emoji         text default '📦',
  category      text not null,
  unit          text not null,
  opening_qty   numeric not null default 0,
  current_qty   numeric not null default 0,
  reorder_level numeric not null default 0,
  is_active     boolean not null default true,
  created_at    timestamptz not null default now()
);

-- ---------- Stock movements (audit trail → reports + prediction) ----------
create table if not exists stock_movements (
  id          uuid primary key default gen_random_uuid(),
  item_id     uuid references items on delete cascade,
  change_qty  numeric not null,                 -- +in / -out
  type        text not null,                    -- master_in | order_out | restock | adjustment
  note        text,
  created_by  uuid references profiles,
  created_at  timestamptz not null default now()
);

-- ---------- Weekly order cycles ----------
create table if not exists order_cycles (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  week_start   date not null,
  week_end     date not null,
  status       cycle_status not null default 'open',
  share_token  text unique not null default encode(gen_random_bytes(5),'hex'),
  created_at   timestamptz not null default now()
);

-- ---------- Orders ----------
create table if not exists orders (
  id              uuid primary key default gen_random_uuid(),
  cycle_id        uuid references order_cycles on delete set null,
  customer_id     uuid references profiles,
  customer_name   text not null,
  customer_phone  text,
  status          order_status not null default 'pending',
  created_at      timestamptz not null default now()
);

create table if not exists order_items (
  id            uuid primary key default gen_random_uuid(),
  order_id      uuid references orders on delete cascade,
  item_id       uuid references items,
  qty_requested numeric not null,
  qty_fulfilled numeric
);

-- ---------- Customer broadcasts (in-app + SMS/WhatsApp log) ----------
create table if not exists customer_broadcasts (
  id               uuid primary key default gen_random_uuid(),
  title            text not null,
  body             text not null,
  item_emoji       text,
  in_app           boolean not null default true,
  sms              boolean not null default true,
  whatsapp         boolean not null default true,
  recipient_count  int not null default 0,
  created_at       timestamptz not null default now()
);

create index if not exists idx_broadcasts_created on customer_broadcasts(created_at desc);

create index if not exists idx_orders_cycle on orders(cycle_id);
create index if not exists idx_order_items_order on order_items(order_id);
create index if not exists idx_movements_item on stock_movements(item_id);

-- ============================================================
-- Helper: is the caller a staff member (admin/worker)?
-- ============================================================
create or replace function public.is_staff() returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from profiles where id = auth.uid() and role in ('admin','worker'));
$$;

-- ============================================================
-- Row Level Security
-- Stock data is shareable (public read). Personal data (orders,
-- profiles) is restricted. This matches the "share stock, not
-- personal data" privacy rule.
-- ============================================================
alter table profiles        enable row level security;
alter table items           enable row level security;
alter table stock_movements enable row level security;
alter table order_cycles    enable row level security;
alter table orders          enable row level security;
alter table order_items     enable row level security;
alter table customer_broadcasts enable row level security;

-- Broadcasts: anyone can READ (customer app); staff can insert
drop policy if exists broadcasts_read on customer_broadcasts;
create policy broadcasts_read on customer_broadcasts for select using (true);
drop policy if exists broadcasts_write on customer_broadcasts;
create policy broadcasts_write on customer_broadcasts for insert with check (true);

-- Items: anyone can READ (the public order link shows live stock); staff WRITE
drop policy if exists items_read on items;
create policy items_read on items for select using (true);
drop policy if exists items_write on items;
create policy items_write on items for all using (is_staff()) with check (is_staff());

-- Cycles: anyone can READ (link); staff WRITE
drop policy if exists cycles_read on order_cycles;
create policy cycles_read on order_cycles for select using (true);
drop policy if exists cycles_write on order_cycles;
create policy cycles_write on order_cycles for all using (is_staff()) with check (is_staff());

-- Orders: staff see all; a customer sees their own. Inserts go through the RPC below.
drop policy if exists orders_read on orders;
create policy orders_read on orders for select using (is_staff() or customer_id = auth.uid());
drop policy if exists orders_write on orders;
create policy orders_write on orders for update using (is_staff()) with check (is_staff());

drop policy if exists order_items_read on order_items;
create policy order_items_read on order_items for select
  using (is_staff() or exists (select 1 from orders o where o.id = order_id and o.customer_id = auth.uid()));

-- Stock movements + profiles: staff only (profiles also: read your own)
drop policy if exists movements_staff on stock_movements;
create policy movements_staff on stock_movements for all using (is_staff()) with check (is_staff());

drop policy if exists profiles_read on profiles;
create policy profiles_read on profiles for select using (id = auth.uid() or is_staff());
drop policy if exists profiles_self on profiles;
create policy profiles_self on profiles for update using (id = auth.uid() or is_staff());
drop policy if exists profiles_insert_self on profiles;
create policy profiles_insert_self on profiles for insert with check (id = auth.uid());

-- ============================================================
-- Auto-create a customer profile whenever someone signs up.
-- SECURITY DEFINER so it bypasses RLS. Uses the name/phone passed
-- as signup metadata, falling back to the email prefix.
-- ============================================================
-- Customer email lives on the profile so admin broadcasts can reach it.
alter table profiles add column if not exists email text default '';

create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, name, role, phone, email)
  values (
    new.id,
    coalesce(nullif(new.raw_user_meta_data->>'name', ''), split_part(new.email, '@', 1)),
    'customer',
    new.raw_user_meta_data->>'phone',
    new.email
  )
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: every existing auth user gets a customer profile (covers accounts
-- created before the trigger existed). Safe to re-run.
insert into profiles (id, name, role, phone, email)
select
  u.id,
  coalesce(nullif(u.raw_user_meta_data->>'name', ''), split_part(u.email, '@', 1)),
  'customer',
  u.raw_user_meta_data->>'phone',
  u.email
from auth.users u
where not exists (select 1 from profiles p where p.id = u.id);

-- Keep emails filled for profiles created before the email column existed.
update profiles p set email = u.email
from auth.users u
where u.id = p.id and (p.email is null or p.email = '');

-- ============================================================
-- place_order(): atomic stock decrement + order creation.
-- SECURITY DEFINER so the public order link (anon) can place an
-- order without exposing write access to the tables directly.
-- p_items = jsonb: [{"item_id":"...","qty":10}, ...]
-- ============================================================
create or replace function public.place_order(
  p_cycle uuid,
  p_name  text,
  p_phone text,
  p_items jsonb
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_order uuid;
  rec record;
  v_take numeric;
  v_have numeric;
begin
  insert into orders(cycle_id, customer_id, customer_name, customer_phone, status)
  values (p_cycle, auth.uid(), p_name, p_phone, 'pending')
  returning id into v_order;

  for rec in
    select * from jsonb_to_recordset(p_items) as x(item_id uuid, qty numeric)
  loop
    select current_qty into v_have from items where id = rec.item_id for update;
    v_take := least(rec.qty, coalesce(v_have, 0));
    if v_take > 0 then
      update items set current_qty = current_qty - v_take where id = rec.item_id;
      insert into order_items(order_id, item_id, qty_requested, qty_fulfilled)
        values (v_order, rec.item_id, rec.qty, v_take);
      insert into stock_movements(item_id, change_qty, type)
        values (rec.item_id, -v_take, 'order_out');
    end if;
  end loop;

  return v_order;
end;
$$;

-- Let the public order link call it
grant execute on function public.place_order(uuid, text, text, jsonb) to anon, authenticated;

-- ============================================================
-- Realtime: broadcast item/stock changes so every open page
-- updates live.
-- ============================================================
do $$ begin
  alter publication supabase_realtime add table items;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table orders;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table order_cycles;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table customer_broadcasts;
exception when duplicate_object then null; end $$;

-- ============================================================
-- Seed: sample stock + one open week. Only runs if empty, so it
-- is safe to re-run the whole file.
-- ============================================================
insert into items (name, emoji, category, unit, opening_qty, current_qty, reorder_level)
select * from (values
  ('Basmati Rice','🍚','Grains','kg',1200,920,300),
  ('Wheat Flour (Atta)','🌾','Grains','kg',800,540,200),
  ('Toor Dal','🫘','Pulses','kg',400,150,160),
  ('Chana Dal','🟡','Pulses','kg',300,210,100),
  ('Potato','🥔','Vegetables','kg',600,430,150),
  ('Onion','🧅','Vegetables','kg',500,205,150),
  ('Tomato','🍅','Vegetables','kg',300,70,90),
  ('Green Chilli','🌶️','Vegetables','kg',60,11,16),
  ('Carrot','🥕','Vegetables','kg',180,96,50),
  ('Banana','🍌','Fruits','dozen',200,42,55),
  ('Apple','🍎','Fruits','kg',250,175,60),
  ('Orange','🍊','Fruits','kg',200,130,50),
  ('Milk','🥛','Dairy','litre',400,250,110),
  ('Eggs','🥚','Dairy','dozen',350,120,100),
  ('Paneer','🧀','Dairy','kg',120,64,45),
  ('Bread','🍞','Bakery','packet',300,0,60),
  ('Butter','🧈','Dairy','kg',90,58,30),
  ('Cooking Oil','🛢️','Essentials','litre',300,235,80),
  ('Sugar','🍬','Essentials','kg',250,188,70),
  ('Tea','🍵','Essentials','kg',80,22,26),
  ('Salt','🧂','Essentials','kg',150,118,40)
) as v(name,emoji,category,unit,opening_qty,current_qty,reorder_level)
where not exists (select 1 from items);

insert into order_cycles (title, week_start, week_end, status)
select 'Week 23','2026-06-02','2026-06-08','open'::cycle_status
where not exists (select 1 from order_cycles);
