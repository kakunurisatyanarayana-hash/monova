# Monova Live Market: audit and status

Audit of the Flutter app before Live Market was added, the sources checked, and what is built.

## 1. Existing architecture

- Flutter app in `mobile/`. State with Riverpod, navigation with go_router (`lib/app/router.dart`), shell with bottom navigation and the wide sidebar (`lib/features/shell/main_shell.dart`).
- Offline-first. Data lives on the phone in `LocalStore` (`lib/core/local_store.dart`), which stores JSON lists in shared_preferences under `monova.*` keys. Phones keep the most sensitive lists (vault, cards) in flutter_secure_storage.
- The offline build (`--dart-define=MONOVA_OFFLINE=true`) hides sign-in and account features. It can still make public network requests.
- Existing HTTP: `dio` (used by the Nominatim geo service). Existing charts: `fl_chart`. Existing location: `geolocator`, `flutter_map`. Android has the INTERNET permission.

## 2. Existing database

- No SQL database. Each record list is a JSON list in shared_preferences. Nothing existing was changed or migrated.
- New keys: `monova.market.bullion` (stored prices, one record per product and day) and `monova.market.sync` (last successful fetch and last error per dataset). Both are new, so existing data is untouched.

## 3. Sources: what was checked, from this machine

| Source | Checked | Result | Used |
|---|---|---|---|
| snapdata.dev, gold `latest.json` | 27 Nov 2026 | 200, JSON, 24K, 22K and 18K per gram, IBJA, status provisional | Yes |
| snapdata.dev, gold `series/30d.json` | 27 Nov 2026 | 200, 30 days, 87 usable values of 108 observations | Yes |
| snapdata.dev, silver `latest.json` and `series/30d.json` | 27 Nov 2026 | 200, per kg, 29 usable values of 36 days, 7 days marked missing | Yes |
| snapdata.dev CORS | 27 Nov 2026 | `Access-Control-Allow-Origin: *`, so the web build can read it | Yes |
| snapdata.dev gold `series/7d`, `series/90d` | 27 Nov 2026 | Not published | No |
| api.metalcharts.org | Docs page only | Reachable. Licence, quotas and endpoints not verified | No |
| CEDA AGMARKNET (api.ceda.ashoka.edu.in) | 27 Nov 2026 | `GET` routes return 404. Swagger page loads, but its spec file was not found, so request and response schemas are unverified. Access likely needs a registered token | No |
| data.gov.in mandi dataset | 27 Nov 2026 | 301 redirect; the API needs a free registered key | No |
| IOCL petrol-diesel page | 27 Nov 2026 | Blocked by a bot check, so no usable data | No |
| Consumer Affairs (fcainfoweb.nic.in) | Not tested in this pass | Still to check | No |

## 4. Licence and attribution

- snapdata states, for gold and silver: "IBJA domestic benchmark, republished with attribution, no formal licence". The app shows IBJA and snapdata.dev as the source on every price and in the Sources section.
- Risk to confirm with you: IBJA has not granted a formal licence. Commercial use would need IBJA's permission. A free, non-commercial app with attribution is the current position.

## 5. Behaviour built

- Prices come only from a successful fetch. A failed refresh keeps the stored prices and shows the reason.
- Each day's price keeps its source, licence, status (final or provisional) and fetch time.
- Missing days are stored as nothing. The chart shows them as gaps and never joins across them.
- Freshness: "Today" only for a price dated today. "Recent" within three days. "Old, not today" after that.
- A refresh runs only when the person presses Refresh, with one retry for a dropped connection. No background work.
- Gold and silver are compared per gram; silver's per-kilogram value is shown too.

## 6. Not built yet, and why

- **Mandi prices (AGMARKNET/CEDA):** need a verified schema and a key. Shown as "waiting".
- **Consumer Affairs retail and wholesale:** no verified machine-readable export yet. Shown as "waiting".
- **Fuel:** no permitted, verified source yet. Shown as "waiting".
- **Other categories** (grains, vegetables, dairy, eggs, meat and fish, construction, household): waiting for a verified source or community entries.
- **Location:** not built yet. Gold and silver are national benchmarks, so location does not change them. Location matters for mandi and fuel data, which are not available yet.
- **Community submissions, shopkeeper dashboard, price alerts, favourites:** not built. The spec's later phases.
- **Refresh policy:** the spec suggests daily refreshes. Right now refresh is manual, to avoid background battery and data use. Scheduled refresh needs Android work and your approval.

## 7. Files

Added:
- `mobile/lib/core/market/bullion_feed.dart`: pure parsing, merging, freshness, per-gram conversion.
- `mobile/lib/core/market/bullion_repository.dart`: fetch, retry, merge, store, sync state.
- `mobile/lib/features/market/live_market_screen.dart`: the Live Market screen.
- `docs/LIVE_MARKET_AUDIT.md`: this file.

Changed:
- `mobile/lib/app/router.dart`: adds the `/market` route.
- `mobile/lib/features/services/services_screen.dart`: adds the "Market prices" section.

## 8. Tests

- `scratch_market/check.dart` (outside the repo) runs the parser against the real snapdata responses saved as fixtures. It checks values, dates, status, missing days, the unit conversion, duplicate-free merging, the newer-fetch-wins rule, freshness, and rejection of bad rows. All checks pass.
- Flutter widget tests are not run here, because Developer Mode is needed for plugin builds on this machine.
