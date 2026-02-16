import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'firebase_options.dart';
import 'services/admin_auth_service.dart';
import 'models/admin_user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final adminAuth = AdminAuthService();
  
  print('\n=== Creating First Super Admin Account ===\n');
  
  try {
    // Create super admin account
    final admin = await adminAuth.createAdmin(
      email: 'admin@must.ac.ug',
      password: 'ChangeThisPassword123!',
      fullName: 'System Administrator',
      role: AdminRole.superAdmin,
    );
    
    print('✅ Success! Super admin account created.\n');
    print('Admin Details:');
    print('  Email: admin@must.ac.ug');
    print('  Password: ChangeThisPassword123!');
    print('  Role: Super Admin');
    print('  UID: ${admin.uid}\n');
    
    print('⚠️  IMPORTANT: Change the password after first login!\n');
    print('You can now login to the admin panel at:');
    print('https://sexual-harrasment-management.web.app\n');
    
  } catch (e) {
    print('❌ Error creating admin account: $e\n');
    print('Common issues:');
    print('  - Email already exists');
    print('  - Weak password');
    print('  - Firebase connection issues\n');
  }
  
  print('Setup complete. You can close this now.');
}
