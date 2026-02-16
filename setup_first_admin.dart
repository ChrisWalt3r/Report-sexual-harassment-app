// Run this script to create the first super admin
// Usage: dart run setup_first_admin.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:report_harassment/firebase_options.dart';
import 'package:report_harassment/services/admin_auth_service.dart';
import 'package:report_harassment/models/admin_user.dart';

void main() async {
  print('🔧 Setting up first super admin...\n');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final adminAuth = AdminAuthService();

  // Admin credentials - CHANGE THESE!
  const adminEmail = 'admin@must.ac.ug';
  const adminPassword = 'ChangeThisPassword123!';
  const adminName = 'Super Administrator';

  print('Creating admin account...');
  print('Email: $adminEmail');
  print('Name: $adminName');
  print('Role: Super Admin\n');

  try {
    await adminAuth.createAdmin(
      email: adminEmail,
      password: adminPassword,
      fullName: adminName,
      role: AdminRole.superAdmin,
      permissions: [],
    );

    print('✅ Super admin created successfully!');
    print('\n📝 Login credentials:');
    print('Email: $adminEmail');
    print('Password: $adminPassword');
    print('\n⚠️  IMPORTANT: Change this password after first login!');
    print('\n🌐 Deploy the admin panel:');
    print('1. flutter build web --target=lib/main_admin.dart --release');
    print('2. firebase deploy --only hosting');
  } catch (e) {
    print('❌ Error creating admin: $e');
    print('\nPossible reasons:');
    print('- Admin with this email already exists');
    print('- Firebase not properly configured');
    print('- Network connection issues');
  }
}
