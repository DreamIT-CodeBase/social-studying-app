import asyncio
from fastapi.testclient import TestClient
from app.main import app
from app.core.auth import get_current_user
from app.models.user import User, UserRole

def override_get_current_user():
    return User(
        id="usr_seed_001",
        tenant_id="93e3ce50-a29e-462b-8956-85674a34d167",
        email="tarunjunejaun471@gmail.com",
        display_name="Tarun Juneja",
        role=UserRole.student,
        workspace_memberships=[],
        is_active=True,
        identity_provider="test",
        identity_subject="test",
    )

app.dependency_overrides[get_current_user] = override_get_current_user

def main():
    client = TestClient(app)
    response = client.post("/api/v1/users/me/notification-tokens/test-push")
    print("STATUS:", response.status_code)
    print("RESPONSE:", response.json())

if __name__ == "__main__":
    main()
