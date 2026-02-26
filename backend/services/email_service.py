# backend/services/email_service.py

from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
from config import Config

def send_email(to_email, subject, message, client_name=None):
    """
    Send a professional formatted email using SendGrid
    """
    try:
        sg = SendGridAPIClient(Config.SENDGRID_API_KEY)

        # Professional HTML template
        html_content = f"""
        <div style="font-family: Arial, sans-serif; color: #333;">
            <p>Dear {client_name or 'Client'},</p>
            <p>{message}</p>
            <br>
            <p>Best regards,<br>
            Your Legal Team</p>
        </div>
        """

        email = Mail(
            from_email=Config.FROM_EMAIL,
            to_emails=to_email,
            subject=subject,
            html_content=html_content
        )

        response = sg.send(email)
        return {"success": True, "status_code": response.status_code}

    except Exception as e:
        return {"success": False, "error": str(e)}