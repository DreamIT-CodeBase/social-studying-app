---
name: endpoint-scaffold
description: Scaffolds a new API endpoint (FastAPI) AND its corresponding Flutter feature module together. Enforces full vertical slice — backend + frontend + tests in one go.
---

# Endpoint Scaffold Skill

When adding a new feature, build the full vertical slice. Not "backend first, frontend later." Both, together, tested.

## Backend (4 files minimum)

### 1. Router (`backend/app/api/{domain}.py`)
```python
from fastapi import APIRouter, Depends, HTTPException, status
from app.core.auth import get_current_user, require_role
from app.core.database import get_db
from app.models.{domain} import {Model}Create, {Model}Response
from app.services.{domain}_service import {Domain}Service

router = APIRouter(prefix="/{domain}", tags=["{domain}"])

@router.post("/", response_model={Model}Response, status_code=status.HTTP_201_CREATED)
async def create_{entity}(
    data: {Model}Create,
    user=Depends(get_current_user),
    db=Depends(get_db),
):
    """Create a new {entity}."""
    service = {Domain}Service(db)
    return await service.create(data, user)
```

### 2. Models (`backend/app/models/{domain}.py`)
- `{Model}Create` — request body validation (all required fields, type constraints)
- `{Model}Update` — partial update (all fields Optional)
- `{Model}Response` — response serialization (exclude internal fields like _id, deleted_at)
- `{Model}InDB` — full document schema including internal fields

### 3. Service (`backend/app/services/{domain}_service.py`)
- Constructor takes DB dependency
- Each method handles one operation
- Raise custom exceptions, not HTTPException (that's the router's job)
- Include docstrings with param and return descriptions

### 4. Tests (`backend/tests/unit/api/test_{domain}.py`)
- Minimum 6 tests per endpoint (happy, auth, permission, validation, not-found, tenant-isolation)

### 5. Register: Add to `backend/app/main.py`: `app.include_router({domain}.router)`

## Flutter (5 files minimum per feature)

### 1. Repository (`flutter_app/lib/features/{feature}/data/{feature}_repository.dart`)
- Abstracts API calls via Dio
- Returns typed domain models, not raw JSON
- Handles API errors and maps to app-specific exceptions

### 2. Provider (`flutter_app/lib/features/{feature}/presentation/{feature}_controller.dart`)
- `@riverpod` annotated AsyncNotifier
- Methods for each user action
- State transitions: loading → data or loading → error

### 3. Screen (`flutter_app/lib/features/{feature}/presentation/{feature}_screen.dart`)
- Handles ALL states: loading (shimmer or spinner), error (message + retry), empty (illustration + CTA), success (the actual content)
- Uses `ref.watch` for reactive state

### 4. Model (`flutter_app/lib/features/{feature}/data/{feature}_model.dart`)
- Freezed + json_serializable
- Must match backend Response model field names exactly

### 5. Tests (`flutter_app/test/features/{feature}/`)
- Widget test for the screen (all 4 states)
- Unit test for the controller/notifier

## The Rule
Never create backend without frontend. Never create frontend without backend. Never create either without tests. Vertical slices, fully baked, every time. This is what Boil the Lake means in practice.
