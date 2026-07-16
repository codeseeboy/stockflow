# Run scripts

Double-click any of these (or run from a terminal). Each one checks its own
prerequisites and tells you exactly what's missing.

| Script | What it does |
|---|---|
| `run-web.bat` | Preview the app **without a phone** — opens in Chrome with hot reload (`r` to reload, `q` to quit). This is also how the website behaves. |
| `run-phone.bat` | Run on a **USB-connected phone** in debug mode with hot reload. Checks the phone is plugged in and USB-debugging is allowed. |
| `install-phone.bat` | Build the **release APK** and install + launch it on the connected phone — what you hand to testers. |
| `build-website.bat` | Build the website to `build/web` (what Vercel serves). Commit + push afterwards to deploy. |

## One-time phone setup
1. On the phone: Settings → About phone → tap **Build number** 7 times (unlocks Developer options).
2. Settings → Developer options → enable **USB debugging**.
3. Plug in via USB → tap **Allow** on the phone popup (tick *Always allow*).

## URLs
- Admin console (website): https://stockflow-sjcem.vercel.app
- Customers order through shared demand links: `https://stockflow-sjcem.vercel.app/c/<token>`
