# Connecting StockFlow to Supabase

Two things only **you** can do (your account / your data). Takes ~10 minutes.
After this, I wire the app's Dart side to it and stock becomes real & shared across devices.

---

## ✅ Step 0 — Enable Windows Developer Mode (one-time, required)
The Supabase Flutter package uses native plugins. On Windows, `flutter pub get`
needs symlink support for plugins, which requires Developer Mode.

1. Press **Win + R**, type `ms-settings:developers`, Enter.
2. Turn **Developer Mode** → **On** (accept the prompt).

> Until this is on, I keep the app on the current pure-Dart packages so it
> stays working.

---

## ✅ Step 1 — Create a Supabase project (free)
1. Go to **https://supabase.com** → sign in → **New project**.
2. Name: `stockflow`. Choose a region near you (e.g. Mumbai / Singapore).
3. Set a database password (save it somewhere).
4. Wait ~2 min for it to provision.

## ✅ Step 2 — Run the schema
1. In the project: **SQL Editor → New query**.
2. Open [`schema.sql`](schema.sql), copy everything, paste, click **Run**.
3. You should see "Success". This creates all tables, security rules,
   the `place_order` function, and turns on realtime.

## ✅ Step 3 — Create the first admin user
1. **Authentication → Users → Add user** → email + password (this is your admin login).
2. Copy that user's **UID**.
3. **SQL Editor**, run (replace the UID and name):
   ```sql
   insert into profiles (id, name, role, unit)
   values ('PASTE-UID-HERE', 'Arjun Mehta', 'admin', 'Central Store');
   ```

## ✅ Step 4 — Get your keys
1. **Project Settings → API**.
2. Copy these two and send them to me:
   - **Project URL** (e.g. `https://abcdxyz.supabase.co`)
   - **anon public** key (the long `eyJ...` one — the *anon*, **not** the service_role)

> The anon key is safe to ship in a client app (RLS protects the data).
> Never share the **service_role** key.

---

## What I do next (once you send the URL + anon key)
1. Add `supabase_flutter`, initialise it in `main.dart`.
2. Swap the in-memory `AppStore` for a Supabase-backed data layer (same method names — screens don't change).
3. Wire **realtime** so stock updates live across all devices.
4. Add login for admin/staff; the customer order link stays public.
5. Seed your real items (or import via Excel).

Then we move to the **Android app** so you can see it on your phone.
