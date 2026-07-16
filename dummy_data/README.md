# Dummy data & test setup

Everything you need to test the new meeting-requirement flow. **You do _not_ need
new data from the unit to test** — the app already ships with the real RIK
Officers per-day scale, and you already uploaded stock. These files just let you
exercise the new features and demonstrate two zones behaving differently.

---

## STEP 0 (required once) — wipe old data + apply the migration

The phone app talks to your **live** Supabase. Run both scripts in
Supabase → **SQL Editor → New query**:

1. **`WIPE_DATA.sql`** — deletes all old items, orders, demands and customer
   accounts so you start fresh. Admin/staff logins are kept. *(Cannot be undone.)*
2. **`MIGRATION.sql`** — adds the new demand/zone columns **and the short
   order-number column (SF-101 codes)**. Without it, raising a demand or
   assigning a zone won't save. Safe to run more than once — if you ran an
   older copy, run it again to pick up `order_no`.

After the wipe the app starts empty — upload your stock Excel again from the
admin console (Import master stock) to load the item catalogue.

---

## STEP 1 — set up zones (designations)

Admin console → **Zones**

- **Officers** already exists with the real RIK scale — nothing to do.
- (Optional) tap **New zone**, name it **Commanders**, start from *Officers scale*.
  This shows Zone A ≠ Zone B.

### Import an entitlement sheet (optional, to test the importer)
Open a zone → **Entitlement scale → Import Excel**, then pick one of:

| File | What it shows |
|------|----------------|
| `entitlement_officers.csv` | The per-day scale (matches the built-in Officers scale). |
| `entitlement_commanders.csv` | A richer scale — use it on the **Commanders** zone to see the difference. |
| `entitlement_officers_monthly.csv` | Values stated **per 30 days** with a `Days` column — the importer divides them back to a per-day rate automatically. |

> The sheet needs a **Category** column and a **Per Day** (or **Entitlement**)
> column. A `Days` column is optional — include it when the figures are stated
> over a period instead of per day.

---

## STEP 2 — customers & their zone

Admin console → **Users**

- Each customer needs a zone. Add one with **Add user → Customer → Ration scale**,
  or tap the **shield icon** on an existing customer row to set/change it.
- Put a couple of test customers in **Officers** and, if you made it, one in
  **Commanders**.

---

## STEP 3 — raise demands (this is the new flow)

Admin console → **Demands → Raise demand**

Reproduce the unit's monthly cycle:

1. **Fresh · 10 days · this month** — tick meat, vegetables, fruit, onion, potato,
   butter, eggs, milk, **and bread**. Open it.
2. Place a customer demand against it (take some **bread**). Note the Cereals
   balance drops.
3. **Dry · 30 days · same month** — tick atta, rice, dal, oil, sugar, **and bread**.
   Open it and check: the Cereals balance already reflects the bread taken on the
   fresh demand → **carry-forward within the month** ✔

### What to verify
- Customer **Home** shows *"Balance left with you"* even with **no demand open**.
- With no demand open the Order tab says *"Demand acceptance has not started yet."*
- A customer who orders nothing sees their **full** entitlement (the on-leave case).
- Ordering more than the balance is refused.
- Next month, leftover is added on top of the new allowance (e.g. 500 + 300 = 800).
- The customer only sees the varieties you ticked — untick something and it
  disappears from their list.

---

## Notes on the RIK numbers
The Officers figures are the real per-day scale, so the monthly dal works out to
`0.04 × 30 = 1.2 kg` — the exact figure from the meeting. Swap in the unit's real
sheet later via the same **Import Excel** button; nothing else changes.
