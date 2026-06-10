# StockFlow — Inventory & Weekly Ordering System
### Blueprint / Master Plan (v1)

> Working name: **StockFlow** (change kar sakte ho).
> Use case: Bulk food/grocery inventory management (rice, fruits, vegetables, bread, dairy, etc.) with a weekly real-time ordering link for customers — built for an organisation like a Navy supply/mess store.

---

## 1. Vision (ek line mein)
Admin master stock daalta hai → har week ek **live ordering link** banti hai → customers order karte hain aur **real-time stock** dekhte hain → stock khatam hone se pehle system **admin + workers ko alert** bhejta hai → reports/PDF generate hote hain.

---

## 2. Users & Roles

| Role | Kaun | Kya kar sakta hai |
|------|------|-------------------|
| **Admin** | Tu / store in-charge | Sab kuch: users banana, master stock daalna (Excel/manual), weekly link generate karna, sab orders dekhna, reports/PDF, alerts paana, settings |
| **Worker** | Admin ke under staff | Stock update/adjust, orders fulfill karna, low-stock alert paana, limited reports |
| **Customer** | Order karne wale (mess/unit) | Weekly link kholna, live stock dekhna, order place karna, apne purane orders dekhna |

**Permissions matrix (short):**
```
                 Create   Master   Weekly   Place   View All   Reports/   Get
                 Users    Stock    Link     Order   Orders     PDF        Alerts
Admin              ✓        ✓        ✓        ✗        ✓          ✓          ✓
Worker             ✗        ✓(edit)  ✗        ✗        ✓(limited) ✓(limited) ✓
Customer           ✗        ✗        ✗        ✓        own only   ✗          ✗
```

---

## 3. Core Features

1. **Master Stock Entry** — Excel/CSV upload **ya** manual entry. Yeh month ka base stock; jaise-jaise order aate hain, ghatataa hai.
2. **Item Catalog** — har item ka naam, category (grains/fruits/veg/bread/dairy…), unit (kg/litre/packet/dozen), photo, reorder level (kab "low" maanein).
3. **Weekly Ordering Link** — har week ek shareable link/form. Google Form jaisa par **live stock** ke saath; stock 0 hua toh "Out of Stock".
4. **Real-time Stock** — ek customer order kare toh baaki sabko turant updated quantity dikhe (live sync).
5. **Stock Prediction & Alerts** — consumption rate dekh ke predict: "X item Y din mein khatam hoga" → admin + worker ko alert.
6. **Notifications** — Phase 1: in-app + push. Phase 2: SMS. Phase 3: WhatsApp.
7. **Reports + PDF** — stock report, orders report, consumption report → PDF download/share.
8. **Audit Trail** — har stock change ka record (kaun, kab, kyun) — prediction aur reports dono ke liye.
9. **Security & Privacy** — role-based access; personal data share nahi hoga, sirf stock data dikhega.

---

## 4. Recommended Tech Stack (with reasoning)

> **Final pick: Flutter (app + web) + Supabase (backend)**

| Layer | Choice | Kyun |
|-------|--------|------|
| **Frontend** | **Flutter** | Ek hi codebase se **Android + iOS + Web** — teeno. Customer order page bhi Flutter Web route ban sakti hai (ya alag halki web — niche note). |
| **Backend / DB** | **Supabase** (PostgreSQL) | Inventory + orders + reports **relational data** hai → SQL best fit (joins, reports easy). |
| **Real-time** | **Supabase Realtime** | Postgres changes ka live subscription → stock turant sabko update (built-in, extra setup nahi). |
| **Auth + Roles** | **Supabase Auth + RLS** | Row Level Security se role-based access aur privacy DB level pe enforce — bahut secure. |
| **File Storage** | **Supabase Storage** | Excel uploads, item photos, generated PDFs. |
| **Server logic** | **Supabase Edge Functions + Cron** | Weekly link auto-generate, low-stock prediction job, notifications trigger. |
| **Push Notifications** | **Firebase Cloud Messaging (FCM)** | Free, reliable push (Flutter ke saath standard). |
| **PDF** | Flutter `pdf` package (client) ya Edge Function (server) | Reports → PDF. |

**Alternative (agar Supabase na chahiye):** Flutter + **Firebase** (Firestore). Real-time aur notifications aur easy, par reports/joins NoSQL mein thode awkward. Inventory ke liye main **Supabase (SQL)** recommend karta hoon.

> **Note on customer order page:** Sabse smooth experience ke liye option hai ki order page ek **alag halki web app** ho (taaki link turant khule, app install na karna pade). Phase 1 mein hum Flutter Web hi use karenge (simplicity), aur zaroorat padi toh later optimize karenge.

---

## 5. System Architecture (high level)

```
        ┌─────────────────────────────────────────────────────────┐
        │                     SUPABASE (Cloud)                      │
        │  ┌──────────┐  ┌───────────┐  ┌──────────┐  ┌──────────┐ │
        │  │ Postgres │  │ Realtime  │  │  Auth +  │  │ Storage  │ │
        │  │   DB     │  │ (live)    │  │   RLS    │  │ (files)  │ │
        │  └────┬─────┘  └─────┬─────┘  └────┬─────┘  └────┬─────┘ │
        │       │   ┌──────────────────────────┐           │       │
        │       │   │ Edge Functions + Cron     │           │       │
        │       │   │ • weekly link generate    │           │       │
        │       │   │ • low-stock predict/alert │           │       │
        │       │   │ • notification dispatch   │           │       │
        │       │   └──────────────────────────┘           │       │
        └───────┼───────────────────┬───────────────────────┼──────┘
                │                    │                        │
       ┌────────▼─────────┐ ┌────────▼─────────┐    ┌─────────▼────────┐
       │  ADMIN / WORKER  │ │  CUSTOMER (web    │    │   FCM Push +     │
       │  Flutter App     │ │  order link)      │    │   (later SMS/    │
       │  (Android/iOS)   │ │  Flutter Web      │    │    WhatsApp)     │
       └──────────────────┘ └──────────────────┘    └──────────────────┘
```

---

## 6. Data Model (tables)

```sql
-- USERS (linked to Supabase auth)
users(id, name, phone, email, role[admin|worker|customer],
      unit_or_dept, created_by, is_active, created_at)

-- ITEM CATALOG
items(id, name, category, unit[kg|litre|packet|dozen|piece],
      image_url, reorder_level, is_active, created_at)

-- LIVE STOCK (per item per month)
stock(id, item_id→items, month, opening_qty, current_qty,
      reorder_level, last_updated, updated_by)
      -- current_qty = LIVE stock (order aate hi ghatata hai)

-- AUDIT TRAIL (har change ka record → reports + prediction)
stock_movements(id, item_id→items, change_qty(+/-),
      type[master_in|order_out|restock|adjustment|spoilage],
      reference_id, note, created_by, created_at)

-- WEEKLY ORDER CYCLES (har week ka link)
order_cycles(id, title, week_start, week_end,
      status[draft|open|closed], share_token(unique), created_by, created_at)

-- ORDERS
orders(id, cycle_id→order_cycles, customer_id→users,
      customer_name, customer_phone,
      status[pending|confirmed|fulfilled|cancelled],
      created_at)

order_items(id, order_id→orders, item_id→items,
      qty_requested, qty_fulfilled)

-- NOTIFICATIONS
notifications(id, user_id→users, title, body,
      channel[inapp|push|sms|whatsapp], type[low_stock|new_link|order|...],
      status[pending|sent|failed], created_at, sent_at)
```

---

## 7. Screens (app structure)

### Admin App
- **Login**
- **Dashboard** — total items, low-stock count, active weekly link, today's orders
- **Master Stock** — Excel upload / manual add / edit, current_qty list (color-coded: green/amber/red)
- **Items** — catalog manage (add/edit, photo, category, reorder level)
- **Weekly Link** — generate link, set week dates, open/close, copy & share, QR code
- **Orders** — saare orders (filter by cycle/customer/status), fulfill
- **Users** — create admin/worker/customer, manage
- **Reports** — stock / orders / consumption → view + PDF
- **Alerts** — low-stock & prediction notifications feed
- **Settings**

### Worker App
- Login → **Dashboard** (low-stock alerts) → **Update Stock** → **Fulfill Orders** → limited **Reports**

### Customer (Web Order Page — link se khulega)
- Link kholo → (simple verify: naam + phone / OTP)
- **Live Item List** — category-wise, har item ki **live available qty**, photo, unit
- Quantity select → **Cart** → **Place Order**
- Stock 0 → **"Out of Stock"** badge, select disabled
- Order ke baad → confirmation + order summary

---

## 8. Key Flows (step-by-step)

### A) Master Stock Daalna
1. Admin → Master Stock → "Upload Excel" ya "Add Manually"
2. Excel parse → items match/create → `opening_qty` & `current_qty` set
3. `stock_movements` mein `master_in` entry → audit trail shuru

### B) Weekly Link + Ordering (dil of the app)
1. Admin → "Generate Weekly Link" → week dates + status `open` → unique `share_token` → shareable URL + QR
2. (Phase 1) Admin link copy karke share kare / (Phase 2-3) auto SMS/WhatsApp registered customers ko
3. Customer link kholta hai → **live stock** dikhta hai (Supabase Realtime)
4. Customer order place → `orders` + `order_items` create → **`current_qty` ghatata hai** → `stock_movements` `order_out`
5. Realtime push → baaki sab customers ko updated/Out-of-Stock turant dikhta hai

### C) Low-Stock Prediction & Alert
1. Cron Edge Function (daily) chale
2. Har item: pichle movements se **avg daily consumption** nikalo
3. `days_to_stockout = current_qty / avg_daily_consumption`
4. Agar `current_qty ≤ reorder_level` **ya** `days_to_stockout ≤ N` → **alert** admin + workers ko (in-app + push)
5. Notification log + dashboard pe dikhao

### D) Report / PDF
1. Admin → Reports → type + date range choose
2. SQL aggregate (stock snapshot / orders / consumption)
3. PDF generate → download / share

---

## 9. Notifications — Phased Plan

| Phase | Channel | Notes |
|-------|---------|-------|
| **1 (MVP)** | In-app + **FCM Push** | Free, turant. Low-stock + new-link + order alerts. |
| **2** | **SMS** | Provider (e.g. MSG91/Twilio). Customers ko link SMS pe. |
| **3** | **WhatsApp** | WhatsApp Business API (Meta/Twilio) — business verify + cost. Tere request pe **baad mein**. |

> Code aise design karenge ki notification ka ek hi "dispatch" layer ho — naya channel add karna easy.

---

## 10. Security & Privacy
- **Supabase Auth** + **Row Level Security**: customer sirf apna data; worker limited; admin full — DB level pe enforce.
- Order page pe customer ka personal data **dusre customers ko nahi dikhega** — sirf stock data public-ish (link wale ko).
- Share token random + expirable (week close hone pe link band).
- All traffic HTTPS; passwords/OTP secure.

---

## 11. Roadmap (phased delivery)

### 🟢 Phase 1 — MVP (core, sabse pehle)
- [ ] Supabase project + DB schema + RLS
- [ ] Auth + roles (admin/worker/customer)
- [ ] Item catalog (add/edit)
- [ ] Master stock entry (manual first, Excel next)
- [ ] Weekly link generate + open/close
- [ ] Customer web order page with **live stock**
- [ ] Order place → stock auto-decrement (real-time)
- [ ] Basic admin dashboard

### 🟡 Phase 2 — Smart + Reports
- [ ] Excel/CSV import
- [ ] Low-stock prediction + push alerts (FCM)
- [ ] Reports + PDF generation
- [ ] Worker app flows
- [ ] SMS notifications

### 🔵 Phase 3 — Polish
- [ ] WhatsApp integration
- [ ] QR code for link
- [ ] Advanced analytics/charts
- [ ] Multi-store / multi-month history

---

## 12. Open decisions (jab time mile, batana)
1. **Login for customers:** OTP (phone) ya simple naam+phone? (OTP zyada secure, thoda extra setup)
2. **Pricing/billing:** Kya orders mein price/amount bhi chahiye, ya sirf quantity? (abhi maana: sirf quantity)
3. **Multi-store:** Abhi ek store, ya future mein kai stores? (abhi: ek)
4. **Project ka final naam.**

---

*Yeh living document hai — har phase pe update karenge.*
