# Automatic Email Setup (free, ~10 min)

When the admin sends a notification with **Email** enabled, every customer with an
email on file is emailed automatically — no manual button. Uses your Gmail via SMTP.

## 1. Create a Gmail App Password
1. Use any Gmail account (a dedicated one like `stockflow.navy@gmail.com` is cleanest).
2. Turn on **2-Step Verification**: https://myaccount.google.com/security
3. Go to **App passwords**: https://myaccount.google.com/apppasswords
4. App = "Mail", Device = "Other" → name it `StockFlow` → **Generate**.
5. Copy the 16-character password (looks like `abcd efgh ijkl mnop`) — remove spaces.

## 2. Deploy the Edge Function
1. Supabase Dashboard → **Edge Functions** → **Create a function**.
2. Name it exactly: `send-broadcast-email`
3. Paste the contents of `supabase/functions/send-broadcast-email/index.ts`.
4. Click **Deploy**.

## 3. Add the secrets
Dashboard → **Edge Functions** → **Secrets** (or Project Settings → Edge Functions),
add two secrets:

| Name | Value |
|------|-------|
| `GMAIL_USER` | your full gmail address |
| `GMAIL_APP_PASSWORD` | the 16-char app password (no spaces) |

`SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are already available automatically.

## 4. Done
Send a notification from the admin console with Email ticked. The dialog will show
**"Email sent automatically to N customers"**. Customers receive a branded StockFlow email.

### Notes
- Gmail allows ~500 recipients/day on a free account — plenty for a mess unit.
- Goes to all profiles with `role = 'customer'` and a non-empty email.
- If the function isn't deployed yet, the app silently falls back to the manual
  "Email all" button (opens your mail app pre-filled). Nothing breaks.
