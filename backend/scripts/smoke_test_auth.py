"""Smoke test for Microsoft Entra External ID (CIAM) — Sprint 1 task 1.5.

Verifies that the user flow + custom-attribute mapping issues a JWT containing
``extension_TenantId``. Pops a browser, performs auth code + PKCE via MSAL,
then prints the decoded ID and access token claims.

Run from the backend/ directory::

    python scripts/smoke_test_auth.py

Required env vars (loaded from backend/.env or backend/.env.dev):

    B2C_TENANT_SUBDOMAIN  the part before .ciamlogin.com (e.g. "socialstudyingapp")
    B2C_TENANT_ID         the directory GUID
    B2C_CLIENT_ID         the application (client) ID

Prerequisites in the Entra portal:
    1. App registration has http://localhost as a Mobile and desktop redirect URI.
    2. App manifest has acceptMappedClaims = true and isFallbackPublicClient = true.
    3. Enterprise Application > Single sign-on > Attributes & Claims includes a
       claim named "extension_TenantId" sourced from the b2c-extensions-app
       directory schema extension.
    4. App registration > Expose an API has at least one scope (e.g. access_as_user)
       — required for the access-token request below. If you skipped this, replace
       the SCOPES list with ["openid", "profile"] and read claims from id_token only.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def _load_env_file(path: Path) -> None:
    if not path.exists():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        os.environ.setdefault(key.strip(), value.strip())


_BACKEND_DIR = Path(__file__).resolve().parent.parent
for _fname in (".env", ".env.dev"):
    _load_env_file(_BACKEND_DIR / _fname)


TENANT_SUBDOMAIN = os.environ.get("B2C_TENANT_SUBDOMAIN", "")
TENANT_ID = os.environ.get("B2C_TENANT_ID", "")
CLIENT_ID = os.environ.get("B2C_CLIENT_ID", "")

_missing = [
    name
    for name, value in (
        ("B2C_TENANT_SUBDOMAIN", TENANT_SUBDOMAIN),
        ("B2C_TENANT_ID", TENANT_ID),
        ("B2C_CLIENT_ID", CLIENT_ID),
    )
    if not value
]
if _missing:
    sys.exit(
        f"Missing env var(s): {', '.join(_missing)}.\n"
        "Set them in backend/.env.dev. B2C_TENANT_SUBDOMAIN is the part before "
        ".ciamlogin.com (e.g. 'socialstudyingapp')."
    )

AUTHORITY = f"https://{TENANT_SUBDOMAIN}.ciamlogin.com/{TENANT_ID}"
# SCOPES = [f"api://{CLIENT_ID}/.default"]
# SCOPES = ["openid", "profile"]
SCOPES = [f"api://{CLIENT_ID}/access_as_user"]

try:
    import msal
except ImportError:
    sys.exit("msal not installed. Run: pip install msal  (or: pip install -e '.[dev]')")

try:
    from jose import jwt as jose_jwt
except ImportError:
    sys.exit("python-jose not installed. Run: pip install 'python-jose[cryptography]'")


print(f"Authority: {AUTHORITY}")
print(f"Client ID: {CLIENT_ID}")
print(f"Scopes:    {SCOPES}")
print("\nA browser window will open. Sign up with a fresh email, then return here.\n")

app = msal.PublicClientApplication(client_id=CLIENT_ID, authority=AUTHORITY)
result = app.acquire_token_interactive(scopes=SCOPES, prompt="select_account")

if "access_token" not in result and "id_token" not in result:
    print("FAILED to acquire token:")
    print(json.dumps(result, indent=2))
    sys.exit(1)


def _print_claims(label: str, token: str | None) -> dict:
    """Decode without signature verification — this is a smoke test, not a security check.

    auth.py verifies signatures on every real request. Here we only inspect the payload.
    """
    if not token:
        print(f"\n── {label}: <not returned> ──")
        return {}
    claims = jose_jwt.get_unverified_claims(token)
    print(f"\n── {label} ──")
    print(json.dumps(claims, indent=2, default=str))
    return claims


id_claims = _print_claims("ID token claims", result.get("id_token"))
access_claims = _print_claims("Access token claims", result.get("access_token"))

failures: list[str] = []
combined = {**access_claims, **id_claims}

if not combined.get("sub"):
    failures.append("Token missing 'sub' claim")

if not combined.get("extension_TenantId"):
    failures.append(
        "Token missing 'extension_TenantId' — check claim mapping in "
        "Enterprise App → Single sign-on → Attributes & Claims, and that "
        "acceptMappedClaims=true in the app manifest."
    )

if failures:
    print("\nFAILED:")
    for f in failures:
        print(f"  - {f}")
    sys.exit(1)

print("\nPASSED. Token contains sub + extension_TenantId. Sprint 1 task 1.5 verified.")
if result.get("access_token"):
    print(
        "\nFor jwt.io inspection, paste this access token:\n"
        f"{result['access_token']}"
    )
