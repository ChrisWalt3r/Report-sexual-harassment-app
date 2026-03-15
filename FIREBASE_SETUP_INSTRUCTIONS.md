# Firebase Setup Instructions

## 🔥 **REQUIRED: Set up your Firebase project**

The app needs a real Firebase project to work properly. Follow these steps:

### **Step 1: Create Firebase Project**
1. Go to https://console.firebase.google.com
2. Click "Add project"
3. Project name: `must-harassment-report` (or your choice)
4. Disable Google Analytics (optional)
5. Click "Create project"

### **Step 2: Add Android App**
1. In Firebase Console, click "Add app" → Android (📱)
2. **Android package name**: `com.must.report_harassment`
3. **App nickname**: "MUST Harassment Report"
4. **Debug signing certificate SHA-1**: Leave empty for now
5. Click "Register app"

### **Step 3: Download google-services.json**
1. Download the `google-services.json` file
2. Place it in: `android/app/google-services.json`
3. **IMPORTANT**: Replace the placeholder file with this real one

### **Step 4: Enable Authentication**
1. Firebase Console → Authentication
2. Click "Get started"
3. Sign-in method tab
4. Enable "Email/Password"
5. Click "Save"

### **Step 5: Set up Firestore Database**
1. Firebase Console → Firestore Database
2. Click "Create database"
3. Start in "test mode" (for development)
4. Choose your region (preferably close to Uganda)
5. Click "Enable"

### **Step 6: Update Firebase Options**
1. Run: `flutterfire configure`
2. Select your project
3. Select platforms: Android, iOS (if needed)
4. This will update `lib/firebase_options.dart` with real values

### **Step 7: Test the App**
1. Run: `flutter clean`
2. Run: `flutter pub get`
3. Run: `flutter run -d "R83Y80ASEBE"`

## 🔧 **Quick Commands**
```bash
# After setting up Firebase project:
flutterfire configure
flutter clean
flutter pub get
flutter run -d "R83Y80ASEBE"
```

## ✅ **What You'll Get**
- ✅ Real user registration and login
- ✅ Secure data storage in Firestore
- ✅ User profiles and reports
- ✅ All app features working properly
- ✅ MUST University theme with full functionality

## 🆘 **Need Help?**
If you need help setting up Firebase, let me know and I can guide you through each step!