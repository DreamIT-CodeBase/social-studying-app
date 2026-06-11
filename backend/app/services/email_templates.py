def get_invite_email_html(display_name: str, workspace_name: str, magic_link: str) -> str:
    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>You've been invited to Social Study</title>
        <style>
            body {{
                font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                background-color: #f3f4f6;
                margin: 0;
                padding: 0;
                -webkit-font-smoothing: antialiased;
            }}
            .container {{
                max-width: 600px;
                margin: 40px auto;
                background-color: #ffffff;
                border-radius: 16px;
                overflow: hidden;
                box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            }}
            .header {{
                background: linear-gradient(135deg, #4F46E5 0%, #7C3AED 100%);
                padding: 40px 20px;
                text-align: center;
            }}
            .logo-placeholder {{
                width: 64px;
                height: 64px;
                background-color: white;
                border-radius: 16px;
                display: inline-flex;
                align-items: center;
                justify-content: center;
                font-size: 24px;
                font-weight: bold;
                color: #4F46E5;
                margin-bottom: 20px;
                box-shadow: 0 4px 12px rgba(0,0,0,0.1);
            }}
            .header h1 {{
                color: #ffffff;
                margin: 0;
                font-size: 28px;
                font-weight: 700;
                letter-spacing: -0.5px;
            }}
            .content {{
                padding: 40px;
                color: #374151;
                font-size: 16px;
                line-height: 1.6;
            }}
            .greeting {{
                font-size: 20px;
                font-weight: 600;
                color: #111827;
                margin-bottom: 24px;
            }}
            .workspace-card {{
                background-color: #f8fafc;
                border: 1px solid #e2e8f0;
                border-radius: 12px;
                padding: 24px;
                margin: 32px 0;
                text-align: center;
            }}
            .workspace-name {{
                font-size: 22px;
                font-weight: 700;
                color: #0f172a;
                margin: 0;
            }}
            .button-container {{
                text-align: center;
                margin: 40px 0;
            }}
            .button {{
                display: inline-block;
                background-color: #4F46E5;
                color: #ffffff !important;
                text-decoration: none;
                padding: 16px 32px;
                border-radius: 9999px;
                font-weight: 600;
                font-size: 16px;
                transition: background-color 0.2s;
                box-shadow: 0 4px 6px rgba(79, 70, 229, 0.2);
            }}
            .button:hover {{
                background-color: #4338CA;
            }}
            .footer {{
                background-color: #f9fafb;
                padding: 24px 40px;
                text-align: center;
                color: #6b7280;
                font-size: 14px;
                border-top: 1px solid #e5e7eb;
            }}
            .trouble-link {{
                color: #4F46E5;
                text-decoration: underline;
                font-size: 14px;
                word-break: break-all;
            }}
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <!-- Inline attachment from backend -->
                <img src="cid:app_logo" alt="Social Study Logo" width="64" height="64" style="border-radius: 16px; margin-bottom: 20px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);">
                <h1>You've Been Invited!</h1>
            </div>
            <div class="content">
                <div class="greeting">Hi {display_name},</div>
                <p>Great news! You have been invited to join a workspace on <strong>Social Study</strong>. Your instructor or admin has already set everything up for you.</p>
                
                <div class="workspace-card">
                    <p style="margin-top: 0; color: #64748b; font-size: 14px; text-transform: uppercase; letter-spacing: 1px; font-weight: 600;">Workspace</p>
                    <h2 class="workspace-name">{workspace_name}</h2>
                </div>

                <p>Click the button below on your mobile device to securely accept your invitation and sign in to the app.</p>
                
                <div class="button-container">
                    <a href="{magic_link}" class="button">Accept Invitation</a>
                </div>
                
                <p style="margin-bottom: 0;">Welcome aboard,<br><strong>The Social Study Team</strong></p>
            </div>
            <div class="footer">
                <p>Having trouble clicking the button? Copy and paste this link into your browser:</p>
                <a href="{magic_link}" class="trouble-link">{magic_link}</a>
            </div>
        </div>
    </body>
    </html>
    """
