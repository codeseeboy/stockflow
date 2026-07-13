# StockFlow — Image Generation Prompts for Presentation

*Companion document to `PROJECT_OVERVIEW.md`. It contains ready-to-paste prompts for generating the four presentation images (via Gemini or any AI image generator), along with where each image fits in the PPT and how to keep all four visually consistent.*

---

## How to Use This Document

1. Each section below corresponds to **one slide / one image**.
2. Copy the entire prompt inside the code block **as-is** and paste it into Gemini.
3. Generate all four images in the **same session** so the style stays consistent.
4. If any output comes out 3D, glossy, or over-colored, regenerate after appending the fix-line given in the last section.

### Image-to-Slide Mapping (at a glance)

| # | Image | Purpose in PPT | Suggested Slide Position |
|---|-------|----------------|--------------------------|
| 1 | Complete System at One Glance | Main overview — shows Admin side, Customer side, and the live central system together | Right after the Problem Statement slide |
| 2 | Admin Website Flow | Explains the admin's 6-step working of the website | "Admin Console" section |
| 3 | Customer App Journey | Explains the customer's 5-step ordering journey on the app | "Customer App" section |
| 4 | Behind the Scenes | The only lightly-technical slide — security, live sync, roles | Near the end, before the roadmap/future-features slide |

### Common Visual Style (applies to all four images)

- **Look:** flat corporate vector infographic — no 3D, no photorealism, no emojis, no cartoon people.
- **Colors:** navy blue (primary) · white (background) · light grey (panels) · one muted gold accent (highlights). Nothing else.
- **Text:** clean sans-serif only.
- **Format:** 16:9 landscape, high resolution — drops straight into a PPT slide.

---

## Image 1 — The Complete System at One Glance

**Use for:** the main overview slide. Shows all three parts of the system side by side — what the **Admin does on the website**, what the **Customer does on the app**, and how the **central system keeps both in sync**.

```
Create a professional, presentation-grade infographic showing the complete working of a digital ration ordering system called "StockFlow", for a formal slide shown to senior officials (16:9 landscape, high resolution).

STYLE (strict):
- Clean flat-vector corporate diagram style. NOT photorealistic, NOT 3D, no glossy AI-art effects, no emojis, no cartoon characters.
- Palette limited to: navy blue (primary), white background, light grey panels, and one muted gold accent for highlights. Nothing else.
- One consistent icon set, uniform thin line weight, clean sans-serif text only.
- Soft shadows and rounded card corners for polish, but no gradients, textures, or decorations.

TITLE at top center: "StockFlow — How the System Works" with a thin divider line under it.

LAYOUT — three vertical zones side by side:

LEFT ZONE, titled "Admin (Website)":
A laptop/desktop mockup with a simple dashboard on screen, and beneath it 4 short labeled line-icon rows stacked vertically:
- "Loads weekly stock" (box/inventory icon)
- "Sets ration limits per person" (scale/measure icon)
- "Opens ordering window & shares link" (link icon)
- "Approves & fulfils orders" (checkmark clipboard icon)

CENTER ZONE, titled "Central System (Live & Secure)":
A single rounded panel in the middle with a cloud/database line icon, and 3 short labels inside:
- "Live stock count — updates instantly"
- "Ration limits enforced automatically"
- "All records saved for reports"
Two-way arrows connect this center panel to both the left and right zones, labeled "instant sync".

RIGHT ZONE, titled "Customer (Mobile App)":
A phone mockup showing a simple item list on screen, and beneath it 4 short labeled line-icon rows:
- "Gets notified when ordering opens" (bell icon)
- "Sees what is available right now" (list icon)
- "Orders within their allowed limit" (limit-bar icon)
- "Tracks order till delivery" (progress-tracker icon)

BOTTOM STRIP: a thin footer bar with 4 evenly spaced benefit statements, each with a small navy icon:
"No paperwork" · "No over-ordering" · "Live visibility for all" · "Instant reports"

BALANCE RULES: generous white space, equal visual weight in left and right zones, nothing overlapping, readable even as a small slide thumbnail. Prioritize clarity over density.
```

---

## Image 2 — Admin Website Flow

**Use for:** the slide explaining the admin side. A 6-step flow (two rows of three cards) covering the full weekly working of the website — from loading stock to downloading reports.

```
Create a professional flat-vector infographic showing the step-by-step working of the Admin website of a ration ordering system called "StockFlow" (16:9 landscape, presentation quality, for senior officials).

STYLE: same strict rules — flat corporate vector, navy blue + white + light grey + one muted gold accent only, one consistent icon set, clean sans-serif text, soft card shadows, no emojis, no 3D, no gradients, no people illustrations.

TITLE at top: "Admin Website — Managing the Store Digitally"

LAYOUT: 6 numbered steps arranged in two rows of three white rounded cards (read left to right, top row first), connected by a thin navy arrow path that flows through all six. Each card has a gold numbered circle, a small laptop-screen mockup with a simple relevant screen layout, a bold short label, and one grey descriptive line.

1. "Load Stock" — screen shows a simple item table; description: "Add items manually or upload the full stock sheet in one go."
2. "Set Ration Limits" — screen shows a category list with small limit bars; description: "Fix how much each person can order, as per entitlement."
3. "Open Order Window" — screen shows a link with a share button; description: "Generate a weekly ordering link and share it with all customers."
4. "Notify Everyone" — screen shows a message panel with channel toggles; description: "Announce via app alert, SMS, WhatsApp or email — in one click."
5. "Manage Orders Live" — screen shows an order list with status tags; description: "Watch orders arrive in real time, approve and mark fulfilled."
6. "Download Reports" — screen shows a document with a download button; description: "Get stock, order and shortage reports as ready PDF files."

BOTTOM: one thin gold-accented note strip: "Everything the admin does reflects instantly on every customer's app."

BALANCE: equal card sizes, even icon density, clear white space, legible at thumbnail size.
```

---

## Image 3 — Customer App Journey

**Use for:** the slide explaining the customer side. A 5-step left-to-right journey — from getting notified to tracking the order — with the ration-limit enforcement shown visually in step 3.

```
Create a professional flat-vector infographic showing the journey of a customer using the "StockFlow" mobile ordering app (16:9 landscape, presentation quality, for senior officials).

STYLE: flat corporate vector only — navy blue + white + light grey + one muted gold accent, one consistent icon set, sans-serif text, soft card shadows, no emojis, no 3D, no gradients, no cartoon people.

TITLE at top: "Customer App — Ordering Made Simple & Fair"

LAYOUT: 5 white rounded cards left to right, each with a gold step number, a detailed-but-tidy phone mockup (status bar + app top bar + 4-5 simple UI elements max), a bold label above and one grey description line below. A thin navy arrow line connects all five.

1. "Get Notified" — phone shows a notification banner "Ordering is now open"; description: "The moment the admin opens the window, every customer knows."
2. "See Live Stock" — phone shows category tabs and 3 item rows each with a quantity and a small green availability dot; description: "What you see is what is actually left — updated live."
3. "Order Within Limit" — phone shows an item with a +/- stepper and a gold limit bar labeled "Used 4 of 7 kg"; description: "The app itself stops any order beyond the allowed ration."
4. "Place Order" — phone shows a 3-line order summary and a bold "Place Order" button; description: "One tap to submit — no forms, no paperwork."
5. "Track till Fulfilled" — phone shows a 3-stage tracker "Placed → Confirmed → Fulfilled" with the middle stage in gold; description: "Full visibility of every order, past and present."

BOTTOM STRIP: three evenly spaced icon highlights: "Works on any phone" · "Guest access available" · "Order history saved week-wise"

BALANCE: even visual weight across cards, generous white space, must stay readable at small size.
```

---

## Image 4 — Behind the Scenes (Lightly Technical)

**Use for:** the technology/trust slide near the end of the deck. The only image that mentions technology — kept in plain words (central database, live sync, role-based access, audit records) suitable for a senior, non-technical audience.

```
Create a clean, professional flat-vector diagram showing what happens behind the scenes in the "StockFlow" ration ordering system, kept simple enough for a non-technical senior audience (16:9 landscape, presentation quality).

STYLE: flat corporate vector — navy blue + white + light grey + one muted gold accent only, consistent thin-line icons, sans-serif text, soft shadows, no emojis, no 3D, no gradients.

TITLE at top: "Behind the Scenes — Secure, Live & Reliable"

LAYOUT: a horizontal three-block architecture, connected by labeled two-way arrows:

LEFT BLOCK "Admin Website" — laptop icon, small caption: "Built as a web console — works on any browser, no installation."

CENTER BLOCK (largest, gold-outlined) "Secure Cloud Backbone" — one large rounded panel containing 4 small stacked rows, each with a line icon and short label:
- "One central database — single source of truth"
- "Live sync — every change reaches all screens in seconds"
- "Role-based access — admin, staff and customers see only what they should"
- "Automatic record of every stock change, for audit"

RIGHT BLOCK "Customer Mobile App" — phone icon, small caption: "Single app built once, runs on Android phones and the web."

Arrows: left↔center labeled "manages", center↔right labeled "updates live".

BOTTOM STRIP: a thin footer with 3 evenly spaced assurance points with small icons:
"Encrypted & password-protected access" · "No customer data visible to other customers" · "Reports generated from the same live data — no manual tallying"

BALANCE: minimal, airy, senior-briefing tone — clarity over detail, nothing overlapping, readable at thumbnail size.
```

---

## Fix-Line (if the output drifts)

If any generated image comes out **3D, glossy, over-colored, or cluttered**, regenerate with this line appended to the end of the prompt:

```
Strictly flat 2D vector, corporate briefing style, navy-white-grey-gold palette only — reject 3D, glossy or colorful rendering.
```

### Final Checklist Before Adding to PPT

- [ ] All four images use the same navy–white–grey–gold palette.
- [ ] All images are 16:9 landscape and sharp at full-slide size.
- [ ] Text inside the images is spelled correctly (AI generators sometimes garble text — regenerate if any label is misspelled).
- [ ] No emojis, cartoon people, or off-palette colors slipped in.
- [ ] Each image is placed on the slide matching the table in the "Image-to-Slide Mapping" section above.
