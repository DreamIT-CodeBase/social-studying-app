"""Transactional email dispatch through Microsoft Graph or SMTP."""

from __future__ import annotations

import base64
import logging
import mimetypes
import os
import smtplib
import time
from abc import ABC, abstractmethod
from email.message import EmailMessage
from pathlib import Path
from urllib.parse import quote

import httpx
from fastapi.concurrency import run_in_threadpool
from pydantic import BaseModel

from app.core.config import settings

logger = logging.getLogger(__name__)


class EmailPayload(BaseModel):
    to_email: str
    subject: str
    body_text: str
    body_html: str | None = None
    logo_path: str | None = None


class EmailSender(ABC):
    @abstractmethod
    async def send(self, payload: EmailPayload) -> bool:
        """Dispatch an email and report whether the provider accepted it."""


class LoggingEmailSender(EmailSender):
    """Local-development sender that logs instead of delivering."""

    async def send(self, payload: EmailPayload) -> bool:
        logger.info(
            "Outbound email suppressed recipient=%s subject=%s",
            payload.to_email,
            payload.subject,
        )
        return True


class SMTPEmailSender(EmailSender):
    """Legacy SMTP sender retained for non-Graph environments."""

    def __init__(self, host: str, port: int, username: str, password: str):
        self.host = host
        self.port = port
        self.username = username
        self.password = password

    def _send_sync(self, payload: EmailPayload) -> bool:
        msg = EmailMessage()
        msg["Subject"] = payload.subject
        msg["From"] = self.username
        msg["To"] = payload.to_email
        msg.set_content(payload.body_text)

        if payload.body_html:
            msg.add_alternative(payload.body_html, subtype="html")
            if payload.logo_path and os.path.exists(payload.logo_path):
                with open(payload.logo_path, "rb") as image_file:
                    image_data = image_file.read()
                html_part = msg.get_payload()[1]
                html_part.add_related(
                    image_data,
                    "image",
                    "jpeg",
                    cid="<app_logo>",
                )

        try:
            with smtplib.SMTP(self.host, self.port) as server:
                server.starttls()
                server.login(self.username, self.password)
                server.send_message(msg)
            return True
        except Exception:
            logger.exception("SMTP email failed recipient=%s", payload.to_email)
            return False

    async def send(self, payload: EmailPayload) -> bool:
        return await run_in_threadpool(self._send_sync, payload)


class MicrosoftGraphEmailSender(EmailSender):
    """Send as a Microsoft 365 mailbox using app-only Graph authentication."""

    def __init__(
        self,
        *,
        tenant_id: str,
        client_id: str,
        client_secret: str,
        sender_email: str,
        transport: httpx.AsyncBaseTransport | None = None,
    ) -> None:
        self.tenant_id = tenant_id
        self.client_id = client_id
        self.client_secret = client_secret
        self.sender_email = sender_email
        self.transport = transport
        self._token: str | None = None
        self._token_expires_at = 0.0

    async def _get_access_token(self, client: httpx.AsyncClient) -> str:
        if self._token and time.monotonic() < self._token_expires_at:
            return self._token

        response = await client.post(
            f"https://login.microsoftonline.com/{quote(self.tenant_id, safe='')}/oauth2/v2.0/token",
            data={
                "client_id": self.client_id,
                "client_secret": self.client_secret,
                "scope": "https://graph.microsoft.com/.default",
                "grant_type": "client_credentials",
            },
        )
        response.raise_for_status()
        body = response.json()
        token = str(body.get("access_token", "")).strip()
        if not token:
            raise ValueError("Microsoft identity response did not include an access token")
        expires_in = max(60, int(body.get("expires_in", 3600)))
        self._token = token
        self._token_expires_at = time.monotonic() + expires_in - 60
        return token

    @staticmethod
    def _message(payload: EmailPayload) -> dict:
        content_type = "HTML" if payload.body_html else "Text"
        content = payload.body_html or payload.body_text
        message: dict = {
            "subject": payload.subject,
            "body": {"contentType": content_type, "content": content},
            "toRecipients": [{"emailAddress": {"address": payload.to_email}}],
        }

        if payload.logo_path and Path(payload.logo_path).is_file():
            logo_path = Path(payload.logo_path)
            content_type_value = mimetypes.guess_type(logo_path.name)[0] or "image/jpeg"
            message["attachments"] = [
                {
                    "@odata.type": "#microsoft.graph.fileAttachment",
                    "name": logo_path.name,
                    "contentType": content_type_value,
                    "contentBytes": base64.b64encode(logo_path.read_bytes()).decode("ascii"),
                    "isInline": True,
                    "contentId": "app_logo",
                }
            ]
        return message

    async def send(self, payload: EmailPayload) -> bool:
        try:
            async with httpx.AsyncClient(
                timeout=20.0,
                transport=self.transport,
            ) as client:
                token = await self._get_access_token(client)
                response = await client.post(
                    "https://graph.microsoft.com/v1.0/users/"
                    f"{quote(self.sender_email, safe='')}/sendMail",
                    headers={"Authorization": f"Bearer {token}"},
                    json={
                        "message": self._message(payload),
                        "saveToSentItems": True,
                    },
                )
                response.raise_for_status()
            logger.info(
                "Microsoft Graph accepted email sender=%s recipient=%s",
                self.sender_email,
                payload.to_email,
            )
            return True
        except (httpx.HTTPError, ValueError, TypeError):
            logger.exception(
                "Microsoft Graph email failed sender=%s recipient=%s",
                self.sender_email,
                payload.to_email,
            )
            return False


_cached_sender: EmailSender | None = None


def get_email_sender() -> EmailSender:
    """Return the configured process-wide email sender."""
    global _cached_sender
    if _cached_sender is not None:
        return _cached_sender

    provider = settings.email_provider.strip().casefold()
    if provider in {"microsoft_graph", "graph"}:
        graph_values = {
            "tenant_id": settings.microsoft_graph_tenant_id,
            "client_id": settings.microsoft_graph_client_id,
            "client_secret": settings.microsoft_graph_client_secret,
            "sender_email": settings.microsoft_graph_sender_email,
        }
        missing = [name for name, value in graph_values.items() if not value.strip()]
        if missing:
            raise RuntimeError(
                "Microsoft Graph email configuration is incomplete: " + ", ".join(missing)
            )
        _cached_sender = MicrosoftGraphEmailSender(**graph_values)
        logger.info(
            "Email sender configured for Microsoft Graph mailbox=%s",
            settings.microsoft_graph_sender_email,
        )
        return _cached_sender

    if provider not in {"auto", "smtp", "logging"}:
        raise RuntimeError(f"Unsupported EMAIL_PROVIDER value: {settings.email_provider!r}")
    if provider == "logging":
        _cached_sender = LoggingEmailSender()
        return _cached_sender

    if settings.smtp_username and settings.smtp_password:
        _cached_sender = SMTPEmailSender(
            settings.smtp_host,
            settings.smtp_port,
            settings.smtp_username,
            settings.smtp_password,
        )
        logger.info("Email sender configured for SMTP")
    else:
        _cached_sender = LoggingEmailSender()
        logger.info("Email sender configured for logging; SMTP credentials are absent")
    return _cached_sender
