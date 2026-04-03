import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import 'cloudinary_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _phoneLoginCachePrefix = 'phone_login_email_';

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
    String? phoneNumber,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) {
        await _cachePhoneLoginEmail(phoneNumber: phoneNumber, email: email);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign in with student ID (using email format: studentId@university.edu)
  Future<UserCredential?> signInWithStudentId({
    required String studentId,
    required String password,
  }) async {
    try {
      // Convert student ID to email format
      String email = '$studentId@must.ac.ug';

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  String _normalizePhoneNumber(String phoneNumber) {
    return phoneNumber.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  String _phoneLookupDocId(String phoneNumber) {
    return Uri.encodeComponent(_normalizePhoneNumber(phoneNumber));
  }

  String _phoneLoginCacheKey(String phoneNumber) {
    return '$_phoneLoginCachePrefix${_phoneLookupDocId(phoneNumber)}';
  }

  String _buildHiddenPhoneAuthEmail(String phoneNumber) {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    final digitsOnly = normalizedPhone.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.isEmpty) {
      throw 'Phone number cannot be empty';
    }

    return 'phone_$digitsOnly@must.ac.ug';
  }

  bool _isHiddenPhoneAuthEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    return normalizedEmail.startsWith('phone_') &&
        normalizedEmail.endsWith('@must.ac.ug');
  }

  Future<void> _cachePhoneLoginEmail({
    required String phoneNumber,
    required String email,
  }) async {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    final normalizedEmail = email.trim();

    if (normalizedPhone.isEmpty || normalizedEmail.isEmpty) {
      return;
    }

    try {
      await _secureStorage.write(
        key: _phoneLoginCacheKey(normalizedPhone),
        value: normalizedEmail,
      );
    } catch (e) {
      debugPrint('Failed to cache phone login email: $e');
    }
  }

  Future<void> _deleteCachedPhoneLoginEmail(String phoneNumber) async {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    if (normalizedPhone.isEmpty) {
      return;
    }

    try {
      await _secureStorage.delete(key: _phoneLoginCacheKey(normalizedPhone));
    } catch (e) {
      debugPrint('Failed to clear cached phone login email: $e');
    }
  }

  Future<String?> _readCachedPhoneLoginEmail(String phoneNumber) async {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    if (normalizedPhone.isEmpty) {
      return null;
    }

    try {
      final cachedEmail = await _secureStorage.read(
        key: _phoneLoginCacheKey(normalizedPhone),
      );
      if (cachedEmail == null) {
        return null;
      }

      final trimmedEmail = cachedEmail.trim();
      return trimmedEmail.isEmpty ? null : trimmedEmail;
    } catch (e) {
      debugPrint('Failed to read cached phone login email: $e');
      return null;
    }
  }

  Future<void> _upsertPhoneLoginLookup({
    required String phoneNumber,
    required String authEmail,
    required String userId,
  }) async {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    final normalizedEmail = authEmail.trim();

    if (normalizedPhone.isEmpty || normalizedEmail.isEmpty) {
      return;
    }

    await _firestore
        .collection('phone_login_lookup')
        .doc(_phoneLookupDocId(normalizedPhone))
        .set({
          'phoneNumber': normalizedPhone,
          'authEmail': normalizedEmail,
          'userId': userId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    await _cachePhoneLoginEmail(
      phoneNumber: normalizedPhone,
      email: normalizedEmail,
    );
  }

  Future<void> _deletePhoneLoginLookup(String phoneNumber) async {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);
    if (normalizedPhone.isEmpty) {
      return;
    }

    await _firestore
        .collection('phone_login_lookup')
        .doc(_phoneLookupDocId(normalizedPhone))
        .delete();

    await _deleteCachedPhoneLoginEmail(normalizedPhone);
  }

  Future<String> _resolveEmailForPhoneNumber(String phoneNumber) async {
    final normalizedPhone = _normalizePhoneNumber(phoneNumber);

    if (normalizedPhone.isEmpty) {
      throw 'Phone number cannot be empty';
    }

    final cachedEmail = await _readCachedPhoneLoginEmail(normalizedPhone);
    if (cachedEmail != null) {
      return cachedEmail;
    }

    try {
      final lookupDoc =
          await _firestore
              .collection('phone_login_lookup')
              .doc(_phoneLookupDocId(normalizedPhone))
              .get();

      if (!lookupDoc.exists) {
        throw 'No account found with this phone number.';
      }

      final data = lookupDoc.data();
      final email = (data?['authEmail'] as String?)?.trim();

      if (email == null || email.isEmpty) {
        throw 'No email is linked to this phone number.';
      }

      await _cachePhoneLoginEmail(phoneNumber: normalizedPhone, email: email);
      return email;
    } on FirebaseException catch (e) {
      final fallbackEmail = await _readCachedPhoneLoginEmail(normalizedPhone);
      if (fallbackEmail != null) {
        return fallbackEmail;
      }

      if (e.code == 'permission-denied' ||
          e.code == 'unauthenticated' ||
          e.code == 'unavailable') {
        throw 'Phone lookup is currently blocked. Sign in with email once on this device to refresh the saved phone login, or contact support.';
      }

      throw 'Error resolving phone number: ${e.message ?? e.code}';
    }
  }

  Future<UserCredential?> signInWithPhone({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);

      if (normalizedPhone.isEmpty) {
        throw 'Phone number cannot be empty';
      }

      final hiddenEmail = _buildHiddenPhoneAuthEmail(normalizedPhone);

      try {
        final hiddenCredential = await _auth.signInWithEmailAndPassword(
          email: hiddenEmail,
          password: password,
        );

        await _cachePhoneLoginEmail(
          phoneNumber: normalizedPhone,
          email: hiddenEmail,
        );

        return hiddenCredential;
      } on FirebaseAuthException catch (hiddenError) {
        if (hiddenError.code != 'user-not-found') {
          throw _handleAuthException(hiddenError);
        }
      }

      final email = await _resolveEmailForPhoneNumber(normalizedPhone);

      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register new user with email
  Future<UserCredential?> registerWithEmail({
    required String email,
    required String password,
    required String fullName,
    required String studentId,
    required String department,
    required String phoneNumber,
    String role = '',
    String otherRole = '',
    String studyLevel = '',
    String facultyDepartment = '',
    String gender = '',
  }) async {
    try {
      final storedRole = role.trim();
      final storedOtherRole = otherRole.trim();
      final normalizedPhone = _normalizePhoneNumber(phoneNumber);
      final trimmedEmail = email.trim();
      final authEmail =
          trimmedEmail.isNotEmpty
              ? trimmedEmail
              : _buildHiddenPhoneAuthEmail(normalizedPhone);

      if (storedRole == 'Other' && storedOtherRole.isEmpty) {
        throw 'Please specify your role.';
      }

      // Create user account
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: authEmail, password: password);

      // Store additional user data in Firestore
      final userId = userCredential.user!.uid;
      await _firestore.collection('users').doc(userId).set({
        'fullName': fullName,
        'email': trimmedEmail,
        'authEmail': authEmail,
        'studentId': studentId,
        'department': department,
        'phoneNumber': phoneNumber,
        'role': storedRole,
        'otherRole': storedOtherRole,
        'studyLevel': studyLevel,
        'facultyDepartment': facultyDepartment,
        'gender': gender,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false,
      });

      await _upsertPhoneLoginLookup(
        phoneNumber: phoneNumber,
        authEmail: authEmail,
        userId: userId,
      );

      // Update display name
      await userCredential.user!.updateDisplayName(fullName);

      await _cachePhoneLoginEmail(phoneNumber: phoneNumber, email: authEmail);

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Register with student ID
  Future<UserCredential?> registerWithStudentId({
    required String studentId,
    required String password,
    required String fullName,
    required String department,
    required String phoneNumber,
  }) async {
    try {
      // Convert student ID to email format
      String email = '$studentId@must.ac.ug';

      return await registerWithEmail(
        email: email,
        password: password,
        fullName: fullName,
        studentId: studentId,
        department: department,
        phoneNumber: phoneNumber,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      print('DEBUG: Starting Google Sign-In process...');

      // Sign out first to ensure account picker is shown
      await _googleSignIn.signOut();

      print('DEBUG: Triggering Google Sign-In flow...');
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        print('DEBUG: User cancelled Google Sign-In');
        throw 'Sign in cancelled by user';
      }

      print('DEBUG: Google user signed in: ${googleUser.email}');

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      print('DEBUG: Got Google authentication tokens');

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      print('DEBUG: Created Firebase credential, signing in...');

      // Sign in to Firebase with the Google credential
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      print(
        'DEBUG: Firebase sign-in successful: ${userCredential.user?.email}',
      );

      // Check if this is a new user, if so create their profile
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        print('DEBUG: New user, creating profile...');
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'fullName': googleUser.displayName ?? '',
          'email': googleUser.email,
          'authEmail': googleUser.email,
          'studentId': '', // Will need to be filled later
          'department': '', // Will need to be filled later
          'phoneNumber': '', // Will need to be filled later
          'role': '',
          'otherRole': '',
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
          'signInMethod': 'google',
        });
        print('DEBUG: User profile created successfully');
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      print(
        'DEBUG: FirebaseAuthException - Code: ${e.code}, Message: ${e.message}',
      );

      if (e.code == 'account-exists-with-different-credential') {
        throw 'An account already exists with the same email address but different sign-in credentials. Please try signing in with email/password.';
      }
      if (e.code == 'invalid-credential') {
        throw 'The Google sign-in credentials are invalid or expired. Please try again.';
      }
      if (e.code == 'operation-not-allowed') {
        throw 'Google sign-in is not enabled. Please contact support.';
      }
      if (e.code == 'user-disabled') {
        throw 'This account has been disabled. Please contact support.';
      }

      throw _handleAuthException(e);
    } catch (e) {
      print('DEBUG: General error during Google Sign-In: $e');

      if (e.toString().contains('cancelled') ||
          e.toString().contains('canceled')) {
        throw 'Sign in cancelled by user';
      }
      if (e.toString().contains('network')) {
        throw 'Network error. Please check your internet connection and try again.';
      }
      if (e.toString().contains('PlatformException')) {
        throw 'Google Sign-In configuration error. Please contact support.';
      }

      rethrow;
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      throw 'Error fetching user data: $e';
    }
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String uid,
    Map<String, dynamic>? updates,
  }) async {
    try {
      final currentDoc = await _firestore.collection('users').doc(uid).get();
      final currentData = currentDoc.data();
      final previousPhone = currentData?['phoneNumber'] as String?;
      final authEmail =
          (currentData?['authEmail'] as String? ?? _auth.currentUser?.email)
              ?.trim();

      await _firestore.collection('users').doc(uid).update(updates ?? {});

      final newPhone = updates?['phoneNumber'] as String?;
      final normalizedNewPhone = _normalizePhoneNumber(newPhone ?? '');
      final normalizedOldPhone = _normalizePhoneNumber(previousPhone ?? '');

      if (normalizedOldPhone.isNotEmpty &&
          normalizedOldPhone != normalizedNewPhone) {
        await _deletePhoneLoginLookup(normalizedOldPhone);
      }

      if (normalizedNewPhone.isNotEmpty &&
          authEmail != null &&
          authEmail.isNotEmpty) {
        await _upsertPhoneLoginLookup(
          phoneNumber: normalizedNewPhone,
          authEmail: authEmail,
          userId: uid,
        );
      }
    } catch (e) {
      throw 'Error updating profile: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      final hasPasswordProvider = user.providerData.any(
        (p) => p.providerId == 'password',
      );
      if (!hasPasswordProvider) {
        throw 'This account does not use an email/password sign-in method. Use “Reset Password” instead.';
      }

      final email = user.email;
      if (email == null || email.isEmpty) {
        throw 'User email not found';
      }

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw 'Current password is incorrect';
      }
      if (e.code == 'weak-password') {
        throw 'New password is too weak. Please use at least 6 characters with a mix of letters and numbers';
      }
      if (e.code == 'requires-recent-login') {
        throw 'For security reasons, please log out and log in again before changing your password';
      }
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  Future<String> updateProfilePhoto({required XFile imageFile}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      final uid = user.uid;
      String? downloadUrl;

      if (kIsWeb) {
        // For web, upload bytes
        final bytes = await imageFile.readAsBytes();
        final filename = 'profile_$uid.jpg';
        downloadUrl = await CloudinaryService.uploadImageBytes(bytes, filename);
      } else {
        // For mobile, upload file
        downloadUrl = await CloudinaryService.uploadImage(imageFile.path);
      }

      if (downloadUrl == null) {
        throw 'Failed to upload image to Cloudinary: ${CloudinaryService.lastError ?? "Unknown error"}';
      }

      // Update Firestore with new photo URL
      await _firestore.collection('users').doc(uid).update({
        'photoUrl': downloadUrl,
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firebase Auth profile
      await user.updatePhotoURL(downloadUrl);

      return downloadUrl;
    } catch (e) {
      if (e.toString().contains('Cloudinary')) {
        rethrow;
      }
      throw 'Failed to upload profile photo: $e';
    }
  }

  Future<void> removeProfilePhoto() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      final uid = user.uid;

      // Update Firestore to remove photo URL
      await _firestore.collection('users').doc(uid).update({
        'photoUrl': FieldValue.delete(),
        'photoUpdatedAt': FieldValue.serverTimestamp(),
      });

      // Update Firebase Auth profile
      await user.updatePhotoURL(null);
    } catch (e) {
      throw 'Failed to remove profile photo: $e';
    }
  }

  // Delete account and all user data
  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      final uid = user.uid;
      final email = user.email;

      // Check if user signed in with Google or Email
      bool isGoogleSignIn = false;
      for (var provider in user.providerData) {
        if (provider.providerId == 'google.com') {
          isGoogleSignIn = true;
          break;
        }
      }

      // Re-authenticate user before deletion
      if (isGoogleSignIn) {
        // For Google sign-in, re-authenticate with Google
        try {
          final googleUser = await _googleSignIn.signIn();
          if (googleUser == null) {
            throw 'Google sign-in cancelled';
          }

          final googleAuth = await googleUser.authentication;
          final credential = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );

          await user.reauthenticateWithCredential(credential);
        } catch (e) {
          throw 'Failed to re-authenticate with Google: ${e.toString()}';
        }
      } else {
        // For email/password, use the provided password
        if (email == null || email.isEmpty) {
          throw 'User email not found';
        }

        final credential = EmailAuthProvider.credential(
          email: email,
          password: password,
        );

        await user.reauthenticateWithCredential(credential);
      }

      // Delete user data from Firestore
      await _firestore.collection('users').doc(uid).delete();

      // Delete any other user-related data (reports, etc.)
      final reportsSnapshot =
          await _firestore
              .collection('reports')
              .where('userId', isEqualTo: uid)
              .get();

      for (var doc in reportsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Delete chat messages if any
      final chatsSnapshot =
          await _firestore
              .collection('chats')
              .where('userId', isEqualTo: uid)
              .get();

      for (var doc in chatsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Sign out from Google if signed in with Google
      if (isGoogleSignIn) {
        await _googleSignIn.signOut();
      }

      // Delete the Firebase Auth account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw 'Incorrect password. Please try again';
      }
      if (e.code == 'requires-recent-login') {
        throw 'For security reasons, please log out and log in again before deleting your account';
      }
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      // Validate email format
      email = email.trim().toLowerCase();

      if (email.isEmpty) {
        throw 'Email address cannot be empty';
      }

      if (!email.contains('@') || !email.contains('.')) {
        throw 'Please enter a valid email address';
      }

      print('DEBUG: Attempting to send password reset email to: $email');

      // Configure action code settings for better email delivery
      final actionCodeSettings = ActionCodeSettings(
        url: 'https://sexual-harrasment-management.firebaseapp.com',
        handleCodeInApp: false,
        androidPackageName: 'com.must.report_harassment',
        androidInstallApp: false,
      );

      // Send password reset email
      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: actionCodeSettings,
      );

      print('DEBUG: ✅ Password reset email sent successfully!');
      print('DEBUG: Email sent to: $email');
      print('DEBUG: Check:');
      print('  1. Your inbox (may take 2-10 minutes)');
      print('  2. Spam/Junk/Promotions folders');
      print('  3. Make sure you registered with this exact email address');
    } on FirebaseAuthException catch (e) {
      print(
        'DEBUG: ❌ FirebaseAuthException - Code: ${e.code}, Message: ${e.message}',
      );

      // Handle specific Firebase errors
      if (e.code == 'user-not-found') {
        throw 'No account found with this email address.\n\nPlease make sure:\n• You have registered an account\n• The email address is correct';
      }
      if (e.code == 'invalid-email') {
        throw 'Invalid email format. Please enter a valid email address.';
      }
      if (e.code == 'too-many-requests') {
        throw 'Too many password reset attempts. Please try again later.';
      }
      throw _handleAuthException(e);
    } catch (e) {
      print('DEBUG: ❌ General error: $e');
      rethrow;
    }
  }

  Future<String> resetPasswordByPhone(String phoneNumber) async {
    final email = await _resolveEmailForPhoneNumber(phoneNumber);

    if (_isHiddenPhoneAuthEmail(email)) {
      throw 'This account was created without a visible email address, so password reset by phone is not available. Please add an email address in your profile or contact support.';
    }

    await resetPassword(email);
    return email;
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email/student ID.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email/student ID.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      case 'invalid-email':
        return 'Invalid email format. Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }
}
