# 🔴 Lal Bus — Dhaka University Bus Tracking App

[![Flutter](https://img.shields.io/badge/Flutter-v3.13.0+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Realtime--Database--Firestore-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

"Lal Bus" (Red Bus) is the heart of Dhaka University's transportation. This app allows students and drivers to see exactly where their bus is in real-time, helping everyone save time and avoid missing their ride.

---

## 🌟 What this app does
- **See Live Buses:** Open the map and see moving icons representing actual buses on the road.
- **Find My Bus:** Search for your specific bus stop and see every bus that will pass through it.
- **Check Schedules:** View the official timetables for all 17+ University routes.
- **Get Alerts:** Receive notifications about delays, route changes, or special announcements.

---

## 🎨 Setup Guide (Easy Version)

Even if you aren't a computer scientist, you can set this up! Just follow these steps:

### 1. Basic Tools
- **Install Flutter:** Follow the [official guide](https://docs.flutter.dev/get-started/install) to install Flutter on your computer. This is the "engine" that runs the app.
- **Get a Code Editor:** Download [VS Code](https://code.visualstudio.com/). It's like Microsoft Word but for code.

### 2. Get the Code
- Download this project as a ZIP file from GitHub and extract it on your computer.

### 3. Create your own "Engine Control Room" (Firebase)
The app needs a "brain" to store data. We use Google Firebase for this.
1. Go to the [Firebase Console](https://console.firebase.google.com/) and click **"Add project"**. Name it "Lal Bus".
2. **Enable Services:**
   - **Authentication:** Turn on "Email/Password" and "Google" login options.
   - **Firestore Database:** Create a database (choose "Singapore" or `asia-southeast1` for the fastest speed in Bangladesh).
   - **Realtime Database:** Create this too. This is what makes the buses move on the map!
3. **Connect the App:**
   - Click the Android icon in Firebase to add an Android app.
   - Use `com.masad.lal_bus` as the package name.
   - Download the `google-services.json` file they give you.
   - **Important:** Copy that file into the `android/app/` folder inside this project.

### 4. Put in your Security Keys
To keep things safe, I've hidden the secret keys. You need to put your own in:
1. **The Secrets File:**
   - Find the file `lib/config/secrets.dart.example`.
   - Rename it to just `secrets.dart`.
   - Open it and replace `YOUR_FIREBASE_RTDB_URL` with the URL of your Realtime Database (you'll find this in the Firebase Console).
   - Replace `YOUR_PROJECT_ID` with your Firebase Project ID.
2. **The Firebase Options File:**
   - Open `lib/firebase_options.dart`.
   - Look for the `android` section and fill in the values (API Key, App ID, etc.) that you got from the Firebase Console.
3. **The Configuration Files:**
   - Open `firebase.json` and `.firebaserc` in the main folder.
   - Replace `YOUR_PROJECT_ID` and `YOUR_APP_ID` with your actual project details.

### 5. Start the App!
1. Open a "Terminal" (like a command prompt) in your project folder.
2. Type `flutter pub get` and press Enter. This downloads the "parts" the app needs.
3. Type `flutter run` and press Enter. If you have a phone connected or an emulator open, the app will start!

---

## 🛠️ Technical Details (For the curious)
- **Framework:** Flutter (cross-platform)
- **Maps:** OpenStreetMap (Free and open!)
- **Location:** Crowd-sourced. When a student is "On a bus", they can opt-in to share their GPS location anonymously, which then shows up on everyone else's map.

---

## 📄 License
This project is open-source under the MIT License.

Built with ❤️ for the students of Dhaka University.
