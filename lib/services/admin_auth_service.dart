import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_user.dart';

class AdminAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current admin user
  User? get currentUser => _auth.currentUser;

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in admin
  Future<AdminUser?> signInAdmin(String email, String password) async {
    try {
      // Sign in with Firebase Auth
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if user is an admin
      final adminDoc = await _firestore
          .collection('admins')
          .doc(credential.user!.uid)
          .get();

      if (!adminDoc.exists) {
        // Not an admin, sign out
        await _auth.signOut();
        throw Exception('Unauthorized: This account is not an admin.');
      }

      // Get admin data
      final admin = AdminUser.fromFirestore(adminDoc);

      if (!admin.isActive) {
        await _auth.signOut();
        throw Exception('Account is deactivated. Contact super admin.');
      }

      // Update last login
      await _firestore.collection('admins').doc(credential.user!.uid).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
      });

      return admin;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
          throw Exception('No admin account found with this email.');
        case 'wrong-password':
          throw Exception('Incorrect password.');
        case 'invalid-email':
          throw Exception('Invalid email format.');
        case 'user-disabled':
          throw Exception('This account has been disabled.');
        default:
          throw Exception('Login failed: ${e.message}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get current admin data
  Future<AdminUser?> getCurrentAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final adminDoc =
          await _firestore.collection('admins').doc(user.uid).get();

      if (!adminDoc.exists) {
        await _auth.signOut();
        return null;
      }

      return AdminUser.fromFirestore(adminDoc);
    } catch (e) {
      return null;
    }
  }

  // Check if current user is admin
  Future<bool> isAdmin() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final adminDoc =
          await _firestore.collection('admins').doc(user.uid).get();

      return adminDoc.exists;
    } catch (e) {
      return false;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Create admin (only super admin can do this)
  Future<void> createAdmin({
    required String email,
    required String password,
    required String fullName,
    required AdminRole role,
    List<String> permissions = const [],
  }) async {
    try {
      // Create Firebase Auth account
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create admin document
      await _firestore.collection('admins').doc(credential.user!.uid).set({
        'email': email,
        'fullName': fullName,
        'role': role.value,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'permissions': permissions,
      });
    } catch (e) {
      rethrow;
    }
  }

  // Update admin role and permissions
  Future<void> updateAdminRole({
    required String adminId,
    AdminRole? role,
    List<String>? permissions,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};

      if (role != null) updates['role'] = role.value;
      if (permissions != null) updates['permissions'] = permissions;
      if (isActive != null) updates['isActive'] = isActive;

      if (updates.isNotEmpty) {
        await _firestore.collection('admins').doc(adminId).update(updates);
      }
    } catch (e) {
      rethrow;
    }
  }

  // Get all admins (for super admin)
  Stream<List<AdminUser>> getAllAdmins() {
    return _firestore
        .collection('admins')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => AdminUser.fromFirestore(doc)).toList());
  }

  // Delete admin
  Future<void> deleteAdmin(String adminId) async {
    try {
      await _firestore.collection('admins').doc(adminId).delete();
    } catch (e) {
      rethrow;
    }
  }
}
