import smtplib
from email.message import EmailMessage

from . import config


class MailError(Exception):
    pass


def configured() -> bool:
    return bool(config.SMTP_USER and config.SMTP_PASSWORD)


def send_code(email: str, name: str, code: str) -> None:
    msg = EmailMessage()
    msg["Subject"] = f"{code} is your Kognitiv code"
    msg["From"] = f"Kognitiv <{config.SMTP_FROM}>"
    msg["To"] = email
    msg.set_content(
        f"Hi {name},\n\nYour Kognitiv verification code is {code}.\n"
        "It expires in 10 minutes.\n\nIf you didn't ask for this, ignore this email.\n"
    )
    try:
        with smtplib.SMTP(config.SMTP_HOST, config.SMTP_PORT, timeout=15) as smtp:
            smtp.starttls()
            smtp.login(config.SMTP_USER, config.SMTP_PASSWORD)
            smtp.send_message(msg)
    except (smtplib.SMTPException, OSError) as e:
        raise MailError(str(e)) from e
