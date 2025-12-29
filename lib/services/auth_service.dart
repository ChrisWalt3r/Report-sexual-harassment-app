import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  
  // List of allowed university email domains
  final List<String> _allowedDomains = [
    '@std.must.ac.ug',
    '@must.ac.ug',
  ];

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
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
      String email = '$studentId@must.ac.mw';
      
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
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
  }) async {
    try {
      // Create user account
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store additional user data in Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'fullName': fullName,
        'email': email,
        'studentId': studentId,
        'department': department,
        'phoneNumber': phoneNumber,
        'createdAt': FieldValue.serverTimestamp(),
        'isVerified': false,
      });

      // Update display name
      await userCredential.user!.updateDisplayName(fullName);

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
      String email = '$studentId@must.ac.mw';
      
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

  // Sign in with Google (only university emails allowed)
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // User canceled the sign-in
        throw 'Sign in cancelled';
      }

      // Check if the email is from allowed university domain
      bool isUniversityEmail = _allowedDomains.any(
        (domain) => googleUser.email.toLowerCase().endsWith(domain.toLowerCase())
      );

      if (!isUniversityEmail) {
        // Sign out from Google if not a university email
        await _googleSignIn.signOut();
        throw 'Only university email addresses (@std.must.ac.ug) are allowed to sign in';
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      UserCredential userCredential = await _auth.signInWithCredential(credential);

      // Check if this is a new user, if so create their profile
      if (userCredential.additionalUserInfo?.isNewUser ?? false) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'fullName': googleUser.displayName ?? '',
          'email': googleUser.email,
          'studentId': '', // Will need to be filled later
          'department': '', // Will need to be filled later
          'phoneNumber': '', // Will need to be filled later
          'createdAt': FieldValue.serverTimestamp(),
          'isVerified': false,
          'signInMethod': 'google',
        });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      rethrow;
    }
  }

  // Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
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
      await _firestore.collection('users').doc(uid).update(updates ?? {});
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

      // Re-authenticate user with current password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
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

  // Delete account and all user data
  Future<void> deleteAccount(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      final uid = user.uid;

      // Re-authenticate user before deletion
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);

      // Delete user data from Firestore
      await _firestore.collection('users').doc(uid).delete();

      // Delete any other user-related data (reports, etc.)
      // Add more collections as needed
      final reportsSnapshot = await _firestore
          .collection('reports')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (var doc in reportsSnapshot.docs) {
        await doc.reference.delete();
      }

      // Sign out from Google if signed in with Google
      await _googleSignIn.signOut();

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
      
      // Send password reset email
      await _auth.sendPasswordResetEmail(email: email);
      
      print('DEBUG: Password reset email sent successfully');
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException - Code: ${e.code}, Message: ${e.message}');
      
      // Handle specific Firebase errors
      if (e.code == 'user-not-found') {
        throw 'No account found with this email address.\n\nPlease make sure:\n• You have registered an account\n• The email address is correct\n• You are using your university email';
      }
      if (e.code == 'invalid-email') {
        throw 'Invalid email format. Please enter a valid university email address.';
      }
      throw _handleAuthException(e);
    } catch (e) {
      print('DEBUG: General error: $e');
      rethrow;
    }
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
