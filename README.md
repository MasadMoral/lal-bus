# 🔴 Lal Bus — ঢাকা বিশ্ববিদ্যালয় বাস ট্র্যাকিং অ্যাপ

A real-time crowd-sourced bus tracking app for Dhaka University students.

## Features

- 🗺️ **Live Tracking** — Crowd-sourced GPS tracking. Riders share their location, others see the bus on the map in real time.
- 🕐 **Schedule** — Full timetable for all 17 DU bus routes with stop-wise arrival times.
- 📍 **Stop Map** — Interactive map showing all stops for any route.
- 📢 **Notices** — General and bus-specific notices with role-based admin posting.
- ❤️ **Favorites** — Save your buses, get relevant notices first.
- 🔐 **Auth** — DU email (@du.ac.bd) via Google, or manual email/password accounts.

## Tech Stack

- **Flutter** (Android)
- **Firebase** — Auth, Firestore, Realtime Database
- **OpenStreetMap** via flutter_map
- **Geolocator** for GPS

## Setup Guide

### 1. Clone the repo
```bash
git clone https://github.com/MasadMoral/lal-bus.git
cd lal-bus
```

### 2. Create a Firebase project

1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Create a new project
3. Enable these services:
   - **Authentication** → Google + Email/Password
   - **Firestore Database**
   - **Realtime Database** (note the region URL)

### 3. Add Firebase config files

Run FlutterFire CLI to generate `lib/firebase_options.dart`:
```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_PROJECT_ID
```

Download `google-services.json` from Firebase Console → Project Settings → Android app and place it in `android/app/`.

### 4. Add the Realtime Database URL

In `lib/firebase_options.dart`, make sure `databaseURL` is set to your RTDB URL:
```dart
databaseURL: 'https://YOUR_PROJECT_ID-default-rtdb.REGION.firebasedatabase.app',
```

### 5. Add Google Maps API Key

In `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY"/>
```

Get a key from [Google Cloud Console](https://console.cloud.google.com) → Maps SDK for Android.

### 6. Install dependencies and run
```bash
flutter pub get
flutter run
```

### 7. Set up admin users

In Firebase Console → Firestore → `users` collection, set a user's role:
```
role: "admin"         → full access
role: "bus_admin"     → can post notices for their bus only
busId: "kinchit"      → which bus they admin (for bus_admin)
```

## Firestore Structure
```
users/
  {uid}: { email, displayName, role, busId, favorites[] }

notices/
  general/posts/{id}: { title, body, pinned, date, authorName }
  buses/{busId}/{id}: { title, body, pinned, date, authorName }
```

## Realtime Database Structure
```
buses/
  {busId}/
    users/
      {uid}: { lat, lng, accuracy, timestamp, displayName }
```

## Bus Routes

17 routes including: Kinchit, Choitaly, Shrabon, Taranga, Basanta, Boishakhi, Khonika, Hemonto, Ullash, Falguni, Isha Kha, Maitree, Wari-Bateshwar, Idrakpur, Bikrampur, Ananda, Shitalakhya.

## Contributing

MIS or CSE students interested in contributing — especially for official GPS integration (ESP32 + GPS module on each bus) — please open an issue or contact via Facebook.

## License

MIT — free to use, modify, and distribute.

---

Built with ❤️ for Dhaka University students.
