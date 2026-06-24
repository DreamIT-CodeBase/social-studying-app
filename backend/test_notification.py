"""
Notification end-to-end test script
====================================
Two ways to test:

  1. Via the backend API (requires the backend running + a valid JWT):
       python test_notification.py --via-api --token <your_id_token>

  2. Directly via FCM HTTP v1 API (requires google-services service-account key):
       python test_notification.py --via-fcm --fcm-token <device_fcm_token>

Run with no flags to see this help.
"""
import argparse
import json
import sys

import httpx

BACKEND_BASE = "http://127.0.0.1:8000"


# ── Option 1: via the backend API ──────────────────────────────────────────

def test_via_api(id_token: str) -> None:
    """Call POST /api/v1/users/me/notification-tokens/test-push.
    
    This uses the new test endpoint that fires the push through whatever
    sender is configured (LoggingSender in local dev, ANH in production).
    """
    print("\n=== Testing via backend API ===")
    url = f"{BACKEND_BASE}/api/v1/users/me/notification-tokens/test-push"
    headers = {"Authorization": f"Bearer {id_token}"}

    with httpx.Client(timeout=30) as client:
        resp = client.post(url, headers=headers)

    print(f"Status: {resp.status_code}")
    try:
        body = resp.json()
        print(json.dumps(body, indent=2))
    except Exception:
        print(resp.text)

    if resp.status_code == 200:
        body = resp.json()
        sender = body.get("sender_type", "?")
        devices = body.get("devices_found", 0)
        if sender == "LoggingSender":
            print(
                "\n⚠️  sender_type=LoggingSender means the backend only LOGGED the push."
                "\n   No real notification was sent to your device."
                "\n   → Add NOTIFICATION_HUB_CONNECTION_STRING + NOTIFICATION_HUB_NAME to .env"
                "\n     OR use --via-fcm with a Firebase service-account key for direct FCM testing."
            )
        elif devices == 0:
            print(
                "\n⚠️  No registered devices found."
                "\n   The app did not successfully register an FCM token with the backend."
                "\n   → Check that google-services.json is present in flutter_app/android/app/"
                "\n     and that Firebase.initializeApp() succeeds on the device."
            )
        else:
            print(f"\n✅ Push dispatched to {devices} device(s) via {sender}.")


# ── Option 2: direct FCM HTTP v1 ──────────────────────────────────────────

def test_via_fcm(fcm_token: str, service_account_json: str | None) -> None:
    """Send a push directly via FCM HTTP v1 API.

    Requires a Firebase service-account JSON key file.
    Download it from Firebase Console → Project Settings → Service Accounts
    → Generate New Private Key.

    If you don't have the key file this prints a guide.
    """
    print("\n=== Testing via FCM HTTP v1 ===")

    if not service_account_json:
        print(
            "⚠️  --service-account not provided.\n\n"
            "To test directly via FCM:\n"
            "  1. Open Firebase Console → your project → Project Settings\n"
            "  2. Go to Service Accounts tab\n"
            "  3. Click 'Generate New Private Key' → save as service-account.json\n"
            "  4. Re-run:\n"
            "       python test_notification.py --via-fcm "
            "--fcm-token <token> --service-account service-account.json\n"
        )
        sys.exit(1)

    try:
        import google.auth
        import google.auth.transport.requests
        from google.oauth2 import service_account
    except ImportError:
        print(
            "Missing google-auth. Install it:\n"
            "  pip install google-auth\n"
        )
        sys.exit(1)

    with open(service_account_json) as f:
        sa_info = json.load(f)

    project_id = sa_info["project_id"]
    credentials = service_account.Credentials.from_service_account_info(
        sa_info,
        scopes=["https://www.googleapis.com/auth/firebase.messaging"],
    )
    auth_req = google.auth.transport.requests.Request()
    credentials.refresh(auth_req)
    access_token = credentials.token

    fcm_url = (
        f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    )
    payload = {
        "message": {
            "token": fcm_token,
            "notification": {
                "title": "🔔 Test notification",
                "body": "Direct FCM test — push is working!",
            },
            "data": {
                "type": "study_reminder",
                "workspace_id": "test",
            },
            "android": {
                "priority": "HIGH",
            },
        }
    }
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json",
    }

    with httpx.Client(timeout=30) as client:
        resp = client.post(fcm_url, json=payload, headers=headers)

    print(f"FCM status: {resp.status_code}")
    try:
        body = resp.json()
        print(json.dumps(body, indent=2))
    except Exception:
        print(resp.text)

    if resp.status_code == 200:
        print("\n✅ FCM accepted the push. Check your device — it should arrive within seconds.")
    elif resp.status_code == 400:
        err = resp.json().get("error", {})
        if "INVALID_ARGUMENT" in str(err):
            print(
                "\n❌ Invalid FCM token. The token may have expired or the app was reinstalled."
                "\n   Sign out and sign back in to generate a fresh token."
            )
    elif resp.status_code == 404:
        print(
            "\n❌ FCM token not found (404). The token is stale."
            "\n   Reinstall the app or clear app data to get a fresh token."
        )


# ── CLI ────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Test push notifications end-to-end.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--via-api", action="store_true",
                      help="Test via the backend /test-push endpoint")
    mode.add_argument("--via-fcm", action="store_true",
                      help="Test by sending directly to FCM HTTP v1 API")

    parser.add_argument("--token", metavar="ID_TOKEN",
                        help="Your Entra External ID JWT (for --via-api)")
    parser.add_argument("--fcm-token", metavar="FCM_TOKEN",
                        help="The device FCM token (for --via-fcm)")
    parser.add_argument("--service-account", metavar="PATH",
                        help="Path to Firebase service-account JSON (for --via-fcm)")
    parser.add_argument("--backend", default=BACKEND_BASE,
                        help=f"Backend base URL (default: {BACKEND_BASE})")

    args = parser.parse_args()

    global BACKEND_BASE
    BACKEND_BASE = args.backend

    if args.via_api:
        if not args.token:
            parser.error("--via-api requires --token <your_jwt>")
        test_via_api(args.token)
    elif args.via_fcm:
        if not args.fcm_token:
            parser.error("--via-fcm requires --fcm-token <device_fcm_token>")
        test_via_fcm(args.fcm_token, args.service_account)


if __name__ == "__main__":
    main()
