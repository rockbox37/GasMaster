# GasMaster — Cost Estimate

Rough operating costs for Jirius Group LLC’s GasMaster (Flutter, local Hive + JSON backup today).  
Figures are **approximate public list prices as of 2026** — not quotes. Re-check vendor pages before budgeting.

Related: [GitHub issue #2](https://github.com/rockbox37/GasMaster/issues/2) — community MPG by year/make/model (YMM).

---

## Assumptions

| Item | Assumption |
| --- | --- |
| Active users | Hobby → ~100 → ~1,000 MAU bands below |
| Vehicles / user | ~1–3 |
| Fill-ups / vehicle / year | ~12–24 (local only; not uploaded in preferred design) |
| Vehicle photo | Local only; ~1280px edge, JPEG quality 80 (~100–400 KB typical) |
| Community payload (#2) | Opt-in **aggregates only**: YMM + unit system + avg efficiency + sample/fill count (+ optional date range). No raw fill-up stream, no PII, no photos |
| Retention | Local: device lifetime + user JSON backup. Cloud (B): keep latest aggregate per opted-in vehicle; roll up YMM stats; purge or anonymize on opt-out |
| Bundle / stores | `com.example.gasmaster` today; Apple Developer team used for device installs; store listing TBD |

---

## Fixed costs (both scenarios)

| Cost | Amount | Notes |
| --- | --- | --- |
| Apple Developer Program | ~**$99 / year** | Required for App Store / TestFlight |
| Google Play Console | ~**$25 one-time** | Required for Play Store |
| Domain (optional) | ~**$10–20 / year** | Marketing / privacy policy URL only |

**Scenario A annual floor (iOS + Android listed):** ~$99/yr + $25 once (+ optional domain).  
No backend, CDN, or analytics required.

---

## Scenario A — Local-only (current)

Everything stays on-device (Hive + local backup JSON). Photos never leave the device.

| Band | Backend | Est. monthly variable | Est. yearly store fees |
| --- | --- | --- | --- |
| Free / hobby | $0 | $0 | ~$99 (Apple) |
| ~100 users | $0 | $0 | ~$99 |
| ~1k users | $0 | $0 | ~$99 |

**Pros:** Zero infra, strongest privacy default, matches current product.  
**Cons:** No cross-user YMM comparison ([#2](https://github.com/rockbox37/GasMaster/issues/2)).

---

## Scenario B — Sync + anonymized YMM aggregates (#2)

Opt-in share of **aggregates**, server rollup by (year, make, model) with a minimum N (e.g. hide until ≥10 vehicles). Prefer this over raw fill-up streams — cheaper bandwidth/storage and privacy-friendly.

### Backend options (brief)

Rough **backend-only** monthly bands. Store fees above still apply. Assumes aggregates-only (tiny rows), no photo upload, light read traffic (open vehicle detail → fetch one YMM rollup).

| Option | Free / hobby | ~100 MAU | ~1k MAU | Notes |
| --- | --- | --- | --- | --- |
| **Supabase** | **$0** (Free; pauses after ~1 week inactivity) | **$0–25** | **~$25** (Pro base; usage usually within quota at this shape) | Postgres + Auth + RLS; good fit for YMM rollups. Pro ~$25/mo when you need always-on + backups. |
| **Firebase** | **$0** (Spark / Blaze free quotas) | **~$0** | **~$0–10** | Auth + Firestore; daily free read/write quotas easily cover aggregate sync at this scale. Blaze if you need paid Google features later. |
| **PocketBase on cheap VPS** | **~$4–6** (always-on VPS) | **~$4–6** | **~$6–12** | Single binary + SQLite; cheapest predictable always-on $, but **you** own updates, backups, TLS, uptime. |

*Estimates only (as of 2026). Egress, auth SMS, and heavy storage are out of scope if you stick to aggregates + email/OAuth/anonymous auth.*

### Scenario B total (illustrative)

| Band | Backend (pick one) | + Store (Apple/yr) | Ballpark monthly “feel” |
| --- | --- | --- | --- |
| Free / hobby | $0 managed free tier **or** ~$5 VPS | ~$8/mo amortized Apple | **$0–15** |
| ~100 | $0–25 | same | **$0–35** |
| ~1k | $0–25 managed **or** ~$6–12 VPS | same | **$10–40** |

---

## Recommendation (cheapest sensible path that still supports #2)

1. **Ship and run Scenario A** until community compare is ready — no cloud cost.  
2. **For [#2](https://github.com/rockbox37/GasMaster/issues/2):** start on **Supabase Free** (or Firebase Spark if you want always-on at $0) with **opt-in YMM aggregates only** — no photos, no raw fill-ups.  
3. When the feature is public and Free-tier pause/quotas hurt, budget **Supabase Pro (~$25/mo)** *or* stay near **$0 on Firebase** if traffic stays inside free quotas. Prefer managed over PocketBase unless you want to operate a VPS.  
4. Keep **Apple (~$99/yr)** + **Play (~$25 once)** as the only committed fixed costs; add a cheap domain only if you need a public privacy/support URL.

---

## Deferred (not in this estimate)

- Product analytics / attribution  
- Crash reporting (e.g. Crashlytics, Sentry)  
- CDN / image hosting (photos stay local)  
- Push notifications, email campaigns  
- Paid auth (SMS), multi-region HA, SOC2/Team tiers  
- Cloud backup of full garage / fill-up history  
- CI paid minutes beyond free GitHub Actions (if any)

Revisit this doc when choosing a B backend or before first store submission.
