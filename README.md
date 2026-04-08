# Smart Reminder App

A Flutter + Flask reminder application for medicine, routines, study, meals, and other daily tasks. The project supports voice alerts, custom local alarm audio, caregiver onboarding with OTP verification, delayed caregiver notifications, and timezone-aware reminder handling.

## Current Features

- Create one-time or repeating reminders
- Support daily, weekdays, weekends, and custom-day schedules
- Use text-to-speech or a selected local audio file for reminder alerts
- Mark reminders as done, snooze them, or mark them as missed
- Add caregivers with OTP-based verification
- Notify only accepted caregivers through Twilio SMS or WhatsApp
- Delay final caregiver notification after a trigger so the final status can settle
- Store backend timestamps in UTC and return localized timestamps based on the user timezone

## Tech Stack

- Frontend: Flutter
- Backend: Flask
- Database: SQLite for local development, PostgreSQL-ready models
- Notifications: `flutter_local_notifications`
- Voice: `flutter_tts`
- Audio playback: `audioplayers`
- File picking: `file_picker`
- SMS / WhatsApp: Twilio
- Timezone detection: `flutter_timezone`

## Project Structure

- `backend/`
  Flask API, models, routes, services, and Twilio/caregiver logic
- `frontend/`
  Flutter app with reminder screens, caregiver screens, services, and platform folders

## Backend Overview

Important modules:

- `backend/app/models.py`
  User, Caregiver, Reminder, and AdherenceLog models
- `backend/app/routes/`
  API endpoints for users, caregivers, reminders, logs, and health checks
- `backend/app/services/`
  Reminder serialization, caregiver OTP handling, timezone utilities, notification sending, and delayed evaluation

Important backend behaviors:

- User timezone is stored on the `User` model
- Reminder trigger time is stored in UTC
- After a reminder is triggered, a delayed evaluation decides whether the final result is completed or missed
- Only caregivers with status `accepted` receive notifications

## Frontend Overview

Important areas:

- `frontend/lib/screens/home_screen.dart`
  Main reminder dashboard
- `frontend/lib/screens/add_reminder_screen.dart`
  Reminder creation and editing
- `frontend/lib/screens/caregivers_screen.dart`
  Caregiver list, statuses, resend OTP, and verification entry point
- `frontend/lib/screens/verify_caregiver_screen.dart`
  OTP verification screen
- `frontend/lib/services/`
  Reminder APIs, caregiver APIs, notification service, TTS, audio playback, timezone sync

## Caregiver Verification Flow

1. User adds a caregiver in the Flutter app
2. Backend stores the caregiver as `pending`
3. Backend generates an OTP and sends it through Twilio SMS
4. Caregiver OTP is entered in the app
5. Backend verifies the OTP
6. Caregiver becomes `accepted`
7. Only then will caregiver alerts be sent

## Delayed Caregiver Notification Flow

1. Reminder triggers
2. Backend stores `last_triggered_at` in UTC
3. A delayed background evaluation starts
4. After the configured delay, the backend checks the latest reminder log
5. Final status becomes:
   - `completed`, if the user marked it done
   - `missed`, if there was no completion response
6. Backend sends the final localized message only to accepted caregivers

## Timezone Behavior

- Backend stores timestamps in UTC
- Frontend detects the device timezone
- Frontend sends that timezone to the backend
- API responses return localized times based on the saved user timezone
- Caregiver invite and OTP expiry times are also shown in localized form in the UI

## Backend Setup

From the project root:

```powershell
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python run.py
```

Backend default URL:

```text
http://127.0.0.1:5000
```

## Backend Environment Variables

Create `backend/.env` with values like:

```env
SECRET_KEY=dev-secret-key
DATABASE_URL=sqlite:///data/medication_reminder.db

TWILIO_ACCOUNT_SID=your_account_sid
TWILIO_AUTH_TOKEN=your_auth_token
TWILIO_SMS_FROM=+1xxxxxxxxxx
TWILIO_WHATSAPP_FROM=whatsapp:+14155238886

DEFAULT_CAREGIVER_NOTIFICATION_CHANNEL=sms
DEFAULT_TIMEZONE=Asia/Kolkata
CAREGIVER_OTP_EXPIRY_MINUTES=10
CAREGIVER_OTP_MAX_ATTEMPTS=5
REMINDER_FINAL_STATUS_DELAY_SECONDS=60
```

## Frontend Setup

```powershell
cd frontend
flutter pub get
flutter run
```

For Android emulator API access, the app uses:

```text
http://10.0.2.2:5000
```

For web or desktop local runs, it uses:

```text
http://127.0.0.1:5000
```

## Notes For Local Development

- If the backend schema changes and local SQLite becomes stale, delete:
  `backend/data/medication_reminder.db`
- Then restart Flask so tables are recreated
- If Twilio is not configured, caregiver creation and missed flows still work, but notifications will return an error in the response payload instead of being delivered

## Example API Endpoints

- `POST /api/users`
- `PUT /api/users/<id>/timezone`
- `POST /api/caregivers`
- `GET /api/users/<user_id>/caregivers`
- `POST /api/caregivers/verify-otp`
- `POST /api/caregivers/<id>/resend-invitation`
- `POST /api/caregivers/<id>/reject`
- `POST /api/reminders`
- `PUT /api/reminders/<id>/trigger`
- `POST /api/reminders/<id>/missed`
- `POST /api/logs`
- `GET /api/dashboard/<user_id>`

## Current Status

This project is beyond the initial scaffold stage and already includes:

- reminder CRUD
- caregiver onboarding
- OTP verification
- Twilio-ready caregiver alerts
- timezone-aware behavior
- delayed final reminder evaluation

## Suggested Next Improvements

1. Add a reminder history screen for completed/missed events
2. Replace the simple thread-based delayed evaluator with Celery or a scheduler for stronger production reliability
3. Add authentication for users and caregivers
4. Add edit/delete caregiver actions
5. Improve background reliability for Android alarm playback
