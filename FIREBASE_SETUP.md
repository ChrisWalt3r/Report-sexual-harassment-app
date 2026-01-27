# Firebase Authentication Setup Guide

This guide will help you set up Firebase authentication for the Sexual Harassment Management Application.

## ⚠️ Important: Firebase Credentials Not Included

For security reasons, Firebase configuration files containing API keys and credentials are **NOT** included in this repository. Each contributor must set up their own Firebase project.

### Files You Need to Create

After following this guide, you'll generate these files (they are gitignored):
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist` (if using iOS)
- `macos/Runner/GoogleService-Info.plist` (if using macOS)

## Prerequisites

- Flutter SDK installed
- Firebase account (create one at https://console.firebase.google.com)
- Firebase CLI and FlutterFire CLI installed

## Step 1: Install Firebase CLI

```bash
npm install -g firebase-tools
```

## Step 2: Login to Firebase

```bash
firebase login
```

## Step 3: Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

Make sure the pub global bin directory is in your PATH.

## Step 4: Create a Firebase Project

1. Go to https://console.firebase.google.com
2. Click "Add project"
3. Enter project name (e.g., "sexual-harassment-management")
4. Follow the setup wizard

## Step 5: Configure Firebase for Flutter

Run the following command in your project root:

```bash
flutterfire configure
```

This will:
- Prompt you to select your Firebase project
- Ask which platforms to support (Android, iOS, Web, etc.)
- Automatically generate `firebase_options.dart` with your configuration
- Update platform-specific files with Firebase configuration

## Step 6: Enable Authentication Methods

1. Go to Firebase Console > Your Project
2. Click "Authentication" in the left sidebar
3. Click "Get Started"
4. Click "Sign-in method" tab
5. Enable "Email/Password" authentication

## Step 7: Set Up Firestore Database

1. In Firebase Console, click "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (or production mode with proper rules)
4. Select a location for your database
5. Click "Enable"

### Firestore Security Rules (Recommended)

Update your Firestore rules to secure user data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection - users can only read/write their own data
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Reports collection - authenticated users can create reports
    match /reports/{reportId} {
      allow create: if request.auth != null;
      allow read, update, delete: if request.auth != null && 
        (resource.data.userId == request.auth.uid || 
         request.auth.token.admin == true);
    }
  }
}
```

## Step 8: Update Android Configuration (if needed)

The FlutterFire CLI should handle this automatically, but verify:

1. Check `android/app/build.gradle` has minimum SDK version 21 or higher:
```gradle
minSdkVersion 21
```

2. Verify `android/build.gradle` has Google services plugin

## Step 9: Test the Setup

Run your app:

```bash
flutter run
```

You should now see the login screen and be able to:
- Register new users
- Login with email/password or student ID
- Use Firebase authentication

## Features Implemented

### Authentication Service
- Sign in with email/password
- Sign in with student ID (converted to email format)
- Register new users with university details
- Password reset functionality
- User data stored in Firestore

### Login Screen
- Toggle between Student ID and Email authentication
- Password visibility toggle
- Form validation
- Forgot password option
- Navigation to registration

### Registration Screen
- Full name input
- Student ID input
- Department dropdown
- Phone number input
- Password and confirmation
- Stores user data in Firestore

### Main App
- Firebase initialization
- Authentication state management
- Automatic routing based on login status

## User Data Structure in Firestore

When a user registers, their data is stored in Firestore under `/users/{uid}`:

```javascript
{
  "fullName": "John Doe",
  "email": "john@must.ac.mw",
  "studentId": "MUST2024001",
  "department": "Computer Science",
  "phoneNumber": "+265888123456",
  "createdAt": Timestamp,
  "isVerified": false
}
```

## Troubleshooting

### Error: No Firebase App has been created
- Make sure you ran `flutterfire configure`
- Check that `firebase_options.dart` exists in `lib/`
- Verify Firebase.initializeApp() is called in main()

### Error: Multidex issue (Android)
Add to `android/app/build.gradle`:
```gradle
android {
    defaultConfig {
        multiDexEnabled true
    }
}
```

### Firebase CLI not found
Add pub global bin directory to PATH:
```bash
export PATH="$PATH":"$HOME/.pub-cache/bin"
```

## Next Steps

- Add email verification
- Implement profile photo upload
- Add admin roles for managing users
- Implement reporting system with Firebase
- Add push notifications for incident updates

## Security Considerations

1. **Never commit firebase credentials** - The `firebase_options.dart` file contains API keys
2. **Use proper Firestore security rules** - Don't keep in test mode for production
3. **Implement email verification** before allowing full access
4. **Add rate limiting** to prevent abuse
5. **Monitor Firebase usage** to stay within free tier limits

## Support

For issues or questions:
- Check Firebase documentation: https://firebase.google.com/docs
- FlutterFire documentation: https://firebase.flutter.dev
