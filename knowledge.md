# AI Study App — Project Knowledge Base

> This document captures every architectural decision, system design, schema definition, and implementation detail agreed upon during the initial planning session. It serves as the canonical knowledge source for Claude Code when working on this project.

---

## 1. What This App Is

An AI-powered multi-tenant study app for the US market. It generates personalized questions and flash cards from admin-uploaded study materials, adapting to each student's knowledge state over time. Two equally important user segments: **families** (parent + child) and **educational institutions** (teacher + students). The app is built with Flutter (single codebase, two flavors), a Python FastAPI backend, and Azure cloud services.

---

## 2. Tech Stack (Decided)

| Layer | Technology | Notes |
|---|---|---|
| Mobile Apps | Flutter 3.x / Dart | Single codebase, admin + student flavors |
| State Management | Riverpod 2.x | @riverpod annotation with code generation |
| Navigation | GoRouter | Typed route parameters, auth guards |
| HTTP Client | Dio | Auth interceptor, error interceptor, logging interceptor |
| Models (Frontend) | Freezed + json_serializable | Immutable data classes matching backend schemas |
| Backend API | Python 3.12, FastAPI | Hosted on Azure Container Apps |
| Database | Azure Cosmos DB (MongoDB API) | One database per tenant, one collection per domain |
| Vector Store | Azure AI Search | Chunked document embeddings with metadata filters |
| AI Model | Azure AI Foundry (GPT-4o) | Question generation, topic extraction, taxonomy inference |
| AI Orchestration | Custom MCP Server | Python, containerized, internal-only networking |
| Document Processing | Azure Document Intelligence | OCR for images, text extraction for PDFs/Word |
| Authentication | Azure AD B2C (Microsoft Entra External ID) | Social providers: Apple, Google, email/password |
| Content Safety | Azure AI Content Safety | Two threshold profiles: strict for AI output, lenient for uploads |
| Caching | Azure Cache for Redis | User profiles, knowledge states, leaderboards |
| Async Processing | Azure Functions + Azure Service Bus | Document ingestion, status recalculation, taxonomy regen |
| Push Notifications | Azure Notification Hubs + Firebase Cloud Messaging | Cross-platform (iOS + Android) |

---

## 3. Builder Ethos (gstack)

This project follows the gstack methodology. These are enforced by Claude Code config, not aspirational.

**Boil the Lake**: The marginal cost of completeness is near-zero with AI assistance. Always do the complete implementation. Tests ship with code. Every screen handles loading, error, empty, and success states. No shortcuts.

**Search Before Building**: Three layers of knowledge — (1) tried and true, (2) new and popular (scrutinize), (3) first principles (prize above all). Check if something already solves your problem before building from scratch.

**Anti-Slop Mandate**: No placeholder code, no generic variable names, no copy-paste without understanding, no TODO comments that defer real work. Every function earns its existence. The code-reviewer agent blocks slop before it merges.

**Confusion Protocol**: When you encounter architectural ambiguity — STOP. Do not guess. Ask the human. Wrong assumptions compound into wrong architecture.

---

## 4. Multi-Tenancy Architecture

### Hierarchy
- **Tenant** = top level (a school, a tutoring company, or a family)
- **Workspace** = inside a tenant (a class, a subject, or a study group)
- **User** = belongs to one tenant, can be in multiple workspaces within that tenant

### Isolation
- Each tenant gets its own Cosmos DB database named `tenant_{tenant_id}`
- Each workspace maps to collections within that database
- Cross-tenant data access is architecturally impossible, not just permission-gated

### Roles (4 roles, not 2)
1. **Tenant Admin** — full control within the tenant: create/delete workspaces, manage all users, configure tenant-level settings, view all analytics
2. **Workspace Admin** — manage a specific workspace: add/remove students, upload content, set question frequency, configure milestones, view student progress
3. **Student** — interact with learning features within assigned workspaces: answer questions, review flash cards, view own progress
4. **Tenant Member (no workspace)** — transitional state, user added to tenant but not yet assigned to any workspace

---

## 5. Authentication & Authorization

### Service: Azure AD B2C (Microsoft Entra External ID)
- Social providers: Sign in with Apple (mandatory for iOS), Google, email/password
- Supports age-gating and parental consent workflows (COPPA)
- Issues JWT access tokens containing user's unique object ID

### Token Flow
1. Flutter app redirects to Azure AD B2C login
2. User authenticates (Apple, Google, or email)
3. AD B2C issues JWT access token
4. App sends token with every API request
5. Backend validates JWT signature, extracts user object ID
6. Backend looks up tenant/workspace/role from Cosmos DB (cached in Redis, 5-min TTL)
7. RBAC middleware checks role against endpoint requirements

### Role/Hierarchy Storage
- Stored in Cosmos DB `users` collection (not in AD B2C custom attributes)
- Each user document contains: AD B2C object ID, tenant-level role, array of workspace memberships with per-workspace roles

### Two Onboarding Flows (both equally important)
**Family use case**: Parent signs up → becomes tenant admin → creates child accounts directly (possibly without email for younger children, COPPA) → child gets simplified login (PIN or device-based session)

**School use case**: Teacher signs up → creates tenant + workspaces → generates invite codes per workspace → distributes codes to students → students self-enroll by entering code after signup

### API Paths for Adding Users
- **Direct creation**: admin creates user object (family mode)
- **Invite code redemption**: user creates own account and joins via code (school mode)
- Both produce the same user document in the same collection

### Device Sessions
- Long-lived refresh tokens for children's devices (parent unlocks once)
- Parent can revoke access remotely from admin view

---

## 6. Cosmos DB Schema

Each tenant database (`tenant_{tenant_id}`) contains these collections:

### users (partition key: user_id)
- Azure AD B2C object ID
- Tenant-level role (tenant_admin | member)
- Array of workspace memberships [{workspace_id, role: workspace_admin | student}]
- Profile: display_name, age/grade, avatar
- Metadata: created_at, last_login, soft_deleted

### workspaces (partition key: workspace_id)
- Name, description
- Settings: question_frequency, moderation_thresholds, gamification_config (daily_goal, leaderboard_visibility)
- Dynamic taxonomy object: topic tree, dependency graph, per-topic metadata
- Milestone definitions
- Invite code configurations

### documents (partition key: workspace_id)
- Original filename, file_type
- Azure Blob Storage URL (raw file)
- Processing status: queued | extracting | analyzing | vectorizing | ready | flagged | failed
- Extracted text reference
- Topic tags (generated during ingestion)
- Moderation results
- Upload metadata: uploader_id, uploaded_at, file_size

### knowledge_states (partition key: user_id)
- Per-topic: mastery_score (0–100), recency_score, difficulty_ceiling (easy/medium/hard)
- Per-topic per-difficulty: attempt_count, success_rate
- Streak data
- Last updated timestamp
- This is the PRECOMPUTED SUMMARY — the adaptive learning engine reads this, never scans full history

### interactions (partition key: user_id, composite with timestamp)
- Append-only event log
- Per event: question_id/flashcard_id, student_response, correctness, difficulty, topic, time_taken, timestamp, xp_awarded
- Source of truth for recomputing knowledge_states

### gamification (partition key: user_id)
- Total XP, per-topic XP
- Current level
- Current streak count, longest streak
- Streak maintenance log (daily)
- Earned badges with timestamps
- Daily activity summary

### moderation_log (partition key: workspace_id)
- Content reference (not full text)
- Source: upload | ai_generated
- Azure Content Safety verdict + severity scores
- Resolution: auto_approved | auto_rejected | admin_reviewed
- Resolver admin ID (if applicable)

### question_queue (partition key: user_id)
- Pre-generated questions for prefetching
- Topic, difficulty, format, expiry timestamp

### ID Convention
All IDs use `str(uuid4())` prefixed with entity type: `usr_`, `wsp_`, `ten_`, `doc_`, `qst_`

### Timestamps
All timestamps as ISO 8601 UTC strings

### Deletion
Soft delete only — set `deleted_at` timestamp, never remove documents

---

## 7. Document Ingestion Pipeline

### Input Formats
Images, PDFs, Word documents, plain text files

### Processing Flow
1. **Upload**: File stored in Azure Blob Storage, document record created in Cosmos DB with status "processing", queued for async processing
2. **Text Extraction**: Azure Document Intelligence — OCR for images, text extraction for PDFs (if image-oriented PDF, use OCR), text extraction for Word, plain text pass-through
3. **Content Safety Scan**: Azure Content Safety scans extracted text (and images separately). Educational content thresholds are slightly more permissive than social media (History docs about war may flag for violence). Flagged content is quarantined, admin notified.
4. **Semi-Structured Conversion**: Extracted content converted to JSON format
5. **Metadata Enrichment**: AI generates document-level metadata — doc name, language, content length, AI-generated summary
6. **Topic Extraction** (AI): AI reads full document, produces structured JSON — list of topics with hierarchy, descriptions, complexity levels, and references to specific chunks
7. **Taxonomy Merge** (AI): Second AI call merges new topics into existing workspace taxonomy, resolving naming differences and overlaps. Result stored as workspace-level taxonomy document.
8. **Dependency Graph Inference** (AI): AI analyzes taxonomy and content to infer prerequisite relationships between topics. Conservative — only flag genuine prerequisites.
9. **Smart Chunking**: Context-preserving, overlapping, flexible-length chunks. Each chunk tagged with topic metadata.
10. **Store in Cosmos DB**: Document object with metadata pushed to documents collection
11. **Vectorize to Azure AI Search**: Chunks pushed to vector store with proper index schema and metadata filters

### Taxonomy Merge Across Documents
Two-pass approach:
1. Extract topics from new document independently
2. AI receives existing taxonomy + new topics, produces merged taxonomy (identifies overlaps, resolves naming, inserts into hierarchy)

### When Taxonomy Updates, Student Data Must Follow
If "Plant Energy" gets merged with "Photosynthesis" from a second document, student mastery data for "Plant Energy" carries over to the merged topic.

### Performance
Document ingestion is NOT instant (30 seconds to minutes). UX must show processing state. Processing happens async via Azure Functions.

### Admin Override
Admin can see and edit the generated taxonomy — rename topics, merge/split, add/remove dependencies, adjust complexity. Admin overrides are stored alongside AI-generated taxonomy.

### Ideal Status / Curriculum Configuration
Freeform — admin uploads documents, system infers topics dynamically. Admin sets broad goals ("master all topics to 80% by June 15th"), system auto-computes per-topic targets and pacing. Admin can drill in and adjust individual topics if desired.

---

## 8. Adaptive Learning Engine

### Two-Layer Architecture

**Layer 1: Learning Path Engine (deterministic, rule-based)** — decides WHAT topic and WHAT difficulty. Fast, predictable, debuggable.

**Layer 2: Content Generation Engine (AI-powered)** — given a topic + difficulty, retrieves content and generates a question. Uses MCP server, Azure AI Search, AI model.

### Layer 1: Topic Selection Algorithm

Three inputs:
1. **Student's Knowledge State** (from knowledge_states collection): per-topic mastery score, recency score, difficulty ceiling, attempt counts, success rates
2. **Target Curriculum** (from workspace config): topic list, target mastery per topic, dependencies, deadlines/milestones, priority weights
3. **Scheduling Algorithm**: modified spaced repetition with curriculum awareness

Priority scoring per topic:
- Low mastery + high target importance = highest priority
- Not reviewed recently = boost (forgetting curve)
- Approaching deadline = urgency weighting
- Already at/above target mastery = deprioritized (but not eliminated — maintenance reviews)

Then apply dependency graph: if high-priority topic has unmastered prerequisites, bump prerequisite up instead.

Then pick difficulty: target 70–75% success probability (zone of proximal development). If consistently getting medium right, start mixing in hard.

Then add variety factor: no more than 2–3 consecutive questions on the same topic.

Output: `"Generate a [medium difficulty] question about [photosynthesis] for [this student]"`

### Layer 2: Content Generation Pipeline

1. **Retrieve content**: MCP server calls Azure AI Search with topic + metadata filters
2. **Retrieve context**: Pull student's recent interaction history for this topic (prevent near-duplicate questions)
3. **Generate question**: AI model generates question with topic, difficulty, format (MCQ/long-answer/mathematical), constraints
4. **Validate**: Check well-formed, correct answer matches source material, passes content safety
5. If validation fails → silently regenerate

### Question Formats
- **MCQ**: 4 options, plausible distractors, one unambiguous correct answer
- **Long answer**: Includes rubric for AI evaluation
- **Mathematical**: Proper notation handling (LaTeX or plain text)

### Knowledge State Updates
After each interaction:
- Correct answer → mastery goes up (more for hard questions, less for easy)
- Incorrect answer → mastery goes down slightly, engine notes to revisit topic soon
- Update is synchronous (just math on a few numbers, not expensive)
- Full interaction event appended to interactions collection (source of truth)

### Prefetching
When student answers a question, immediately start generating the next one in background so it's ready.

### Flash Cards
Similar pipeline but simpler — front/back, student self-rates recall (easy/medium/hard). Self-rating feeds into knowledge state. Flash cards have higher difficulty than general questions.

---

## 9. Gamification System

### Core Loop
Every interaction earns XP. Amount varies — hard question the student struggled with = more XP than easy familiar one. Flash cards earn less XP than full questions.

### Streak System
Daily streaks maintained by completing a minimum daily goal (configurable by admin per workspace). Streak counter, longest streak tracked.

### Progression
- XP maps to levels per topic and an overall level
- Skill tree visualization — Level 5 Biology, Level 2 History, etc.

### Leaderboards
- Workspace-level only (not global — global is demotivating)
- Admin can toggle on/off
- Show display names, not real names (configurable)

### Badges/Achievements (at least 15 for launch)
Examples: "First 100 questions answered", "7-day streak", "Mastered a topic", "10 hard questions in a row"
- Visually appealing, shareable
- Stored with timestamps

### Storage
Gamification collection: denormalized for fast reads, updated async after interactions. Precomputed leaderboard object updated asynchronously.

### API Endpoints
- GET gamification profile
- GET workspace leaderboard
- GET badges (available + earned + progress toward unearned)
- GET streak details (current count, longest, whether today's minimum met)

### Activity recording
Fire-and-forget from app perspective — async queue processes XP calculation, streak updates, badge checks.

---

## 10. Content Moderation

### Two Streams + One Safety Net

**Stream 1: Admin-Uploaded Content**
- Azure Content Safety scans text + images after extraction, before storage
- Two threshold profiles: strict on hate speech, more lenient on violence (for historical content)
- Flagged content quarantined → admin notified → admin can approve (false positive) or reject
- Moderation event logged in moderation_log collection

**Stream 2: AI-Generated Content**
- Tier 1 (preventive): Prompt-level guardrails — safety instructions baked into system prompts
- Tier 2 (detective): Azure Content Safety output scan after generation, before delivery to student (~200ms)
- If flagged → silently regenerate (student never sees error)
- Monitor regeneration rate — if >5%, prompt needs fixing

**Stream 3: User-Generated Content**
- Students can upload content too — same pipeline as admin uploads
- V1 is non-social (no student-to-student communication) to simplify moderation
- If social features added later, real-time moderation on user inputs needed

### COPPA Considerations
- AI-generated content for younger students: stricter guardrails (adjust tone, vocabulary, topic sensitivity based on age/grade)
- Content involving minors flagged in inappropriate contexts = automatic hard block
- Moderation logs retained as compliance record

### Transparency
- Silent moderation for AI-generated content (student never sees "blocked" message)
- Visible moderation for uploaded content (admin sees flags and reasons)

---

## 11. API Layer

### API Prefix
All endpoints: `/api/v1/...`

### Authentication
- `POST /auth/register-completion` — post-signup profile creation, invite code redemption
- `POST /auth/invite-code/validate` — check invite code validity
- `GET /auth/me` — current user profile with roles and workspaces (reads from Redis cache)

### Tenant & Workspace Management
- `POST /tenants` — create tenant
- `GET /tenants/{tenantId}` — tenant details
- `POST /tenants/{tenantId}/workspaces` — create workspace
- `GET /tenants/{tenantId}/workspaces` — list workspaces (filtered by role)
- `PUT /workspaces/{workspaceId}/settings` — update workspace config
- `POST /workspaces/{workspaceId}/invite-codes` — generate invite code

### User Management
- `POST /workspaces/{workspaceId}/users` — add user (direct creation OR invite code redemption)
- `GET /workspaces/{workspaceId}/users` — list workspace users (role-filtered visibility)
- `PUT /workspaces/{workspaceId}/users/{userId}/role` — change role (invalidates Redis cache)
- `DELETE /workspaces/{workspaceId}/users/{userId}` — soft remove

### Documents & Taxonomy
- `POST /workspaces/{workspaceId}/documents/upload` — upload document (returns immediately, async processing)
- `GET /workspaces/{workspaceId}/documents` — list documents with processing status
- `GET /workspaces/{workspaceId}/documents/{docId}` — document details
- `GET /workspaces/{workspaceId}/documents/{docId}/status` — polling endpoint for processing progress
- `DELETE /workspaces/{workspaceId}/documents/{docId}` — soft-delete (cascading cleanup async)
- `GET /workspaces/{workspaceId}/taxonomy` — full topic tree
- `PUT /workspaces/{workspaceId}/taxonomy` — admin update (validates no circular dependencies)
- `POST /workspaces/{workspaceId}/taxonomy/regenerate` — full re-analysis (async, heavy)

### Learning & Questions
- `POST /workspaces/{workspaceId}/questions/next` — THE critical endpoint. Runs full adaptive pipeline. Target: <3s latency.
- `POST /workspaces/{workspaceId}/questions/{qId}/answer` — submit answer, evaluate, update knowledge state, return feedback + XP
- `GET /workspaces/{workspaceId}/flashcards/next` — get next flash card
- `POST /workspaces/{workspaceId}/flashcards/{fcId}/rate` — self-rate recall (easy/medium/hard)

### Gamification
- `GET /workspaces/{workspaceId}/users/{userId}/gamification` — full gamification profile
- `GET /workspaces/{workspaceId}/leaderboard` — workspace leaderboard (if enabled)
- `GET /workspaces/{workspaceId}/users/{userId}/badges` — badges + progress toward unearned
- `GET /workspaces/{workspaceId}/users/{userId}/streak` — streak details

### Analytics & Progress
- `GET /workspaces/{workspaceId}/users/{userId}/progress` — student progress across topics
- `GET /workspaces/{workspaceId}/analytics` — workspace-level aggregated analytics (admin only)
- `GET /tenants/{tenantId}/analytics` — tenant-level analytics (tenant admin only)

### Moderation
- `GET /workspaces/{workspaceId}/moderation/flagged` — flagged content awaiting review
- `PUT /workspaces/{workspaceId}/moderation/{itemId}/resolve` — approve or reject
- `GET /workspaces/{workspaceId}/moderation/log` — audit trail

### Cross-Cutting Concerns
- **Rate limiting**: different limits per endpoint group (questions: 60/min/user, uploads: 10/hr/workspace)
- **Request validation**: strict Pydantic schema validation before business logic
- **Consistent error responses**: `{status_code, error_code (machine-readable), message (human-readable)}`
- **API versioning**: `/v1/` prefix from day one, support at least 2 versions simultaneously
- **Request logging**: path, user_id, tenant_id, status_code, latency (no request bodies)
- **Payload principle**: app sends minimum necessary (auth token + workspace ID + action data), API derives the rest

### Internal vs External
**Exposed to mobile apps**: everything above, through API gateway with auth + rate limiting
**Internal only**: AI pipeline calls, async processing triggers, admin diagnostics, bulk migrations — separate port/service, internal networking only, service-to-service auth via managed identities

---

## 12. Flutter App Architecture

### Flavor System
- Single codebase, two entry points: `main_admin.dart`, `main_student.dart`
- Feature availability gated by flavor config injected via Riverpod at startup
- Build: `flutter run --flavor admin -t lib/main_admin.dart`
- Build: `flutter run --flavor student -t lib/main_student.dart`

### Folder Structure (Feature-First)
```
flutter_app/lib/
  core/               — theme, constants, DI, routing, extensions
  features/
    auth/
      data/           — repositories, data sources, DTOs
      domain/         — entities, repository interfaces
      presentation/   — screens, widgets, controllers (Riverpod notifiers)
    home/
    questions/
    flashcards/
    gamification/
    admin/
      documents/
      workspace/
      users/
      taxonomy/
      moderation/
      settings/
  shared/             — reusable widgets, models, services
```

### State Management: Riverpod 2.x
- `@riverpod` annotation for all providers
- AsyncNotifier for async state (loading/error/data)
- `ref.watch` in widgets, `ref.read` in callbacks
- Ephemeral state (text field focus, animation) stays local, not in Riverpod
- Freezed for immutable state classes and union types

### Networking: Dio
- Single Dio instance in DI
- Auth interceptor: attach JWT, handle token refresh transparently
- Error interceptor: map HTTP errors to typed app exceptions
- Logging interceptor (debug only)
- Response models via Freezed + json_serializable, matching backend Pydantic schemas

### Navigation: GoRouter
- All routes in `core/routing/`
- Typed route parameters via code generation
- Auth guards (redirect unauthenticated to login)
- Nested navigation for admin tabs and student bottom nav

### UI Rules
- Material 3 with custom ColorScheme
- Light + dark mode from day one
- Spacing scale: 4, 8, 12, 16, 24, 32, 48
- Haptic feedback on: correct/incorrect answers, badge unlocks, streak milestones
- Animations: AnimatedSwitcher, Hero, implicit animations
- Every screen handles: loading, error, empty, success states

### Testing
- Widget tests for every screen (all 4 states)
- Unit tests for every Notifier/Controller
- Integration tests for critical flows
- `mocktail` for mocking (not mockito)
- `ProviderScope.overrides` for DI in tests

---

## 13. MCP Server Design

### Tools
- **Topic selection tool**: runs Layer 1 algorithm (priority scoring, dependency check, variety)
- **Difficulty calibration tool**: targets 70–75% success probability
- **Content retrieval tool**: Azure AI Search with topic + metadata filters
- **Student context retrieval tool**: recent interactions, seen questions from Cosmos DB
- **Question deduplication tool**: checks recent history to prevent near-duplicates
- **Question validation tool**: quality + content safety check before delivery
- **Current status tool**: reads precomputed knowledge state
- **Ideal status tool**: reads workspace curriculum config

### Prompts
- All prompts live in `mcp-server/prompts/` as separate .txt files, never inline strings
- Every prompt has a version comment: `# v1.0 — date — description`
- Variables use `{{double_braces}}` syntax
- Different prompts for MCQ, long-answer, mathematical question types
- Test every prompt against 5+ diverse inputs before committing (use /prompt-eval skill)

---

## 14. Sprint Plan Summary (6 Sprints, 30 Days)

| Sprint | Days | Focus | Key Deliverables |
|---|---|---|---|
| 1 | 1–5 | Foundation | Azure provisioning, Cosmos DB + auth, CRUD APIs, Flutter scaffold + auth flow |
| 2 | 6–10 | Document Ingestion | Upload pipeline, text extraction, topic extraction, taxonomy merge, chunking, vectorization, Flutter admin upload screen |
| 3 | 11–15 | AI & Adaptive Learning | MCP server, Learning Path Engine, question generation prompts, /questions/next endpoint, knowledge state updates |
| 4 | 16–20 | Flutter Core UI | Admin: workspace/user/taxonomy/settings/moderation screens. Student: home/questions/flashcards/revision/progress screens. All vertical slices. |
| 5 | 21–25 | Gamification & Notifications | XP/levels/streaks/badges, leaderboards, push notifications, analytics dashboards, celebration animations |
| 6 | 26–30 | Polish & Launch Prep | E2E testing, performance optimization, COPPA review, security audit (/cso), offline support, app store submission |

### Work Division Principle
- **Human**: architecture decisions, Azure provisioning, complex UI/animations, integration testing
- **Claude Code**: boilerplate generation, schema implementation, API scaffolding, Flutter data layer, test writing
- **Both**: AI pipeline, prompt engineering, adaptive learning algorithm, design-critical screens

---

## 15. Key Risks

1. **Dynamic Taxonomy Quality (HIGH)**: AI topic extraction may be inaccurate. Mitigation: admin override tools, start flat in v1, iterate.
2. **Question Generation Latency (MEDIUM)**: Full pipeline may exceed 3s. Mitigation: prefetching, Redis caching, prompt optimization.
3. **COPPA Compliance (HIGH)**: Serving minors in US requires strict compliance. Mitigation: age-gating in AD B2C, parental consent flows, legal review.
4. **AI Content Safety (MEDIUM)**: AI may produce inappropriate content. Mitigation: two-tier moderation, regeneration rate monitoring.
5. **Cross-Platform Flutter Parity (MEDIUM)**: Platform-specific behaviors may diverge. Mitigation: test both platforms from Sprint 1.
6. **Scope Creep (MEDIUM)**: Ambitious 30-day timeline. Mitigation: strict P0/P1/P2 prioritization, cut P2 before extending timeline.

---

## 16. gstack Workflow Per Sprint

| Phase | gstack Skill | When |
|---|---|---|
| Think | /office-hours | Sprint start — pressure-test the sprint goal |
| Plan | /plan-eng-review | Sprint start — lock architecture decisions |
| Plan | /plan-design-review | Before new UI screens |
| Build | /careful | When working near auth, DB, or prod config |
| Build | /freeze | When debugging a specific module |
| Build | /investigate | For systematic root-cause debugging |
| Review | /review | Every branch before merge |
| Security | /cso | Security-sensitive changes (auth, data, moderation) |
| Test | /qa | Staging build, both iOS and Android |
| Ship | /ship | Run tests, audit coverage, open PR |
| Document | /document-release | Update docs to match what shipped |
| Reflect | /retro | Sprint end — what shipped, what didn't, what to improve |