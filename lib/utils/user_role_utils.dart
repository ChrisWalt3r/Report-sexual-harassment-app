class UserRoleUtils {
  static const String otherRoleValue = 'Other';

  static const List<String> selectableRoles = [
    'Student',
    'Staff',
    'Cleaner',
    'Electrician',
    'Security',
    otherRoleValue,
  ];

  static bool isOtherRole(String? role) {
    return (role ?? '').trim() == otherRoleValue;
  }

  static bool isStudentRole(String? role) {
    return (role ?? '').trim() == 'Student';
  }

  static bool isStaffRole(String? role) {
    return (role ?? '').trim() == 'Staff';
  }

  static bool shouldShowFaculty(String? role) {
    return isStudentRole(role) || isStaffRole(role);
  }

  static bool shouldShowDepartment(String? role) {
    return shouldShowFaculty(role);
  }

  static bool shouldShowStudyLevel(String? role) {
    return isStudentRole(role);
  }

  static String displayIdLabel(String? role) {
    if (isStudentRole(role)) {
      return 'Student ID';
    }
    if (isStaffRole(role)) {
      return 'Staff ID';
    }
    return 'ID Number';
  }

  static String displayIdHint(String? role) {
    if (isStudentRole(role)) {
      return 'Enter your student ID';
    }
    if (isStaffRole(role)) {
      return 'Enter your staff ID';
    }
    return 'Enter your ID number';
  }

  static String displayRoleFromFields({
    String? role,
    String? otherRole,
    String fallback = 'Not provided',
  }) {
    final rawRole = (role ?? '').trim();
    final customRole = (otherRole ?? '').trim();

    if (rawRole.isEmpty) {
      return customRole.isNotEmpty ? customRole : fallback;
    }

    if (rawRole == otherRoleValue) {
      return customRole.isNotEmpty ? customRole : otherRoleValue;
    }

    return rawRole;
  }

  static String displayRoleFromData(
    Map<String, dynamic>? data, {
    String fallback = 'Not provided',
  }) {
    return displayRoleFromFields(
      role: data?['role']?.toString(),
      otherRole: data?['otherRole']?.toString(),
      fallback: fallback,
    );
  }

  static bool matchesRoleFilter(
    Map<String, dynamic>? data,
    String selectedRole,
  ) {
    if (selectedRole == 'all') return true;

    final rawRole = (data?['role'] ?? '').toString().trim();
    final customRole = (data?['otherRole'] ?? '').toString().trim();

    if (selectedRole == otherRoleValue) {
      if (rawRole == otherRoleValue) return true;
      if (customRole.isNotEmpty) return true;
      return rawRole.isNotEmpty && !selectableRoles.contains(rawRole);
    }

    return rawRole == selectedRole;
  }
}
