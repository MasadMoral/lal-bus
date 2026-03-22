# 🔴 Lal Bus — Dhaka University Bus Tracking App

[![Flutter](https://img.shields.io/badge/Flutter-v3.11.0+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime--Database--Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen.svg)]()

A premium, real-time, crowd-sourced bus tracking application specifically designed for the students of Dhaka University. "Lal Bus" (Red Bus) is the heartbeat of DU transportation, and this app ensures you never miss yours.

---

## 🚀 Features

- 🗺️ **Live GPS Tracking** — Real-time tracking powered by crowd-sourced location data from riders.
- 🕐 **Smart Schedule** — Complete timetables for all 17+ DU bus routes with precise stop-wise arrival estimates.
- 📍 **Interactive Stop Map** — Comprehensive maps visualizing every stop for every route.
- 📢 **Instant Notices** — Stay updated with general and bus-specific announcements posted by admins.
- ❤️ **Personalized Favorites** — Save your regular routes to get tailored notifications and quick access.
- 🔐 **Secure Authentication** — Seamless login using DU email (@du.ac.bd) via Google or traditional accounts.
- 🛠️ **Admin Dashboard** — Role-based access for posting notices and managing bus data.

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev) (iOS & Android)
- **Backend:** [Firebase](https://firebase.google.com)
  - **Auth:** Google Sign-In & Email/Password
  - **Firestore:** Persistent user data, notices, and route information
  - **Realtime Database:** High-velocity GPS coordinate updates
- **Maps:** [OpenStreetMap](https://www.openstreetmap.org/) via `flutter_map`
- **Location:** `geolocator` for high-accuracy GPS tracking
- **Animations:** Custom micro-animations for a premium feel

---

## 📁 Project Structure

```text
lib/
├── main.dart           # App entry point & initialization
├── models/             # Data models (Bus, Route, Stop)
├── screens/            # UI Pages (Home, Map, Login, etc.)
├── services/           # Backend interaction (Auth, Firestore, RTDB)
└── widgets/            # Reusable UI components
```

---

## ⚙️ Setup Guide

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.11.0)
- [Firebase account](https://console.firebase.google.com/)

### 2. Clone the Repository
```bash
git clone https://github.com/MasadMoral/lal-bus.git
cd lal-bus
```

### 3. Firebase Configuration
1. Create a new Firebase project.
2. Enable **Authentication** (Google & Email/Password).
3. Create a **Firestore Database** and a **Realtime Database**.
4. Install and run [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup?platform=ios#installing-cli):
   ```bash
   flutterfire configure --project=YOUR_PROJECT_ID
   ```
5. Place `google-services.json` (Android) in `android/app/`.

### 4. API Keys & Database URL
- **Realtime Database:** Ensure the `databaseURL` is set in `lib/firebase_options.dart`.
- **Google Maps (Android):** Add your API Key in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_API_KEY"/>
  ```

### 5. Running the App
```bash
flutter pub get
flutter run
```

---

## 🚌 Supported Bus Routes

"Lal Bus" covers all major DU routes, including:
- **Major Routes:** Kinchit, Choitaly, Srabon, Taranga, Basanta, Boishakhi, Khonika, Hemonto, Ullash, Falguni, Isha Kha, Maitree, Wari-Bateshwar, Idrakpur, Bikrampur, Ananda, and Shitalakhya.

---

## 🤝 Contributing

We welcome contributions from the DU community! Whether you are a CSE student or just a bus enthusiast:
1. Fork the project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`).
4. Push to the Branch (`git push origin feature/AmazingFeature`).
5. Open a Pull Request.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

Built with ❤️ by the DU Student Community.
