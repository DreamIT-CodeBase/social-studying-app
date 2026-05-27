# Social Study App — API Reference

The backend is a FastAPI service that auto-generates an OpenAPI 3.x
spec from the route signatures + Pydantic models + docstrings. This
folder doesn't hand-maintain endpoint reference docs — that would
drift the moment the code changes. It points at the live spec
instead.

## Where to find the docs

### Local dev

```powershell
cd backend
uvicorn app.main:app --reload
```

| URL                                              | What it serves                                            |
|--------------------------------------------------|-----------------------------------------------------------|
| http://localhost:8000/docs                       | Swagger UI — interactive, "Try it out" buttons live       |
| http://localhost:8000/redoc                      | ReDoc — read-friendly, deep-linkable, no client overhead  |
| http://localhost:8000/openapi.json               | Raw OpenAPI 3.x JSON. Useful for codegen.                 |
| http://localhost:8000/api/versions               | Discovery: live API versions + lifecycle status           |
| http://localhost:8000/health                     | Liveness probe — Cosmos + Redis pings + version           |

### Deployed environments

The `/docs` and `/redoc` UIs are **disabled in production** by
default — see `app.main`'s `docs_url=` argument, which checks
`settings.environment`. The OpenAPI spec at `/openapi.json` stays
live so codegen tools and the Flutter client can still introspect
the surface.

To browse the spec interactively against a non-prod deployment,
point a local Swagger UI at the deployed `/openapi.json`:

```powershell
# Or run a local Swagger UI Docker image:
docker run -p 8080:8080 -e SWAGGER_JSON_URL=https://api-dev.socialstudyapp.com/openapi.json swaggerapi/swagger-ui
```

## Versioning

All routes live under `/api/v1`. Adding `/api/v2` later means a new
prefix mount in `app/main.py` plus an entry in
`app/core/versioning.py:API_VERSIONS`. The `VersionResponseMiddleware`
stamps every response with `X-API-Version` identifying the version
that served it.

The `GET /api/versions` endpoint is the discovery point. Its wire
shape:

```json
{
  "versions": [
    {
      "version": "v1",
      "status": "stable",
      "sunset_date": null,
      "base_path": "/api/v1"
    }
  ]
}
```

When v2 ships, v1 stays at `status: "stable"` until we deprecate it
(`status: "deprecated"`, `sunset_date` populated); the spec then
sunsets per the date.

## Authentication

JWT bearer tokens from Microsoft Entra External ID:

```
Authorization: Bearer <jwt>
```

Routes that don't require auth:

- `/health`
- `/api/versions`
- `/openapi.json`
- `/api/v1/auth/register-completion`
- `/api/v1/auth/invite-code/validate`

Everything else expects a token. Inside the handler the JWT's `oid`
claim resolves through `app.core.auth.get_current_user` to a `User`
domain object; tenant scope + workspace membership are enforced per
route.

## ID conventions

| Prefix    | Type                                          |
|-----------|-----------------------------------------------|
| `ten_`    | Tenant                                        |
| `wsp_`    | Workspace                                     |
| `usr_`    | User                                          |
| `doc_`    | Document                                      |
| `qst_`    | Question                                      |
| `fc_`     | Flashcard                                     |
| `gam_`    | Gamification state                            |
| `ks_`     | Knowledge state                               |
| `itx_`    | Interaction (answer log row)                  |
| `rat_`    | Flashcard rating event                        |
| `ntk_`    | Notification token                            |
| `nd_`     | Notification dispatch (push log row)          |
| `chk_`    | Chunk (per-document text fragment)            |
| `top_`    | Canonical taxonomy topic                      |
| `mod_`    | Moderation log row                            |

All IDs are opaque-but-stable UUIDs prefixed by the entity type. The
prefix is informational — Cosmos doesn't enforce it.

## Codegen for clients

Generate a typed Dart client from the spec:

```powershell
# From the flutter_app/ directory
flutter pub run openapi_generator generate -i ../backend/openapi.json -g dart-dio
```

(MVP doesn't ship a generated client — the Flutter side hand-rolls
Freezed models keyed to the wire shape via `@JsonKey`. When the
surface stabilises post-launch we'll switch to codegen.)

## Adding a new endpoint

1. Add the route handler to the appropriate file under `app/api/`.
2. Carry a meaningful docstring — FastAPI uses it as the route
   description in the OpenAPI spec.
3. Set `response_model=` so the response schema lands in the spec.
4. Document non-200 paths with explicit `responses=` overrides when
   the handler raises something the auto-detection won't catch.
5. Tag the route under one of the entries in `_OPENAPI_TAGS`
   (`app/main.py`) so it groups properly in the Swagger UI.

The Sprint 6.7 + 6.10 work locks the conventions above — keep
following them and `/docs` stays self-documenting.
