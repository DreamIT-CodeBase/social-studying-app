---
globs: "backend/**/*.py"
---

# Python Backend Rules

## Ethos: Boil the Lake
Every endpoint gets full error handling, full validation, full tests. "I'll add tests later" is not acceptable. The marginal cost of completeness is near-zero with AI assistance. If you're writing a service method, write its tests in the same session. If you're handling errors, handle ALL the errors — not just the happy path.

## Ethos: Search Before Building
Before implementing any infrastructure pattern (caching strategy, queue processing, DB query optimization), check if Azure SDKs or FastAPI ecosystem already solve it. Don't roll custom middleware when a well-tested library exists. But scrutinize what you find — Layer 2 (popular) is not the same as Layer 1 (battle-tested).

## FastAPI Patterns
Every router file uses `router = APIRouter(prefix="/...", tags=["..."])`. Use `Depends()` for auth, DB, and service injection — never instantiate in handlers. Response models on every endpoint via `response_model=SomeSchema`. Use `status_code=` on create endpoints (201), delete endpoints (204). Background tasks via `BackgroundTasks` for fire-and-forget work.

## Cosmos DB Patterns
Always specify partition key in queries: `collection.find({"user_id": uid}, partition_key=uid)`. Use `replace_one` for updates, not `update_one` with `$set` — keeps documents predictable. Soft delete: set `deleted_at` timestamp, never remove documents. All timestamps as ISO 8601 UTC strings. IDs: use `str(uuid4())` prefixed with entity type: `usr_`, `wsp_`, `ten_`, `doc_`, `qst_`.

## Error Handling
Custom exception classes in `app/core/exceptions.py`. Global exception handler maps custom exceptions to HTTP responses. Never catch bare `Exception` — catch specific types. Log errors with structured context: `logger.error("msg", extra={"user_id": ..., "workspace_id": ...})`.

## Testing
Test files mirror source: `app/api/auth.py` → `tests/unit/api/test_auth.py`. Use pytest fixtures for DB mocks, auth context, and test data. Every endpoint test covers: happy path, auth failure, validation error, not found. No tests hit real Azure services — mock all external calls.

## Anti-Slop
No `# TODO: implement` comments. No `pass` in except blocks. No `print()` for debugging — use the logger. No `Any` type hints unless genuinely unavoidable (document why). No magic strings — use enums or constants. Every function has a docstring. If a function is longer than 40 lines, it's doing too much — split it.
