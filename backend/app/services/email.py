"""Email dispatch service.

Sends transactional emails like workspace invitations. Defaults to a 
logging sender for local development. Can be extended to use SendGrid,
Postmark, or an SMTP server via environment variables.
"""

import logging
from abc import ABC, abstractmethod
from pydantic import BaseModel

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
        """Dispatch an email. Returns True if successful."""
        pass

class LoggingEmailSender(EmailSender):
    """Local development sender. Logs emails to stdout instead of sending them."""
    async def send(self, payload: EmailPayload) -> bool:
        print(
            "\\n=== OUTBOUND EMAIL ==="
            "\\nTo: %s"
            "\\nSubject: %s"
            "\\nBody:\\n%s"
            "\\n======================" % (
                payload.to_email,
                payload.subject,
                payload.body_text,
            )
        )
        return True

import smtplib
from email.message import EmailMessage
from fastapi.concurrency import run_in_threadpool
from app.core.config import settings

class SMTPEmailSender(EmailSender):
    """Sends emails via an SMTP server (e.g., Gmail)."""
    def __init__(self, host: str, port: int, username: str, password: str):
        self.host = host
        self.port = port
        self.username = username
        self.password = password

    def _send_sync(self, payload: EmailPayload) -> bool:
        from email.message import EmailMessage
        import os
        from email.utils import make_msgid
        
        msg = EmailMessage()
        msg['Subject'] = payload.subject
        msg['From'] = self.username
        msg['To'] = payload.to_email
        msg.set_content(payload.body_text)
        
        if payload.body_html:
            msg.add_alternative(payload.body_html, subtype='html')
            
            # If there's a logo, attach it as a related inline image
            if payload.logo_path and os.path.exists(payload.logo_path):
                with open(payload.logo_path, 'rb') as img:
                    img_data = img.read()
                
                # Get the HTML part to attach the image to
                html_part = msg.get_payload()[1]
                html_part.add_related(img_data, 'image', 'jpeg', cid='<app_logo>')

        try:
            with smtplib.SMTP(self.host, self.port) as server:
                server.starttls()
                server.login(self.username, self.password)
                server.send_message(msg)
            return True
        except Exception as e:
            logger.error("SMTP email failed: %s", e)
            return False

    async def send(self, payload: EmailPayload) -> bool:
        return await run_in_threadpool(self._send_sync, payload)

_cached_sender: EmailSender | None = None

def get_email_sender() -> EmailSender:
    """Return the configured email sender."""
    global _cached_sender
    if _cached_sender is not None:
        return _cached_sender
    
    # If SMTP credentials exist in settings, use them. Otherwise, fallback to logging.
    smtp_user = getattr(settings, "smtp_username", None)
    smtp_pass = getattr(settings, "smtp_password", None)
    
    if smtp_user and smtp_pass:
        smtp_host = getattr(settings, "smtp_host", "smtp.gmail.com")
        smtp_port = getattr(settings, "smtp_port", 587)
        _cached_sender = SMTPEmailSender(smtp_host, smtp_port, smtp_user, smtp_pass)
        logger.info("EmailSender configured to use SMTP")
    else:
        _cached_sender = LoggingEmailSender()
        logger.info("EmailSender configured to use Logging (no SMTP credentials found)")
        
    return _cached_sender
