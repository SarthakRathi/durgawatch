# DurgaWatch

<div align="center">

![DurgaWatch Logo](assets/images/logo.png)

**A Smart Personal Safety Application with Multi-Stage Alert System**

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

## 📋 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Security & Privacy](#security--privacy)
- [Technical Stack](#technical-stack)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

DurgaWatch is a comprehensive personal safety application that provides intelligent, multi-stage emergency response capabilities. The app uses advanced AI-powered voice and motion detection to automatically escalate alerts based on threat severity, ensuring users can quickly get help when they need it most.

### The Problem We Solve

Traditional emergency apps require manual activation, which may not be possible during critical situations. DurgaWatch addresses this by:
- **Automatic Threat Detection**: Voice and motion-based triggers
- **Progressive Alert System**: Three escalating stages of response
- **Real-time Location Sharing**: Approximate and precise location modes
- **Contact Network**: Automatic notification of emergency contacts
- **Police Integration**: Dedicated interface for law enforcement

## ✨ Key Features

### 🚨 Three-Stage Alert System

#### Stage 1: Initial Alert (10 seconds)
- Initial warning phase
- User has time to cancel if false alarm
- No location sharing yet
- Activated by: Manual, Voice command, or Motion detection

#### Stage 2: Enhanced Security (5 minutes)
- Approximate location shared (~20-30m radius)
- SMS alerts sent to emergency contacts
- Video/audio recording begins (configurable)
- Location updates every 5 seconds
- Red circle displayed on real-time map

#### Stage 3: Maximum Security
- Precise GPS location shared
- Full emergency response activated
- Direct SMS to emergency contacts with exact location
- Continuous video/audio recording
- Red marker on real-time map
- Automatic dialer fallback if no network coverage

### 🤖 AI-Powered Detection

- **Voice Recognition**: Gemini AI analyzes speech patterns for distress
- **Custom Trigger Phrases**: User-configurable emergency words (default: "help")
- **Motion Detection**: Accelerometer-based shake detection
- **Pitch Analysis**: Real-time frequency detection for anomalies

### 📱 Core Functionality

- **Real-time Threat Map**: View active threats with different visualization for Stage 2 (circles) and Stage 3 (markers)
- **Emergency Contacts Management**: Store phone numbers and email contacts
- **Profile Management**: Upload photos, edit details
- **Video Recording**: Automatic recording during Stage 2/3 with cloud upload
- **Police View**: Dedicated interface for law enforcement to monitor active threats
- **User Search**: Police can search users by email to view their threat history
- **Settings Customization**: Configure stage durations, trigger phrases, and data sharing preferences

## 🏗️ Architecture

### System Design

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                        │
├─────────────────────────────────────────────────────────────┤
│  Home │ Profile │ Contacts │ Map │ Settings │ Police View   │
└────┬────────────────────────────────────────────────────────┘
     │
     ├──> Alert Mode Toggle
     │    ├─> Voice Detection (STT + Gemini AI)
     │    ├─> Motion Detection (Accelerometer)
     │    └─> Pitch Detection (FFT Analysis)
     │
     ├──> Stage Management System
     │    ├─> Stage 1 Timer (auto-escalate to 2)
     │    ├─> Stage 2 Timer + Location + Recording
     │    └─> Stage 3 Precise Location + SMS
     │
     ├──> Firebase Services
     │    ├─> Authentication
     │    ├─> Firestore (user data, threats, contacts)
     │    └─> Storage (recordings, profile photos)
     │
     └──> Device Services
          ├─> Camera (video recording)
          ├─> GPS (location tracking)
          ├─> SMS (emergency notifications)
          └─> Network Detection (fallback to dialer)
```

### Data Structure

#### Firestore Collections

```
/users/{uid}
  - fullName
  - email
  - phone
  - address
  - photoUrl
  - createdAt
  
  /settings/stages
    - stage1Time
    - stage2Time
    - triggerPhrase
    - stage2SendLocation
    - stage2SendVideo
    - stage2SendAudio
    - stage2AccurateLocation
    - stage3SendLocation
    - stage3SendVideo
    - stage3SendAudio
  
  /contacts/{contactId}
    - type: "phone" | "email"
    - phone (if type=phone)
    - email (if type=email)
    - uid (if type=email)
    - createdAt

/threats/{uid}
  - userId
  - userName
  - isActive
  - stageNumber
  - activationMode: "manual" | "voice" | "motion" | "ai"
  - lat
  - lng
  - recordingUrl
  - alertContacts (array of UIDs)
  - updatedAt
  
  /history/{historyId}
    - stageNumber
    - activationMode
    - lat
    - lng
    - isActive: false
    - recordingUrl
    - timestamp
```

## 🚀 Installation

### Prerequisites

- Flutter SDK (3.0 or higher)
- Dart SDK (2.18 or higher)
- Android Studio / Xcode
- Firebase account
- Gemini API key

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/durgawatch.git
cd durgawatch
```

### Step 2: Install Dependencies

```bash
flutter pub get
```

### Step 3: Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
2. Add Android and/or iOS apps to your Firebase project
3. Download and add configuration files:
   - Android: `google-services.json` → `android/app/`
   - iOS: `GoogleService-Info.plist` → `ios/Runner/`

4. Enable Firebase services:
   - Authentication (Email/Password)
   - Cloud Firestore
   - Firebase Storage

5. Set up Firestore Security Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
      
      match /settings/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      match /contacts/{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
    
    match /threats/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
      
      match /history/{document=**} {
        allow read: if request.auth != null;
        allow write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

### Step 4: Configure API Keys

1. Get a Gemini API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Update the API key in `lib/home_screen.dart`:

```dart
final apiKey = 'YOUR_GEMINI_API_KEY_HERE';
```

### Step 5: Configure Android Permissions

Ensure `android/app/src/main/AndroidManifest.xml` includes:

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.READ_PHONE_STATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

### Step 6: Build and Run

```bash
# For Android
flutter run

# For iOS
cd ios && pod install && cd ..
flutter run
```

## ⚙️ Configuration

### Customizing Stage Timers

Navigate to **Settings** in the app to configure:
- Stage 1 duration (default: 10 seconds)
- Stage 2 duration (default: 300 seconds)
- Emergency trigger phrase (default: "help")

### Data Sharing Preferences

Configure what data to share for each stage:

**Stage 2 Options:**
- Send approximate location
- Send video recording
- Send audio recording
- Use accurate location on global map

**Stage 3 Options:**
- Send precise location
- Send video recording
- Send audio recording

## 📖 Usage

### For Users

1. **Registration**: Create an account with email, phone, and address
2. **Add Contacts**: Add emergency contacts (phone numbers or app users via email)
3. **Configure Settings**: Set stage timers and trigger phrase
4. **Enable Alert Mode**: Toggle the alert mode ON to activate monitoring
5. **Emergency Activation**: 
   - Manually select Stage 1, 2, or 3
   - Say your trigger phrase
   - Shake the device vigorously
   - AI will automatically detect distress in your voice

### For Law Enforcement

1. Navigate to **Police View**
2. View all active Stage 2/3 threats on the dashboard
3. Search for specific users by email
4. View threat history and recordings
5. Access real-time location on the map

### Alert Mode Behavior

When **Alert Mode is ON**:
- App listens for voice commands (15-second sessions)
- Motion detection is active
- Pitch detection analyzes voice frequency
- AI continuously monitors for distress signals

## 🔒 Security & Privacy

### Data Protection

- All user data encrypted in transit and at rest
- Passwords hashed using Firebase Authentication
- Location data only shared during active threats
- Recordings stored securely in Firebase Storage

### Privacy Features

- **Stage 2 Location Obfuscation**: Adds random offset (±20-30 meters) for privacy
- **Stage 3 Precise Location**: Only shared when maximum security is needed
- **Configurable Sharing**: Users control what data is sent at each stage
- **Contact Permissions**: Users explicitly add trusted contacts

### Network Fallback

If no mobile network coverage is detected during Stage 2/3:
- App automatically opens phone dialer with emergency number (112)
- User can make voice call for help

## 🛠️ Technical Stack

### Frontend
- **Flutter**: Cross-platform mobile framework
- **Dart**: Programming language

### Backend Services
- **Firebase Authentication**: User management
- **Cloud Firestore**: Real-time database
- **Firebase Storage**: Media file storage

### AI & ML
- **Google Gemini AI**: Natural language processing for distress detection
- **Speech-to-Text**: Voice command recognition
- **Flutter FFT**: Real-time pitch detection

### Device Features
- **Camera**: Video recording
- **Microphone**: Audio capture and voice detection
- **GPS/Location**: Real-time positioning
- **Accelerometer**: Motion detection
- **SMS**: Emergency notifications
- **Google Maps**: Real-time threat visualization

### Key Packages

```yaml
dependencies:
  firebase_core: ^2.24.2
  firebase_auth: ^4.16.0
  cloud_firestore: ^4.14.0
  firebase_storage: ^11.6.0
  google_maps_flutter: ^2.5.0
  geolocator: ^10.1.0
  camera: ^0.10.5
  video_player: ^2.8.1
  video_compress: ^3.1.2
  speech_to_text: ^6.5.1
  flutter_fft: ^1.0.2
  sensors_plus: ^4.0.0
  telephony: ^0.2.0
  url_launcher: ^6.2.2
  permission_handler: ^11.1.0
  image_picker: ^1.0.7
  http: ^1.1.2
```

## 🤝 Contributing

We welcome contributions! Here's how you can help:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/AmazingFeature`)
3. **Commit your changes** (`git commit -m 'Add some AmazingFeature'`)
4. **Push to the branch** (`git push origin feature/AmazingFeature`)
5. **Open a Pull Request**

### Development Guidelines

- Follow Flutter/Dart style guide
- Write meaningful commit messages
- Add tests for new features
- Update documentation as needed
- Ensure all permissions are properly handled

## 📝 Roadmap

- [ ] Multi-language support
- [ ] iOS platform support
- [ ] Wearable device integration
- [ ] Offline mode with local storage
- [ ] Advanced AI training for better threat detection
- [ ] Integration with local emergency services
- [ ] Geofencing alerts
- [ ] Panic button widget

## 🐛 Known Issues

- Motion detection may trigger on very bumpy rides (adjust threshold in settings)
- Voice detection requires stable internet for AI analysis
- Video recording quality depends on device capabilities

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend infrastructure
- Google Gemini AI for advanced NLP capabilities
- All contributors and supporters of personal safety technology

---

<div align="center">

**Made with ❤️ for personal safety**

</div>
