from email.message import EmailMessage
import secrets
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from django.utils.html import strip_tags
from django.conf import settings
from .models import User, OneTimePassword ,PasswordResetOTP
from django.template.loader import render_to_string
import pytz
from django.utils import timezone


def generate_otp(length=6):
    """Generate a secure numeric OTP."""
    return ''.join(secrets.choice("0123456789") for _ in range(length))

def send_code_to_user(email):
    """Send an OTP email using an HTML template."""
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return {"success": False, "message": "User with this email does not exist."}

    otp = generate_otp()
    OneTimePassword.objects.create(user=user, code=otp)

    # Load email template
    context = {
        "user": user,
        "otp_code": otp
    }
    subject = "OTP Verification"
    from_email = settings.EMAIL_HOST_USER
    html_content = render_to_string("emails/otp_email.html", context)  # HTML template
    text_content = strip_tags(html_content)  # Fallback for email clients that don't support HTML

    # Send email
    email_message = EmailMultiAlternatives(subject, text_content, from_email, [email])
    email_message.attach_alternative(html_content, "text/html")
    email_message.send(fail_silently=False)

    return {"success": True, "message": "OTP sent successfully."}


def send_password_reset_code_to_user(email):
    """Send an OTP email using an HTML template."""
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return {"success": False, "message": "User with this email does not exist."}

    otp = generate_otp()
    PasswordResetOTP.objects.create(user=user, code=otp)

    # Load email template
    context = {
        "user": user,
        "otp_code": otp
    }
    subject = "OTP for passward change"
    from_email = settings.EMAIL_HOST_USER
    html_content = render_to_string("emails/otp_email_password.html", context)  # HTML template
    text_content = strip_tags(html_content)  # Fallback for email clients that don't support HTML

    # Send email
    email_message = EmailMultiAlternatives(subject, text_content, from_email, [email])
    email_message.attach_alternative(html_content, "text/html")
    email_message.send(fail_silently=False)

    return {"success": True, "message": "OTP sent successfully."}

