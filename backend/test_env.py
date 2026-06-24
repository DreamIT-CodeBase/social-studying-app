import asyncio
from app.core.config import settings

def main():
    print(f"SMTP Username: {settings.smtp_username}")
    print(f"SMTP Password: {settings.smtp_password}")
    
    smtp_user = getattr(settings, "smtp_username", None)
    smtp_pass = getattr(settings, "smtp_password", None)
    if smtp_user and smtp_pass:
        print("Will use SMTP!")
    else:
        print("Will use Logging!")

if __name__ == "__main__":
    main()
