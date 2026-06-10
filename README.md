# StockFlow

Inventory & weekly ordering system — Flutter web (admin console) + Android app (customer ordering), backed by Supabase (PostgreSQL + realtime).

## Structure
- `lib/` — Flutter source (admin + customer)
- `build/web/` — prebuilt release website (served by Vercel as-is)
- `supabase/schema.sql` — full database schema, RLS policies, triggers
- Android APK: `flutter build apk --release`

## Deploy (Vercel)
The repo ships the prebuilt site in `build/web`. `vercel.json` points the output there — no build step needed on Vercel.

## Local dev
```
flutter pub get
flutter run -d chrome   # website
flutter run             # app on connected phone
```
