import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin user roles
enum AdminRole {
  superAdmin,
  reviewer,
  moderator,
}

extension AdminRoleExtension on AdminRole {
  String get value {
    switch (this) {
      case AdminRole.superAdmin:
        return 'super_admin';
      case AdminRole.reviewer:
        return 'reviewer';
      case AdminRole.moderator:
        return 'moderator';
    }
  }

  String get displayName {
    switch (this) {
      case AdminRole.superAdmin:
        return 'Super Admin';
      case AdminRole.reviewer:
        return 'Reviewer';
      case AdminRole.moderator:
        return 'Moderator';
    }
  }

  static AdminRole fromString(String role) {
    final compact = role
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toLowerCase();

    switch (compact) {
      case 'superadmin':
        return AdminRole.superAdmin;
      case 'reviewer':
        return AdminRole.reviewer;
      case 'moderator':
        return AdminRole.moderator;
      default:
        return AdminRole.moderator;
    }
  }
}

/// Admin user model
class AdminUser {
  final String uid;
  final String email;
  final String fullName;
  final AdminRole role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final List<String> permissions;

  AdminUser({
    required this.uid,
    required this.email,
    required this.fullName,
    required this.role,
    this.isActive = true,
    required this.createdAt,
    this.lastLoginAt,
    this.permissions = const [],
  });

  factory AdminUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminUser(
      uid: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      role: AdminRoleExtension.fromString(data['role'] ?? 'moderator'),
      isActive: data['isActive'] ?? data['active'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      lastLoginAt: data['lastLoginAt'] != null
          ? (data['lastLoginAt'] as Timestamp).toDate()
          : null,
      permissions: List<String>.from(data['permissions'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'fullName': fullName,
      'role': role.value,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt':
          lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'permissions': permissions,
    };
  }

  bool hasPermission(String permission) {
    if (role == AdminRole.superAdmin) return true;
    return permissions.contains(permission);
  }

  bool canManageUsers() {
    return role == AdminRole.superAdmin || hasPermission('manage_users');
  }

  bool canManageReports() {
    return hasPermission('manage_reports');
  }

  bool canAssignReports() {
    return role != AdminRole.moderator || hasPermission('assign_reports');
  }

  AdminUser copyWith({
    String? email,
    String? fullName,
    AdminRole? role,
    bool? isActive,
    DateTime? lastLoginAt,
    List<String>? permissions,
  }) {
    return AdminUser(
      uid: uid,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      permissions: permissions ?? this.permissions,
    );
  }
}
