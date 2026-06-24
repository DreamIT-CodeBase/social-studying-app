import asyncio
from app.services.email import get_email_sender, EmailPayload
from app.services.email_templates import get_invite_email_html
import os

async def main():
    sender = get_email_sender()
    html_text = get_invite_email_html("Test User", "Test Workspace", "socialstudy://app/join?workspace=123")
    
    project_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    logo_path = os.path.join(project_root, "flutter_app", "assets", "branding", "app_logo.jpg")
    print(f"Testing logo path: {logo_path}")
    print(f"Logo exists: {os.path.exists(logo_path)}")
    
    payload = EmailPayload(
        to_email="tarunjuneja471@gmail.com",
        subject="Test HTML Email with Logo CID",
        body_text="Plain text fallback",
        body_html=html_text,
        logo_path=logo_path if os.path.exists(logo_path) else None
    )
    
    success = await sender.send(payload)
    print(f"Success: {success}")

if __name__ == "__main__":
    asyncio.run(main())
