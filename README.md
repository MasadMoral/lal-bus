# 🔴 Lal Bus — Dhaka University Bus Tracking App

[![Flutter](https://img.shields.io/badge/Flutter-v3.13.0+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime--Database--Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A premium, real-time, crowd-sourced bus tracking application specifically designed for the students of Dhaka University. "Lal Bus" (Red Bus) is the heartbeat of DU transportation, and this app ensures you never miss yours.

---

## 🚀 Key Features

- 🗺️ **Live GPS Tracking** — Real-time tracking powered by crowd-sourced location data from riders.
- 👨‍✈️ **Driver Mode** — Simplified, distraction-free interface for drivers with permanent access to live maps and schedules.
- 🕐 **Smart Schedule** — Complete timetables for all 17+ DU bus routes with precise stop-wise arrival estimates.
- 📍 **Interactive Stop Map** — Comprehensive maps visualizing every stop for every route.
- 📢 **Instant Notices** — Stay updated with general and bus-specific announcements.
- 🔐 **Secure Authentication** — Seamless login using DU email (@du.ac.bd) via Google or traditional accounts.
- 🛠️ **Scalable Architecture** — Optimized to handle 10,000+ concurrent users with minimal latency.

---

## ⚡ Recent Performance & UX Improvements

- **Scalability (10k+ Users)**: Implemented throttled UI updates and incremental data listeners (`onChildChanged`) to ensure the app remains smooth under heavy load.
- **Battery Optimization**: Added `distanceFilter` (15m) to the driver-side GPS stream, significantly reducing battery consumption and background data usage.
- **UI Smoothness**: Isolated marker repaints using `RepaintBoundary` to prevent full-map rebuilds on every GPS packet.
- **Safety First**: Added confirmation dialogs for logout and app exit to prevent accidental data loss or tracking termination.

---

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev) (iOS & Android)
- **Backend:** [Firebase](https://firebase.google.com)
  - **Firestore:** Persistent user data, notices, and route information
  - **Realtime Database:** High-velocity GPS coordinate updates
- **Maps:** [OpenStreetMap](https://www.openstreetmap.org/) via `flutter_map`
- **Location:** `geolocator` with optimized 15m distance filtering
- **State Management:** Native `setState` with throttled execution for performance

---

## ⚙️ Setup Guide

### 1. Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.13.0)
- [Firebase account](https://console.firebase.google.com/)

### 2. Clone the Repository
```bash
git clone https://github.com/MasadMoral/rtx_lulbus.git
cd rtx_lulbus
```

### 3. Firebase Configuration
1. Create a new Firebase project (Singapore/`asia-southeast1` recommended for latency).
2. Enable **Authentication** (Google & Email/Password).
3. Create a **Firestore Database** and a **Realtime Database**.
4. Install and run [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup?platform=ios#installing-cli):
   ```bash
   flutterfire configure --project=YOUR_PROJECT_ID
   ```
5. Place `google-services.json` (Android) in `android/app/`.

### 4. Database Setup
Ensure your RTDB security rules allow authenticated users to read and write to the `/buses` node.

### 5. Running the App
```bash
flutter pub get
flutter run
```

---

## 🤝 Contributing

We welcome contributions from the DU community! 
1. Fork the project.
2. Create your Feature Branch (`git checkout -b feature/AmazingFeature`).
3. Commit your changes.
4. Push to the Branch.
5. Open a Pull Request.

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.

---

Built with ❤️ by the DU Student Community.
