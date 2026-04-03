# Report Safely - Sexual Harassment Management App

A comprehensive Flutter-based mobile application designed to provide confidential support and resources for survivors of sexual harassment at MUST Campus. The app features AI-powered chat support, emergency services, comprehensive support resources, and a complete admin management system.

## 🚀 Current Status
- ✅ Core app functionality implemented
- ✅ Firebase integration configured
- ✅ Admin dashboard and management system
- ✅ Email notification system
- ✅ AI-powered chat support
- ✅ Comprehensive reporting system
- 🔄 Final testing and deployment preparation

## ✨ Features

### For Users
- **AI-Powered Chat Support** - Confidential conversations with an AI counselor trained in trauma-informed responses
- **Emergency Services** - Quick access to campus security and emergency contacts
- **Support Services** - Counseling, medical, and legal resources with detailed contact information
- **Incident Reporting** - Submit and track harassment reports with multimedia evidence support
- **Anonymous Options** - Report incidents without revealing your identity
- **Profile Management** - Secure user profiles with privacy controls
- **Notifications** - Real-time updates on report status and important information

### For Administrators
- **Admin Dashboard** - Comprehensive overview of all reports and system analytics
- **Report Management** - Review, update, and manage incident reports
- **User Management** - Manage user accounts and permissions
- **Analytics & Insights** - AI-powered insights and reporting trends
- **Contact Management** - Manage official contacts and support services
- **Policy Management** - Update and maintain harassment policies
- **Email Notifications** - Automated notifications for new reports and status changes

## 🛠 Tech Stack

- **Frontend**: Flutter 3.41+ with Dart
- **Backend**: Firebase (Firestore, Authentication, Storage, Cloud Functions)
- **State Management**: Provider pattern
- **AI Integration**: GROQ API for enhanced AI responses
- **Image Handling**: ImgBB and Cloudinary services
- **Email Services**: Firebase Cloud Functions with Nodemailer
- **Security**: Firebase Security Rules, encrypted storage
- **Analytics**: Built-in analytics dashboard with AI insights

## Getting Started

### Prerequisites

- Flutter SDK ^3.7.2
- Dart SDK
- Android Studio / VS Code
- iOS Simulator or Android Emulator

### Installation

1. Clone the repository:
```bash
git clone https://github.com/ChrisWalt3r/Report-sexual-harassment-app.git
cd Report-sexual-harassment-app
```

2. Install dependencies:
```bash
flutter pub get
```

3. **Configure Firebase** (Required):
   
   Firebase credentials are not included in this repository for security reasons. You need to set up your own Firebase project:
   
   a. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```
   
   b. Login to Firebase:
   ```bash
   firebase login
   ```
   
   c. Install FlutterFire CLI:
   ```bash
   dart pub global activate flutterfire_cli
   ```
   
   d. Configure Firebase for this project:
   ```bash
   flutterfire configure
   ```
   
   This will:
   - Prompt you to select or create a Firebase project
   - Ask which platforms to support (Android, iOS, Web, macOS)
   - Automatically generate `lib/firebase_options.dart` with your credentials
   - Generate platform-specific configuration files
   
   📖 **See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for detailed instructions**

4. Configure AI Service (optional):
   - Get an API key from [Hugging Face](https://huggingface.co/)
   - Update the key in `lib/services/enhanced_ai_service.dart`

5. Run the app:
```bash
flutter run
```

## Project Structure

```
lib/
├── config/          # App configuration (AI settings)
├── constants/       # Colors, styles, and constants
├── features/        # Feature modules (support services)
├── screens/         # App screens (home, chat, emergency, etc.)
├── services/        # Business logic and API services
├── widgets/         # Reusable UI components
└── main.dart        # App entry point
```

## Privacy & Security

- All conversations are confidential
- Anonymous reporting available
- Data encryption in transit
- No personal data shared without consent

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/your-feature`)
3. Commit your changes (`git commit -m 'Add your feature'`)
4. Push to the branch (`git push origin feature/your-feature`)
5. Open a Pull Request

## License

This project is for educational purposes at MUST Campus.

## Support

For questions or support, contact the development team or open an issue on GitHub.
