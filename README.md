# Elder-Friendly Medication Reminder App

Starter repository for a free-first medication reminder app built with Flutter, Flask, and PostgreSQL.

## Stack

- Frontend: Flutter
- Backend: Flask
- Database: PostgreSQL in production, SQLite for local development
- TTS: `flutter_tts` using the device speech engine
- Notifications: local device notifications
- SMS: device SMS plugin for caregiver updates

## Project Structure

- `backend/` Flask API for users, medications, reminders, caregivers, and adherence logs
- `frontend/` Flutter mobile app shell with elder-friendly UI foundations

## MVP Features

- Create medications and reminder schedules
- View upcoming reminders
- Mark a reminder as done or snoozed
- Store adherence logs
- Track caregiver contact details
- Prepare app for local notifications, TTS, and device SMS

## Backend Quick Start

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python run.py
```

Default API URL: `http://127.0.0.1:5000`

## Frontend Quick Start

```bash
cd frontend
flutter pub get
flutter run
```

## Recommended Next Build Steps

1. Add local notifications and `flutter_tts` reminder playback.
2. Add local SQLite storage on the Flutter side.
3. Connect Flutter screens to the Flask API.
4. Add SMS sending through a device SMS plugin after reminder completion.
5. Add authentication and caregiver onboarding.
