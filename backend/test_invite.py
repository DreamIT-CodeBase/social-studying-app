import asyncio
from fastapi.testclient import TestClient
from app.main import app
from app.core.auth import get_current_user
from app.models.user import User, UserRole

def override_get_current_user():
    return User(
        id="usr_admin",
        tenant_id="93e3ce50-a29e-462b-8956-85674a34d167",
        email="admin@test.com",
        display_name="Admin",
        role=UserRole.tenant_admin,
        workspace_memberships=[],
        is_active=True,
    )

app.dependency_overrides[get_current_user] = override_get_current_user

def main():
    client = TestClient(app)
    # create a mock workspace first? Wait, I need an existing workspace ID.
    # From the earlier logs, workspace_id: wsp_f2672fc1d8ed4623a26095cc1214c3e0
    response = client.post(
        "/api/v1/workspaces/wsp_f2672fc1d8ed4623a26095cc1214c3e0/members",
        json={
            "email": "teststudent100@gmail.com",
            "display_name": "Test Student 100",
            "role": "student"
        }
    )
    print("STATUS:", response.status_code)
    print("RESPONSE:", response.json())

if __name__ == "__main__":
    main()
