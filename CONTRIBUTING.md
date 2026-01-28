# Contributing to Report Safely

Thank you for your interest in contributing to the Sexual Harassment Management App! This guide will help you get started.

## Getting Started for New Contributors

### 1. Fork and Clone the Repository

```bash
git clone https://github.com/ChrisWalt3r/Report-sexual-harassment-app.git
cd Report-sexual-harassment-app
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. **IMPORTANT: Set Up Firebase**

Firebase credentials are **NOT** included in this repository for security. You must create your own Firebase project:

#### Quick Setup:

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase for this project
flutterfire configure
```

When running `flutterfire configure`:
- You can either select an existing Firebase project or create a new one
- Select the platforms you want to support (Android, iOS, Web, macOS)
- The CLI will automatically generate all necessary configuration files

#### Files Generated (gitignored):
- ✅ `lib/firebase_options.dart` - Your Firebase credentials
- ✅ `android/app/google-services.json` - Android config
- ✅ `ios/Runner/GoogleService-Info.plist` - iOS config (if selected)

📖 **For detailed Firebase setup, see [FIREBASE_SETUP.md](FIREBASE_SETUP.md)**

### 4. Enable Firebase Services

In your Firebase Console:
1. **Authentication**: Enable Email/Password sign-in
2. **Firestore Database**: Create database (start in test mode for development)
3. **Storage**: Enable if needed for file uploads

### 5. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── config/          # App configuration
├── constants/       # Colors, styles, constants
├── features/        # Feature modules
├── screens/         # UI screens
├── services/        # Business logic & API services
└── widgets/         # Reusable UI components
```

## Important Files (DO NOT COMMIT)

These files contain sensitive information and are gitignored:
- ❌ `lib/firebase_options.dart`
- ❌ `android/app/google-services.json`
- ❌ `ios/Runner/GoogleService-Info.plist`
- ❌ Any file with API keys or secrets

## Making Changes

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Your Changes

- Write clean, documented code
- Follow Flutter/Dart best practices
- Test your changes thoroughly

### 3. Commit Your Changes

```bash
git add .
git commit -m "Description of your changes"
```

### 4. Push and Create Pull Request

```bash
git push origin feature/your-feature-name
```

Then create a pull request on GitHub.

## Coding Guidelines

### Dart/Flutter Style

- Follow the [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

### File Naming

- Use `snake_case` for file names: `my_screen.dart`
- Use `PascalCase` for class names: `MyScreen`
- Use `camelCase` for variables and functions: `myVariable`

### State Management

- We use Provider for state management
- Keep business logic in services, not in widgets

## Testing

Before submitting a PR:

```bash
# Run tests
flutter test

# Check for issues
flutter analyze

# Format code
dart format .
```

## Need Help?

- 📖 Check [README.md](README.md) for general info
- 🔥 See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for Firebase setup
- 💬 Open an issue if you have questions
- 📧 Contact the maintainers

## Security

- **NEVER** commit API keys, credentials, or sensitive data
- **ALWAYS** check `.gitignore` before committing
- Report security vulnerabilities privately to maintainers

## License

By contributing, you agree that your contributions will be licensed under the same license as this project.

---

Thank you for contributing to making our campus safer! 🌟
