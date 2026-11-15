# Rental listing screen

## Home overview total count — 2026-11-15

The Home stat formerly used `model.items.count`, so it rose by 20 whenever a user loaded another page. Home now displays `ListingsModel.serverTotalCount`, populated from the real `ListingPage.totalNumber` envelope on each successful authenticated table page. It appears on page one without loading every page and is cleared on invalidation, job change and session expiry. Before a successful response it shows “—” rather than inventing zero; the other two Home metrics and all pagination continue unchanged.

**Scope:** The installed Fredy v31 `totalNumber` counts all rows returned by the table endpoint, including non-rental deal types. The app displays only `dealType == "rent"` rows; this total must therefore be labelled **"إجمالي النتائج"** rather than claimed to be a verified rent-only total. The per-screen count of actually displayed/filtered rentals remains a separate measure. No server API, hidden extra paging or aggregation of job counters was invented. New offline source-contract coverage was added; native iPhone rendering and authenticated page-total agreement still require testing.

The original listing-stage evidence below is retained. Current additions are documented in `docs/ADD_SEARCH.md`: optional `job_id`/`job_name`, exact job-id table filter, conservative URL-area chips, shared server active counts and page/filter generation guards. The latest readonly audit found 52 visible/active rows, not the historical 51 below. No hardcoded count or listing fixtures are used.

## Current Fredy contract, inspected read-only

- `GET /api/listings/table?page=1&pageSize=20` uses the authenticated login session. The envelope is `{totalNumber: Int, page: Int, result: [...], availableProviders: [...]}`; the client ignores unused providers. There is no `hasMore` field. Pages start at 1; the server permits sizes up to 1000 and defaults to 50.
- The installed table route selects listing columns plus `dealType` from the owning job. Exact decoded fields: `id`, `title`, `price`, `currency`, `address`, `size`, `rooms`, `dealType`. No `coldRent`, `warmRent`, `livingSpace`, `numberOfRooms` or independent `city` field is assumed.
- The screen displays the server's `address` under “City / address as provided”, without inventing a normalized city or geocoding. Missing/blank/malformed optional text/numbers display “Not available”; missing title gets a generic untitled label. Numbers accept JSON numbers or invariant numeric strings, reject negative/nonfinite values and do not interpret locale-formatted money strings. IDs and the page envelope are required; broken identity/envelopes produce an error, not fake UUIDs/empty-success.
- `dealType == "rent"` is filtered on the client. The installed public filter normalizer has no general deal-type filter; no invented parameter or hardcoded job ID is sent. Rows with missing/unknown deal type are not labelled rentals. `totalNumber` counts all server rows, not only rentals; the UI shows only the loaded rental count.
- EUR prices are formatted only when the row explicitly declares `currency == "EUR"`. Other/missing currency shows unavailable under the EUR label; there is no invented conversion, zero fallback or assumption about warm/cold rent. Area uses `size` in m² and rooms uses `rooms`, including fractional values.

A read-only SQLite type/count audit (`readonly`, `fileMustExist`, `query_only`) found 51 non-hidden rows, all rental/EUR, and string title/address/currency/dealType plus numeric price/size/rooms in this snapshot. No stored listing values/IDs, images, raw responses or fixtures entered Git or Graphify. This was a local schema/data-shape check, not a fresh authenticated REST or native client test. A live unauthenticated table GET returned HTTP 401.

## Same-session networking and expiry

`LoginModel` retains the existing `FredyAuthService` behind a combined client protocol. The listing view receives that exact object; it creates neither a second URLSession nor an AsyncImage. Login, user probe, listing pages and images share the original ephemeral cookie jar, default TLS and `User-Agent: fredy-ios/1.0`. No manual Cookie/Bearer header, shared jar, disk cache or stored credentials.

An authenticated read requires previously verified login. HTTP 401 invalidates the local session, clears cookies and increments a session generation. In-flight reads check their captured generation and cancellation before exposing results, so an old response cannot clear a later login's cookies or populate its content. 403 is an access/edge failure, not automatically classified as expiry; 429/server/network/invalid data have bounded messages without raw errors.

A 401 from either a page or image shows the session-expired screen, clears loaded rows and the image cache, and offers return to login. Reauthentication is explicit; there is no polling, background renewal or persistent session restore. Cached data can remain visible until a request detects expiry. A return-to-login action is not a server logout feature.

## Pagination and UI lifecycle

- Load the first page only after verified authentication, using `.task`. Native List rows show the requested fields and image.
- Load more explicitly, one request at a time, retaining rows on later-page errors and retrying the same page. Append unique server IDs only; do not synthesize records or treat filtered rental count as raw page progress.
- Stop using the server total/page size (overflow-safe division), or an empty raw result. Validate the returned page number. A page containing no rentals can still have a Load More action; only show full empty state when no pages remain.
- Pull-to-refresh restarts at page 1. Cancel view-owned tasks on disappearance; cancellation is not shown as an API failure. Expiry is terminal for that screen and late completions cannot restore rows. Offset pagination remains subject to concurrent server inserts/removals; deduplication prevents duplicate rows, not snapshot consistency.

## Authenticated main images

- Request `GET /api/listings/{id}/image` with the same client/cookies, `Accept: image/*`, and a strictly validated nanoid path segment. Never fetch `image_url` or a provider URL directly.
- Accept only successful image MIME bodies, nonempty and at most 8 MiB **after download**; this is not a streaming transfer limit. ImageIO creates a single thumbnail capped at 640 px. A per-screen memory-only NSCache is bounded by 40 entries/16 MiB cost and cleared on expiry. No image files, fixtures or disk persistence.
- Loading and bounded failure placeholders have an explicit retry; one broken image does not fail the list. WebP/other ImageIO decoding and scrolling behavior require iOS runtime verification.
- Fredy's image route returns stored bytes when available. For an uncached picture it can queue server preview capture and return 302 to the provider. The existing client rejects all redirects, including for images: no provider follow or cookie forwarding; show an image failure/retry instead. A later explicit retry may get Fredy's stored bytes. Normal GET side effects belong to Fredy's existing endpoint behavior; no capture jobs or image backfill were triggered by development tools in this task.

## Verification and remaining acceptance checks

Oracle ran six Python checks: three new listing source contracts, two login source contracts and one project/syntax/localization check over 14 Swift files. Source checks were observed red before implementation and green afterwards. They inspect source, not Swift execution, decoding or URLSession behavior. No mocks, hardcoded listings or real-data fixtures were added. The public-scope check also passes.

Swift/Xcode/Apple SDKs are unavailable on this host. Still required on an authorized Mac/simulator/iPhone: type-check/build; real sign-in then authenticated pages/images; 20/20/remainder pagination against current data; null/malformed optional values using isolated tests; rental filtering with non-rental pages; empty state; offline/later-page retry; duplicate taps; image redirect/404/invalid bytes/WebP; HTTP 401 from a page/image; cancellation and re-login while older requests complete; RTL, Dynamic Type, dark mode and VoiceOver. Do not expose credentials/cookies or intentionally exhaust live rate limits. No IPA or jobs/searches/backend/Cloudflare changes are part of this stage.
