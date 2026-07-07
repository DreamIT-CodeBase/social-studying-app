# Project Memory — AI Study App (Social Study App)

> **Aggregated knowledge dump** for handoff to a teammate on a different machine /
> different AI CLI. This consolidates everything from the original author's local
> Claude Code memory (16 files) plus the live state as of **2026-06-04**.
>
> Pairs with: `ONBOARDING.md` (quick start), `knowledge.md` (architecture/schema
> canon), `CLAUDE.md` + `.claude/rules/*` (ethos & per-stack rules).
>
> **SECRETS POLICY — read this.** This file contains **no secret values** by
> design. Connection strings, API keys, and the FCM private key live in **Azure
> Key Vault** (`kv-ssa-dev-ddjopeut37ed2`) and must never be copied into a file
> that can be committed or synced. §2 lists the secret *names* and the commands to
> retrieve them. Identifiers that are NOT secret (tenant GUID, app client ID,
> resource names, subscription ID) are included because they're already in
> committed Bicep params.

---

## 1. Infrastructure — identifiers & topology

| Thing | Value |
|---|---|
| Azure subscription | `Azure subscription 1` — `7697a402-d399-4569-b15a-91c6adf38388` |
| Resource group (dev) | `rg-ssa2-dev` |
| Region | `centralus` (Central US) |
| **Shared resource seed** | `ddjopeut37ed2` (hardcoded across all bicep modules) |
| Tenant name param | `ssa2` (→ RG `rg-ssa2-dev`) |
| ACR | `acrssadevddjopeut37ed2.azurecr.io`, image repo `social-study-api` |
| Key Vault | `kv-ssa-dev-ddjopeut37ed2` |
| API container app | `ca-api-dev` (also runs the notification scheduler endpoint) |
| Worker apps | `ca-worker-dev`, `ca-topic-extractor-dev`, `ca-chunker-dev`, `ca-vectorizer-dev` |
| API URL | https://ca-api-dev.ambitiouswave-1e406ff3.centralus.azurecontainerapps.io |
| Notification Hub | namespace `nh-ns-ssa-dev-ddjopeut37ed2`, hub `study-app-dev` |
| Document Intelligence | `di-ssa-dev-cm` (S0, centralus), `prebuilt-read`, kind `FormRecognizer` |

**Seed decision (2026-05-08):** after a tenant-switch left orphan resources, the
project nuked + redeployed. All 10 bicep modules use the literal seed
`ddjopeut37ed2` (was `uniqueString(resourceGroup().id)`) so resource names stay
stable across RG recreations. **New bicep modules MUST use this literal, not
`uniqueString`.** New environments (staging/prod) pick their own literal seed.

**Container topology:** all 5 container apps run the **same image**; workers
differ only by command override (`python -m app.workers.<name>`). KEDA
`azure-servicebus` scalers watch queue depth (scale 0→3 dev, 1→10 prod).

---

## 2. Secrets — inventory & retrieval (NO values here)

Secrets live in Key Vault `kv-ssa-dev-ddjopeut37ed2`. `deploy.sh` reads them to
generate `backend/.env.dev` (gitignored). To get them on a new machine:

```bash
az login
az account set --subscription 7697a402-d399-4569-b15a-91c6adf38388
# Regenerate backend/.env.dev from Key Vault + deployment outputs:
cd infra/scripts && ./deploy.sh dev --infra-only   # writes backend/.env.<env>
# Or pull one secret directly:
az keyvault secret show --vault-name kv-ssa-dev-ddjopeut37ed2 --name <secret-name> --query value -o tsv
```

Key Vault secret names:
`cosmos-connection-string`, `redis-connection-string`,
`service-bus-connection-string`, `azure-openai-key`, `ai-search-key`,
`content-safety-key`, `storage-connection-string`,
`document-intelligence-key`, `notification-hub-connection-string`.

**Not in Key Vault, set up out-of-band:**
- **FCM v1 service-account JSON** — in Firebase console (Project settings →
  Service accounts → Generate new private key). Pasted into the Notification Hub's
  Google (FCM v1) blade. The original author is keeping their copy locally; a new
  dev regenerates their own from the Firebase console. NEVER commit it.
- **`flutter_app/android/app/google-services.json`** — gitignored; re-download
  from Firebase console.
- **Entra External ID (B2C) identifiers** — see §3; stored in
  `infra/environments/dev/params.json` (committed) + `.env.dev`.

---

## 3. Authentication — Microsoft Entra External ID (CIAM), NOT classic B2C

The code/config says "B2C" but the real provider is **Microsoft Entra External ID
for customers (CIAM)**. Pivoted 2026-05-07 because Microsoft restricted new Azure
AD B2C tenant creation (2025-05-01) — a fresh subscription can't make B2C tenants.
Treat `b2c_*` as a **legacy variable prefix**, not a product choice.

**Dev tenant values (identifiers, not secrets):**
- tenant subdomain `socialstudyingapp`
- tenant GUID `cbf2e3d3-af81-40dd-a396-aae11d2c6b3f`
- app client ID `93e3ce50-a29e-462b-8956-85674a34d167`
- custom attribute `TenantId`, emitted in tokens as `extension_TenantId`

**Hard-won CIAM rules:**
- **JWKS URL**: `https://{guid}.ciamlogin.com/{tenant_guid}/discovery/v2.0/keys` —
  NOT the legacy `{tenant}.b2clogin.com/...`. Fixed in `backend/app/core/auth.py`
  `_jwks_url()`. Using the GUID as subdomain matches the token's `iss` host.
- **Authority** (MSAL): `https://{subdomain}.ciamlogin.com/{tenant_guid}` — no
  `.onmicrosoft.com`, no policy in path.
- **Custom claims**: stored in the auto-created `b2c-extensions-app`, emitted as
  `extension_<appId-no-hyphens>_<name>` by default. For a clean claim name you
  MUST (1) map it under Enterprise App → SSO → Attributes & Claims AND (2) set
  `acceptMappedClaims: true` in the app manifest — without (2) the mapping is
  silently ignored.
- **No implicit flow** in CIAM regardless of toggles — only auth code + PKCE.
- **Redirect URI platform matters**: a URI registered as **Single-page
  application** can't be used by native/desktop clients (throws AADSTS9002327).
  Use **Mobile and desktop applications** for `http://localhost` / native loopback.
- **Apple Sign-In** is not a built-in IdP — configure as generic OIDC with a
  JWT client secret that rotates ≤6 months. Deferred; MVP ships email + Google.
- **Bicep wiring**: `b2cTenantId` + `b2cClientId` must be in BOTH `.env.dev` AND
  `infra/environments/dev/params.json`, or container apps deploy with empty env
  vars and every auth call DNS-fails. `deploy.sh` preserves the B2C block in
  `.env.dev` across regenerations (Sprint 1.5 is portal-only, not in bicep).

**OPEN TECH DEBT — auth bootstrap gap:** `POST /auth/register-completion` (from
the Sprint 1 plan) was never implemented. Auth middleware requires an existing
`users` row keyed by the JWT `sub` (b2c_object_id) before any authenticated
endpoint resolves — a fresh sign-in can't bootstrap itself. Dev workaround:
`backend/scripts/bootstrap_admin_user.py` writes a Tenant + tenant_admin User
directly to Cosmos and busts the Redis cache. **Real fix still pending.**

---

## 4. Document ingestion pipeline (Sprint 2) — per-stage decisions

Flow: `upload → extract text → content safety → topic extraction → taxonomy
merge → dependency inference → chunking → vectorization → ready`. Four async
Container App workers + two inline AI stages. Status enum lives in
`DocumentStatus`. Every worker classifies errors **permanent** (dead-letter) vs
**transient** (Service Bus redeliver up to maxDeliveryCount).

**2.1 Document Intelligence:** `prebuilt-read` only (text+OCR, ~$1.5/1k pages vs
~$10 for layout). Key-based auth. SDK `azure-ai-documentintelligence` (NOT
deprecated `azure-ai-formrecognizer`). **PDF works; DOCX does NOT** with
prebuilt-read — route DOCX through `python-docx` or use `prebuilt-layout` for
Office formats, or drop DOCX in v1. PDFs + images are the safe path.

**2.3 Text extraction worker** (`ca-worker-dev`, `app.workers.document_ingestion`):
reuses the `document-ingestion` SB queue (5-min lock, maxDelivery=5). Extracted
text → Blob at `{tenant}/{workspace}/extracted-text/{doc}.txt` (Cosmos holds path
+ counts, not full text — avoids 2 MB doc limit). Auth via connection strings
(NOT managed identity) because KEDA `azure-servicebus` trigger doesn't support MI.
Permanent errors: DI `UnsupportedContent`/`InvalidContent`, blob not-found.

**2.4 Content safety** — INLINE in the 2.3 worker (one ~200ms call, no separate
worker). Terminal state `flagged`. Educational-lenient thresholds: Hate/SelfHarm/
Sexual ≥2 flag, Violence ≥4 (historical war content shouldn't trip). Text blob
written even when flagged (admins review it). `moderation_log` writes are
best-effort. Chunks at 9,500 chars (10K API limit), aggregates MAX severity. SDK
category keys are capitalized: "Hate","SelfHarm","Sexual","Violence". ID prefix
`mod_`. Transient HttpResponseError propagates so SB redelivers (don't let a doc
past the gate on a scanner hiccup).

**2.5 Topic extraction** (`ca-topic-extractor-dev`, `app.workers.topic_extraction`):
separate worker, new `topic-extraction` queue (10-min lock — GPT-4o is slow,
maxDelivery=3 — model calls expensive). GPT-4o JSON mode. Handoff from 2.3 is
best-effort. States `extracting_topics → topics_extracted`. Prompts in
`backend/app/prompts/*_v1.txt` with `[SYSTEM]`/`[USER]` markers (NOT
`mcp-server/prompts/`). **`app/services/azure_openai.py` is the single seam for
ALL GPT-4o calls** — `AsyncAzureOpenAI`, API version `2024-10-21`, helper
`chat_json(...)` always sets `response_format=json_object`, temp 0.2 default
(stable output for merge idempotency). Front-truncates docs >60K chars (TOCs/
headings up front are gold).

**2.6 Taxonomy merge** — INLINE in topic worker. Builds workspace-level
`CanonicalTopic` rows (`tpc_<uuid>`, name, aliases, description, complexity,
parent_id, source_document_ids) on `Workspace.taxonomy`. First-doc seeds 1:1
(skips AI). Subsequent docs: one GPT-4o merge call. **Optimistic concurrency** via
`taxonomy_version` compare-and-swap, 3 retries. Model uses literal `"NEW"`
sentinel for new topics/ids; service replaces with real uuids. Best-effort (doc
advances even if merge fails). Per-doc TopicTags NOT rewritten with canonical ids
(deferred to 2.9).

**2.7 Dependency inference** — INLINE after merge, eager every upload. **TREE
shape (single `parent_id`), not DAG** (demo-phase choice). Runs only if merge
succeeded + ≥2 topics. Same CAS pattern (reads workspace fresh). Conservative
prompt (prefer null over weak prereq). `_sanitize_edges`: drop self-refs, unknown
ids, cycle-closing edges (DFS, sorted-id order for deterministic drops).

**2.8 Chunking** (`ca-chunker-dev`, `app.workers.chunking`): separate worker, new
`chunking` queue (5-min lock, maxDelivery=5). **Character-based recursive split**
(no tokenizer dep): paragraph → newline → sentence → clause → word → hard cut.
2000 chars target (~500 tok), 200 overlap, 200 min. Dedicated `chunks` Cosmos
collection (partition key `document_id`) — not inline (embeddings would blow 2 MB
limit). Atomic replace = delete-all-then-insert per document_id. `chunker_version:
"v1"` on every row. Ships `topic_ids: []` (resolution deferred to 2.9).

**2.9 Vectorization** (`ca-vectorizer-dev`, `app.workers.vectorization`): separate
worker, `vectorization` queue (10-min lock, maxDelivery=3). **text-embedding-3-small
(1536 dims)** — `-large` is 6x cost. **Per-tenant AI Search index**
`chunks-{sanitized tenant_id}` (lowercase, `_`→`-`). Resolves canonical topic_ids
here by reading workspace taxonomy once (name+alias → tpc_id). Re-vectorize =
delete-then-upsert (no delete-by-filter in Search). Embedding batched at 16/call.
Index dim locked at create time — switching model requires recreating every index.

**2.14 Integration tests** (`backend/tests/integration/test_ingestion_pipeline.py`):
wires all 4 workers with in-memory fakes. Patterns: stage messages round-trip
`to_json`/`from_json` at fake-queue boundaries; `_FakeCollection.status_history`
asserts the full ordered status sequence; patch `get_collection` at EVERY import
callsite; OpenAI prompt discrimination by unique JSON output key (not free text,
since multiple prompts mention "prerequisite").

---

## 5. AI question generation & adaptive learning (Sprint 3)

Two-layer: deterministic topic/difficulty selection (Layer 1) + GPT-4o content
generation (Layer 2 via MCP tools). Endpoints: `POST /questions/next`,
`/questions/{id}/answer`, `/flashcards/next`, `/flashcards/{id}/rate`. Prefetch
worker generates the next question in-process after an answer.

**Smoke test** `backend/scripts/smoke_test_sprint3.py` drives the full pipeline
against real Azure (invokes route handlers directly, no HTTP/JWT). Default target:
tenant `ten_smoke001`, workspace `wsp_273810a8de2a4e9182f4ac885b9c5a16`, doc
`doc_ddd0104573164a48954d8346a64f6e48`. Run it after any Sprint 3 change.

**Bug it caught:** `azure-search-documents 11.7.0b2` renamed
`VectorizedQuery.k_nearest_neighbors` → `k`; the SDK silently dropped the old name
and over-fetched. Fixed in `backend/app/services/azure_ai_search.py`.

---

## 6. Gamification / Notifications / Analytics (Sprint 5) — incl. live FCM state

Gamification engine + API, analytics endpoints, notification service + scheduler,
token registration, skip endpoint. New Cosmos collections auto-create on first
write: `notification_tokens`, `notification_dispatches`, `gamification`.

### Push notifications — FCM v1 (DEPLOYED & LIVE as of 2026-06-04)

**The doc `docs/notifications-setup.md` is STALE — do not follow its FCM steps.**
Google retired FCM legacy HTTP + server keys 2024-06-20; a Firebase project made
now only issues **FCM v1** service-account JSON (no legacy "Server key"). Canonical
contract: https://learn.microsoft.com/en-us/azure/notification-hubs/firebase-migration-rest

Done & verified:
- Firebase project created; Android app package `com.socialstudyapp.social_study_app`
  (the real `applicationId` — the doc's `com.stephens.socialstudyapp` is WRONG).
  No Android product flavors → one Firebase app + one `google-services.json`
  covers admin + student.
- `google-services` Gradle plugin 4.4.2 wired (`settings.gradle.kts` +
  `app/build.gradle.kts`); `Firebase.initializeApp()` auto-inits (no
  `firebase_options.dart`). `minSdk` 21→23 (firebase-messaging requirement).
- **Backend sender on FCM v1** (`backend/app/services/notifications.py`, commit
  `72d282e`): format header `gcm`→`fcmV1` (exact casing), payload wrapped in
  top-level `{"message":{"notification":{...},"data":{...}}}`, direct-send
  api-version `2015-01`→`2015-04`, data stays flat string→string, no token/topic
  (ANH injects via `ServiceBusNotification-DeviceHandle`). 41 tests pass.
- Image `social-study-api:72d282e` deployed; API revision `ca-api-dev--0000016`
  active/healthy on that tag. FCM v1 credential pasted into the hub.
- Sender auto-selects: `AzureNotificationHubSender` when
  `NOTIFICATION_HUB_CONNECTION_STRING` is set, else `LoggingSender` (no-op, logs).

**NEXT TASK — prove the device push (only unproven link):**
1. `cd flutter_app && flutter run --flavor student -t lib/main_student.dart` on a
   device/emulator (run `dart run build_runner build` first if codegen stale).
2. Confirm token registers via `POST /api/v1/users/me/notification-tokens`.
3. Trigger a milestone (answer to level up, or `POST /api/v1/admin/notifications/run-scheduler`).
4. Watch `notification_dispatches` Cosmos collection for `outcome=sent`.

**APNs/iOS** deferred to the store-submission sprint.

---

## 7. Operational gotchas & lessons (these have bitten the project)

**Deploy `:latest` no-op trap (FIXED `e30010f`, but know the shape):** Container
Apps compares the `--image` STRING (not digest) for revisions. `az containerapp
update --image …:latest` after pushing a fresh `:latest` is a **no-op** — new
image sits in ACR, no new revision, stale code keeps running. `deploy.sh` now
deploys the unique commit-SHA tag. If a deploy "succeeds" but behavior is
unchanged, check the active revision's image tag:
`az containerapp revision list -g rg-ssa2-dev -n ca-api-dev`.

**In-memory test fakes hide infra/config bugs.** The first real-Azure run of the
Sprint 2 pipeline (2026-05-19) surfaced **10 latent bugs** that 693 passing tests
didn't catch: container port mismatch (→8080), Service Bus `lockDuration>5min`
silently failing queue deploys, missing `pydantic[email]`/`aiohttp` deps in the
Docker image, JWKS on wrong host, empty B2C params, no register-completion
endpoint, OpenAI deployments with 0 capacity (404 DeploymentNotFound — embedding
needed `GlobalStandard` not `Standard` for quota in centralus), Cosmos rejecting
`.sort()` without an index (→ client-side sort), and `--infra-only` resetting
container apps to the helloworld placeholder image. **Always run a real
end-to-end test against deployed Azure before calling a sprint done.**

**Other gotchas:**
- Cosmos MongoDB API: index-on-sort-field enforced; collections only have `_id`
  indexed → sort client-side or add an index.
- CIAM access tokens last ~75 min; a full `deploy.sh` can outlive one — re-auth
  smoke scripts.
- `--infra-only` may reset container app images to the bicep default placeholder;
  follow with `--app-only` (the [[first_real_azure_run_findings]] item #10 — verify
  current bicep default before trusting this is still true).

---

## 8. Conventions (quick reference)

- **IDs**: `str(uuid4())` prefixed — `usr_`, `wsp_`, `ten_`, `doc_`, `qst_`,
  `tpc_`, `chk_`, `mod_`, `ntk_` (notification token), `nd_` (dispatch).
- **Cosmos**: one DB per tenant (`tenant_{id}`); always pass partition key;
  `replace_one` not `update_one`; soft-delete (`deleted_at`); ISO 8601 UTC strings.
- **Prompts**: `backend/app/prompts/<name>_v<n>.txt`, `[SYSTEM]`/`[USER]` markers,
  `# vX.Y — date — desc` first line, `{{double_braces}}` vars. Bump version on
  schema change; never edit shipped prompts in place.
- **Workers**: `backend/app/workers/`, same image, separate Container App each,
  own queue + status arc, permanent-vs-transient error classification.
- **OpenAI**: only through `app/services/azure_openai.py` (`chat_json`,
  `embed_texts`). Don't roll your own client.
- **gstack**: `/browse` for ALL web browsing (never raw chrome MCP). `/review`
  before merge, `/qa`, `/investigate`, `/cso`, `/ship`. Full list in `CLAUDE.md`.

---

## 9. Open items / known tech debt

1. **Prove the FCM device push** (§6) — immediate next step.
2. **Auth bootstrap**: implement `POST /auth/register-completion` (§3) — currently
   scripted via `bootstrap_admin_user.py`.
3. **Stale doc**: `docs/notifications-setup.md` has obsolete FCM legacy steps +
   wrong package name. This file + the code are correct; that doc isn't.
4. **DOCX ingestion** unsupported by `prebuilt-read` (§4 / 2.1).
5. **Queue-file duplication**: 4 near-identical SB queue modules; refactor when a
   5th appears.
6. **Sprint 6 launch tail**: E2E journeys (6.1/6.2), perf (6.3), COPPA (6.4),
   `/cso` security audit (6.5), offline support (6.8), monitoring (6.11), app
   store submission (6.12), retro (6.15).
7. **iOS/APNs** wiring for store submission.
8. **DAG taxonomy** migration if single-parent tree proves too limiting (§4 / 2.7).
