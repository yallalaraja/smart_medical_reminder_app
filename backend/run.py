from dotenv import load_dotenv
import os
from app import create_app

# Load environment variables from your .env
load_dotenv(dotenv_path=r"D:\2026 Python FS Practice\real_world_projects\smart_medical_reminder_app\backend\.env")

# Optional: check if vars are loaded
print("TWILIO_ACCOUNT_SID:", os.getenv("TWILIO_ACCOUNT_SID"))
print("TWILIO_AUTH_TOKEN:", os.getenv("TWILIO_AUTH_TOKEN"))
print("TWILIO_WHATSAPP_FROM:", os.getenv("TWILIO_WHATSAPP_FROM"))
print("TWILIO_SMS_FROM:", os.getenv("TWILIO_SMS_FROM"))

app = create_app()

if __name__ == "__main__":
    app.run(debug=True)