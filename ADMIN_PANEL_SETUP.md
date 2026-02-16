# Admin Panel Setup and Deployment Guide

## Overview
The admin panel is a web-based interface for managing users and reports. It's hosted on Firebase Hosting and accessible only to authorized administrators.

## Features

### 1. Admin Authentication
- Separate login system from regular users
- Role-based access control (Super Admin, Reviewer, Moderator)
- Secure Firebase Authentication

### 2. Dashboard
- Overview statistics (total users, reports, pending, resolved)
- Quick access to management sections
- Role-specific features

### 3. User Management
- View all registered users
- Search users by name, email, or student ID
- View user details (name, faculty, reports submitted)
- Suspend/activate user accounts
- Filter and sort users

### 4. Report Management
- View all reports with filtering options
- Filter by status (submitted, under review, investigating, resolved, closed)
- Search by report ID, type, or location
- View complete report details including evidence
- Update report status
- View reporter information (for non-anonymous reports)

## Setup Instructions

### Step 1: Create Admin Accounts

First, you need to create admin accounts in Firestore. Run this setup locally:

```dart
// Create a script: setup_admin.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/admin_auth_service.dart';
import 'models/admin_user.dart';

void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final adminAuth = AdminAuthService();

  // Create Super Admin
  await adminAuth.createAdmin(
    email: 'admin@must.ac.ug',
    password: 'SecurePassword123!',
    fullName: 'Super Administrator',
    role: AdminRole.superAdmin,
    permissions: [],
  );

  print('Admin created successfully!');
}
```

Run: `dart run setup_admin.dart`

### Step 2: Build the Web Version

```bash
# Build for web with admin entry point
flutter build web --target=lib/main_admin.dart --release

# The build will be in build/web directory
```

### Step 3: Deploy to Firebase Hosting

```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase Hosting (first time only)
firebase init hosting
# Select "build/web" as public directory
# Configure as single-page app: Yes
# Set up automatic builds with GitHub: No (optional)

# Deploy to Firebase
firebase deploy --only hosting

# You'll get a URL like: https://your-project.web.app
```

### Step 4: Custom Domain (Optional)

1. Go to Firebase Console
2. Navigate to Hosting
3. Click "Add custom domain"
4. Follow the instructions to add your domain (e.g., admin.reportmanagement.com)

## Security Configuration

### Firestore Rules

Update your `firestore.rules` to protect admin data:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Admin collection - only admins can read
    match /admins/{adminId} {
      allow read: if request.auth != null && 
                     exists(/databases/$(database)/documents/admins/$(request.auth.uid));
      allow write: if false; // Only create via backend
    }
    
    // Users collection - admins can read
    match /users/{userId} {
      allow read: if request.auth != null && 
                     exists(/databases/$(database)/documents/admins/$(request.auth.uid));
      allow update: if request.auth != null && 
                       exists(/databases/$(database)/documents/admins/$(request.auth.uid)) &&
                       request.resource.data.keys().hasOnly(['isActive']);
    }
    
    // Reports collection - admins can read and update
    match /reports/{reportId} {
      allow read: if request.auth != null && 
                     exists(/databases/$(database)/documents/admins/$(request.auth.uid));
      allow update: if request.auth != null && 
                       exists(/databases/$(database)/documents/admins/$(request.auth.uid)) &&
                       request.resource.data.keys().hasAny(['status', 'updatedAt', 'updatedBy']);
    }
  }
}
```

## Admin Roles and Permissions

### Super Admin
- Full access to all features
- Can manage users (view, suspend, activate)
- Can manage reports (view, update status)
- Can view analytics
- Can create other admins

### Reviewer
- Can view and update reports
- Can add case notes
- Can assign reports (if given permission)
- Limited user management access

### Moderator
- Can view reports
- Can view users
- Cannot modify data

## Usage

### Creating Additional Admins

Super Admin can create additional admins through the Firebase Console or by running:

```dart
final adminAuth = AdminAuthService();

await adminAuth.createAdmin(
  email: 'reviewer@must.ac.ug',
  password: 'SecurePassword123!',
  fullName: 'John Doe',
  role: AdminRole.reviewer,
  permissions: ['manage_reports', 'assign_reports'],
);
```

### Updating Admin Roles

```dart
await adminAuth.updateAdminRole(
  adminId: 'admin-uid-here',
  role: AdminRole.reviewer,
  permissions: ['manage_reports'],
  isActive: true,
);
```

## Access Control

### Login URL
- **Production**: https://your-project.web.app
- **Custom Domain**: https://admin.your-domain.com (if configured)

### Credentials Distribution
1. Create admin accounts with secure passwords
2. Share credentials securely (encrypted email, password manager)
3. Require admins to change password on first login
4. Never commit credentials to version control

## Monitoring and Maintenance

### View Logs
```bash
firebase functions:log --only hosting
```

### Update Deployment
```bash
# After making changes
flutter build web --target=lib/main_admin.dart --release
firebase deploy --only hosting
```

### Backup Admin Data
Regularly export admin collection from Firestore console for backup.

## Troubleshooting

### Issue: Admin cannot login
- Check if admin document exists in `admins` collection
- Verify email and password are correct
- Check if `isActive` field is `true`

### Issue: Unauthorized errors
- Verify Firestore rules are updated
- Check if admin document exists
- Ensure Firebase Auth user exists

### Issue: Cannot view/update data
- Check admin permissions in Firestore
- Verify role is correctly set
- Review Firebase security rules

## Security Best Practices

1. **Use Strong Passwords**: Minimum 12 characters with mixed case, numbers, symbols
2. **Enable 2FA**: Use Firebase Authentication 2FA when available
3. **Regular Audits**: Review admin access logs regularly
4. **Limit Super Admin**: Only create necessary super admin accounts
5. **Rotate Credentials**: Change admin passwords periodically
6. **Monitor Activity**: Track report status changes and user modifications
7. **Secure Network**: Access admin panel only from secure networks
8. **HTTPS Only**: Ensure hosting uses HTTPS (default with Firebase)

## Support

For issues or questions:
- Check Firebase Console logs
- Review Firestore rules
- Verify admin account in Firestore
- Contact system administrator

---

**Last Updated**: February 2026
**Version**: 1.0.0
