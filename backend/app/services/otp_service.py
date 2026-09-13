"""Email OTP generation, verification, and rate limiting service.

Provides:
1. Secure 6-digit OTP generation using secrets.
2. SHA-256 salted hashing so OTPs are never stored in plaintext.
3. Expiration enforcement (10 minutes) and single-use guarantee.
4. Rate limiting: max 3 requests per 15 minutes, max 5 failed attempts per OTP.
5. Signed HMAC verification tokens returned upon successful verification.
"""

from __future__ import annotations

import hashlib
import hmac
import logging
import secrets
import time
from datetime import UTC, datetime, timedelta
from typing import Any

from app.core.config import settings
from app.core.database import EMAIL_OTPS, get_collection
from app.core.exceptions import BadRequestError
from app.services.email import EmailPayload, get_email_sender

logger = logging.getLogger(__name__)

OTP_EXPIRY_MINUTES = 10
MAX_ATTEMPTS = 5
RATE_LIMIT_MINUTES = 15
MAX_REQUESTS_PER_WINDOW = 3
TOKEN_VALIDITY_MINUTES = 45


def _get_signing_key() -> bytes:
    key_str = (
        getattr(settings, "jwt_secret_key", None)
        or settings.stripe_secret_key
        or settings.dev_auth_token
        or "social-studying-secure-otp-signing-key"
    )
    return key_str.encode("utf-8")


def generate_otp_code() -> str:
    """Generate a cryptographically secure 6-digit numeric OTP."""
    return f"{secrets.randbelow(900_000) + 100_000}"


def _hash_code(code: str, salt: str) -> str:
    return hashlib.sha256(f"{salt}:{code}".encode()).hexdigest()


def generate_verification_token(email: str) -> str:
    """Generate a tamper-proof signed token confirming email verification."""
    email_clean = email.strip().lower()
    issued_at = int(time.time())
    payload = f"{email_clean}:{issued_at}"
    signature = hmac.new(_get_signing_key(), payload.encode("utf-8"), hashlib.sha256).hexdigest()
    return f"{payload}:{signature}"


def validate_verification_token(email: str, token: str) -> bool:
    """Validate that the verification token was signed by us and has not expired."""
    if not token or ":" not in token:
        return False
    parts = token.split(":")
    if len(parts) != 3:
        return False

    tok_email, issued_str, signature = parts
    if tok_email.strip().lower() != email.strip().lower():
        return False

    try:
        issued_at = int(issued_str)
    except ValueError:
        return False

    # Check expiration
    age_seconds = time.time() - issued_at
    if age_seconds < 0 or age_seconds > (TOKEN_VALIDITY_MINUTES * 60):
        return False

    expected_payload = f"{tok_email}:{issued_str}"
    expected_sig = hmac.new(
        _get_signing_key(), expected_payload.encode("utf-8"), hashlib.sha256
    ).hexdigest()
    return hmac.compare_digest(signature, expected_sig)


def _get_otp_email_html(email: str, code: str) -> str:
    return f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Social Studying Verification Code</title>
  <style>
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
      background-color: #f8fafc;
      margin: 0;
      padding: 24px;
      color: #1e293b;
    }}
    .container {{
      max-width: 520px;
      margin: 0 auto;
      background: #ffffff;
      border-radius: 16px;
      border: 1px solid #e2e8f0;
      overflow: hidden;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.05);
    }}
    .header {{
      background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 100%);
      padding: 32px 24px;
      text-align: center;
      color: #ffffff;
    }}
    .header h1 {{
      margin: 0;
      font-size: 24px;
      font-weight: 700;
      letter-spacing: -0.5px;
    }}
    .content {{
      padding: 32px 24px;
    }}
    .code-box {{
      background: #f1f5f9;
      border: 2px dashed #cbd5e1;
      border-radius: 12px;
      text-align: center;
      padding: 24px;
      margin: 24px 0;
    }}
    .otp-code {{
      font-size: 38px;
      font-weight: 800;
      letter-spacing: 8px;
      color: #4f46e5;
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
    }}
    .expiry {{
      color: #64748b;
      font-size: 13px;
      margin-top: 8px;
    }}
    .footer {{
      background: #f8fafc;
      padding: 20px 24px;
      border-top: 1px solid #e2e8f0;
      font-size: 12px;
      color: #94a3b8;
      text-align: center;
    }}
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>Social Studying AI</h1>
      <p style="margin: 6px 0 0; opacity: 0.9; font-size: 14px;">Subscription Verification</p>
    </div>
    <div class="content">
      <p style="font-size: 16px; margin: 0 0 16px;">Hello,</p>
      <p style="font-size: 15px; line-height: 1.5; color: #475569; margin: 0;">
        Please enter the verification code below to verify your email address <strong>{email}</strong> and proceed with your subscription checkout:
      </p>
      <div class="code-box">
        <div class="otp-code">{code}</div>
        <div class="expiry">Expires in {OTP_EXPIRY_MINUTES} minutes • One-time use only</div>
      </div>
      <p style="font-size: 13px; color: #64748b; line-height: 1.5; margin: 0;">
        If you did not request this code, you can safely ignore this email. Someone may have entered your email address by mistake.
      </p>
    </div>
    <div class="footer">
      &copy; {datetime.now().year} Social Studying AI. All rights reserved.
    </div>
  </div>
</body>
</html>"""


async def send_email_otp(email: str) -> dict[str, Any]:
    """Generate, store, and email a single-use 6-digit OTP to the recipient."""
    email_clean = email.strip().lower()
    if "@" not in email_clean or "." not in email_clean:
        raise BadRequestError("Please provide a valid email address.")

    tenant_id = getattr(settings, "dev_auth_tenant_id", "platform")
    otp_col = get_collection(tenant_id, EMAIL_OTPS)

    # Rate limiting: count requests in last RATE_LIMIT_MINUTES
    cutoff = (datetime.now(UTC) - timedelta(minutes=RATE_LIMIT_MINUTES)).isoformat()
    recent_count = await otp_col.count_documents(
        {"email": email_clean, "created_at": {"$gte": cutoff}}
    )
    if recent_count >= MAX_REQUESTS_PER_WINDOW:
        raise BadRequestError(
            f"Too many verification requests. Please wait {RATE_LIMIT_MINUTES} minutes before requesting another code."
        )

    code = generate_otp_code()
    salt = secrets.token_hex(16)
    hashed_code = _hash_code(code, salt)
    now = datetime.now(UTC)
    expires_at = (now + timedelta(minutes=OTP_EXPIRY_MINUTES)).isoformat()

    # Invalidate any previously active OTPs for this email
    await otp_col.update_many(
        {"email": email_clean, "verified": False},
        {"$set": {"verified": False, "invalidated": True}},
    )

    # Insert new OTP record
    record = {
        "_id": f"otp_{secrets.token_hex(12)}",
        "email": email_clean,
        "code_hash": hashed_code,
        "salt": salt,
        "attempts": 0,
        "verified": False,
        "invalidated": False,
        "created_at": now.isoformat(),
        "expires_at": expires_at,
    }
    await otp_col.insert_one(record)

    # Dispatch email
    payload = EmailPayload(
        to_email=email_clean,
        subject=f"{code} is your Social Studying verification code",
        body_text=(
            f"Your Social Studying verification code is: {code}\n\n"
            f"This code will expire in {OTP_EXPIRY_MINUTES} minutes. Do not share this code with anyone."
        ),
        body_html=_get_otp_email_html(email_clean, code),
    )

    try:
        sender = get_email_sender()
        await sender.send(payload)
        logger.info("Sent email OTP to %s", email_clean)
    except Exception as exc:
        logger.exception("Failed to dispatch OTP email to %s: %s", email_clean, exc)
        # If running in local dev/testing without active SMTP or Graph, do not crash
        if getattr(settings, "environment", "") != "production":
            logger.warning("[DEV] OTP code for %s is %s", email_clean, code)

    return {
        "message": f"Verification code sent to {email_clean}",
        "expires_in_seconds": OTP_EXPIRY_MINUTES * 60,
    }


async def verify_email_otp(email: str, otp: str) -> str:
    """Verify an input OTP and return a signed verification token on success."""
    email_clean = email.strip().lower()
    otp_clean = otp.strip()

    if not otp_clean or len(otp_clean) != 6 or not otp_clean.isdigit():
        raise BadRequestError("Please enter a valid 6-digit numeric verification code.")

    tenant_id = getattr(settings, "dev_auth_tenant_id", "platform")
    otp_col = get_collection(tenant_id, EMAIL_OTPS)

    # Find the most recent active OTP record
    doc = await otp_col.find_one(
        {"email": email_clean, "verified": False, "invalidated": False},
        sort=[("created_at", -1)],
    )

    if not doc:
        raise BadRequestError("No active verification code found. Please request a new code.")

    now_iso = datetime.now(UTC).isoformat()
    if doc.get("expires_at", "") < now_iso:
        await otp_col.update_one({"_id": doc["_id"]}, {"$set": {"invalidated": True}})
        raise BadRequestError("Verification code has expired. Please request a new code.")

    doc_id = doc.get("_id")
    attempts = int(doc.get("attempts", 0))
    if attempts >= MAX_ATTEMPTS:
        if doc_id:
            await otp_col.update_one({"_id": doc_id}, {"$set": {"invalidated": True}})
        raise BadRequestError(
            "Too many incorrect attempts. This code has been invalidated. Please request a new code."
        )

    # Compare hash
    salt = doc.get("salt", "")
    expected_hash = doc.get("code_hash", "")
    computed_hash = _hash_code(otp_clean, salt)

    if not hmac.compare_digest(computed_hash, expected_hash):
        if doc_id:
            await otp_col.update_one({"_id": doc_id}, {"$inc": {"attempts": 1}})
        remaining = MAX_ATTEMPTS - (attempts + 1)
        raise BadRequestError(
            f"Incorrect verification code. {remaining} attempt(s) remaining."
        )

    # Success — mark single-use OTP as verified
    if doc_id:
        await otp_col.update_one(
            {"_id": doc_id},
            {"$set": {"verified": True, "verified_at": now_iso}},
        )

    # Issue signed verification token
    return generate_verification_token(email_clean)
