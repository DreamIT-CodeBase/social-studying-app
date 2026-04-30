# AI Study App

## What This Is
Multi-tenant AI-powered study app for the US market. Generates personalized questions and flash cards from admin-uploaded study materials. Two user segments: families (parent + child) and schools (teacher + students). Native mobile apps built with Flutter, Python backend on Azure.

## Builder Ethos

### Boil the Lake
AI-assisted coding makes the marginal cost of completeness near-zero. When the complete implementation costs minutes more than the shortcut — do the complete thing. Every time. "Ship the shortcut" is legacy thinking. If approach A (full, ~150 LOC) vs approach B (90%, ~80 LOC) — always prefer A. Tests are the cheapest lake to boil. Never defer them.

### Search Before Building
Before building anything involving unfamiliar patterns — stop and search first. Three layers: (1) Tried and true — standard patterns, question the obvious. (2) New and popular — search and scrutinize, the crowd can be wrong. (3) First principles — original observations from reasoning about THIS problem. Prize these above everything. The eureka moment is discovering why the conventional approach is wrong for your specific case.

### Anti-Slop Mandate
Never produce slop. No placeholder code ("TODO: implement later"). No generic variable names. No copy-paste without understanding. No "this should work" — verify it works. If you're uncertain about an approach, say so and investigate rather than guessing. Every function earns its existence. Every line earns its place.

### Confusion Protocol
When you encounter architectural ambiguity — STOP. Do not guess. Do not fill in assumptions. Ask the human. Wrong assumptions compound into wrong architecture. The cost of asking is one message. The cost of guessing wrong is a rewrite.

## Tech Stack
- **Mobile Apps**: Flutter 3.x / Dart (single codebase, Admin + Student apps via flavor system)
- **Backend**: Python 3.12, FastAPI, hosted on Azure Container Apps
- **Database**: Azure Cosmos DB (MongoDB API) — one database per tenant, one collection per domain
- **Vector Store**: Azure AI Search — chunked document embeddings with metadata filters
- **AI Model**: Azure AI Foundry (GPT-4o) — question generation, topic extraction, taxonomy inference
- **AI Orchestration**: Custom MCP server (Python, containerized)
- **Auth**: Azure AD B2C (Microsoft Entra External ID)
- **Content Safety**: Azure AI Content Safety
- **Cache**: Azure Cache for Redis
- **Async**: Azure Functions + Azure Service Bus
- **Push Notifications**: Azure Notification Hubs + Firebase Cloud Messaging
- **State Management**: Riverpod 2.x (Flutter)
- **Navigation**: GoRouter (Flutter)
- **HTTP Client**: Dio with interceptors for auth token refresh

## Repo Structure
```
backend/app/api/         — FastAPI route handlers by domain
backend/app/models/      — Pydantic models (request/response + DB schemas)
backend/app/services/    — Business logic (adaptive learning, gamification, taxonomy, moderation)
backend/app/core/        — Config, DB connections, auth middleware, rate limiting
backend/app/workers/     — Async workers (doc ingestion, status recalc)
backend/tests/           — pytest tests
mcp-server/              — MCP server for AI pipeline
flutter_app/lib/         — Flutter application source
flutter_app/lib/core/    — Theme, constants, DI, routing, shared utilities
flutter_app/lib/features/ — Feature modules (auth, home, questions, flashcards, gamification, admin)
flutter_app/lib/shared/  — Shared widgets, models, services
flutter_app/test/        — Widget and unit tests
flutter_app/integration_test/ — Integration tests
infra/                   — Azure Bicep/Terraform
docs/                    — ADRs, API specs, onboarding
```

## Commands
```bash
# Backend
cd backend && uvicorn app.main:app --reload     # run API locally
cd backend && pytest                             # run all tests
cd backend && pytest tests/unit/                 # unit tests only
cd backend && ruff check .                       # lint Python
cd backend && ruff format .                      # format Python
cd backend && mypy app/                          # type check

# Flutter
cd flutter_app && flutter run                    # run app (debug)
cd flutter_app && flutter run --flavor admin     # run admin flavor
cd flutter_app && flutter run --flavor student   # run student flavor
cd flutter_app && flutter test                   # run all tests
cd flutter_app && flutter test --coverage        # test with coverage
cd flutter_app && flutter analyze                # static analysis
cd flutter_app && dart format .                  # format Dart
cd flutter_app && dart run build_runner build     # run code generation (Freezed, Riverpod)
```

## Key Architecture Decisions
- Tenant isolation at DB level (separate Cosmos DB database per tenant)
- Knowledge state is precomputed summary, not live aggregation
- Question generation uses 2-layer architecture: deterministic topic/difficulty selection + AI content generation
- Dynamic taxonomy: AI extracts topics from uploaded docs, admin can override
- Gamification state is denormalized for fast reads, updated async after interactions
- Flutter uses feature-first folder structure with Riverpod for DI and state
- Single Flutter codebase, two app flavors (admin + student) sharing core modules

## gstack
Use /browse from gstack for all web browsing. Never use mcp__claude-in-chrome__* tools.
Available skills: /office-hours, /plan-ceo-review, /plan-eng-review, /plan-design-review, /design-consultation, /design-shotgun, /design-html, /review, /ship, /qa, /qa-only, /design-review, /retro, /investigate, /document-release, /cso, /autoplan, /careful, /freeze, /guard, /unfreeze, /gstack-upgrade, /learn.

## When Compacting
Always preserve: the full list of modified files, current sprint number, any failing tests, the active task number from the project plan, and any architectural decisions made in this session.
