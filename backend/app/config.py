import os


class Config:
    BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    DATA_DIR = os.path.join(BASE_DIR, "data")

    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key")
    SQLALCHEMY_DATABASE_URI = os.getenv(
        "DATABASE_URL",
        f"sqlite:///{os.path.join(DATA_DIR, 'medication_reminder.db').replace(os.sep, '/')}",
    )
    SQLALCHEMY_TRACK_MODIFICATIONS = False

    TWILIO_ACCOUNT_SID = os.getenv("TWILIO_ACCOUNT_SID")
    TWILIO_AUTH_TOKEN = os.getenv("TWILIO_AUTH_TOKEN")
    TWILIO_SMS_FROM = os.getenv("TWILIO_SMS_FROM")
    TWILIO_WHATSAPP_FROM = os.getenv("TWILIO_WHATSAPP_FROM")
    DEFAULT_CAREGIVER_NOTIFICATION_CHANNEL = os.getenv(
        "DEFAULT_CAREGIVER_NOTIFICATION_CHANNEL", "sms"
    )
    CAREGIVER_OTP_EXPIRY_MINUTES = int(
        os.getenv("CAREGIVER_OTP_EXPIRY_MINUTES", "10")
    )
    CAREGIVER_OTP_MAX_ATTEMPTS = int(
        os.getenv("CAREGIVER_OTP_MAX_ATTEMPTS", "5")
    )
    DEFAULT_TIMEZONE = os.getenv("DEFAULT_TIMEZONE", "Asia/Kolkata")
    REMINDER_FINAL_STATUS_DELAY_SECONDS = int(
        os.getenv("REMINDER_FINAL_STATUS_DELAY_SECONDS", "60")
    )
