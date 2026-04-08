import os


class Config:
    @staticmethod
    def _build_database_uri() -> str:
        database_url = os.getenv("DATABASE_URL")
        if database_url:
            if database_url.startswith("postgres://"):
                return database_url.replace("postgres://", "postgresql+psycopg://", 1)
            if database_url.startswith("postgresql://"):
                return database_url.replace(
                    "postgresql://",
                    "postgresql+psycopg://",
                    1,
                )
            return database_url

        db_host = os.getenv("DB_HOST")
        db_port = os.getenv("DB_PORT", "5432")
        db_name = os.getenv("DB_NAME")
        db_user = os.getenv("DB_USER")
        db_password = os.getenv("DB_PASSWORD")

        missing = [
            key
            for key, value in {
                "DATABASE_URL": database_url,
                "DB_HOST": db_host,
                "DB_NAME": db_name,
                "DB_USER": db_user,
                "DB_PASSWORD": db_password,
            }.items()
            if not value
        ][1:]
        if missing:
            missing_keys = ", ".join(missing)
            raise RuntimeError(
                f"Missing PostgreSQL environment variables: {missing_keys}. "
                "Set DATABASE_URL or the split DB_* variables before starting the app."
            )

        return f"postgresql+psycopg://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"

    BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    DATA_DIR = os.path.join(BASE_DIR, "data")
    DEBUG = os.getenv("FLASK_DEBUG", "false").lower() == "true"

    SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key")
    SQLALCHEMY_DATABASE_URI = _build_database_uri()
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        "pool_pre_ping": True,
    }
    JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dev-jwt-secret")
    JWT_ACCESS_TOKEN_EXPIRES = int(os.getenv("JWT_ACCESS_TOKEN_EXPIRES_SECONDS", "86400"))

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
    CREATE_DEMO_USER = os.getenv("CREATE_DEMO_USER", "true").lower() == "true"
    DEMO_USER_ID = os.getenv("DEMO_USER_ID", "a4f9c2d1-7b6e-4c3a-9f21-8d5e7b1c2a34")
    DEMO_USER_NAME = os.getenv("DEMO_USER_NAME", "Demo User")
    DEMO_USER_PHONE = os.getenv("DEMO_USER_PHONE", "9999999999")
    DEMO_USER_PASSWORD = os.getenv("DEMO_USER_PASSWORD", "password123")
