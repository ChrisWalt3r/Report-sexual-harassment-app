class RoleAccess {
  static String normalizeRoleKey(String? rawRole) {
    final compact = (rawRole ?? '')
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toLowerCase();

    switch (compact) {
      case 'devteam':
        return 'devTeam';
      case 'superadmin':
      case 'admin':
      case 'administrator':
        return 'superAdmin';
      case 'chairperson':
        return 'chairperson';
      case 'committeemember':
      case 'committee':
        return 'committeeMember';
      case 'adhocmember':
        return 'adHocMember';
      case 'advisor':
        return 'advisor';
      case 'studentrep':
        return 'studentRep';
      case 'technicalofficer':
      case 'technical':
        return 'technicalOfficer';
      case 'reviewer':
        return 'reviewer';
      case 'moderator':
        return 'moderator';
      default:
        return 'moderator';
    }
  }

  static String displayName(String roleKey) {
    switch (normalizeRoleKey(roleKey)) {
      case 'devTeam':
        return 'Dev Team';
      case 'superAdmin':
        return 'Super Admin';
      case 'chairperson':
        return 'Chairperson';
      case 'committeeMember':
        return 'Committee Member';
      case 'adHocMember':
        return 'Ad Hoc Member';
      case 'advisor':
        return 'Advisor';
      case 'studentRep':
        return 'Student Representative';
      case 'technicalOfficer':
        return 'Technical Officer';
      case 'reviewer':
        return 'Reviewer';
      case 'moderator':
      default:
        return 'Moderator';
    }
  }

  static bool canManageUsers(String roleKey) {
    final role = normalizeRoleKey(roleKey);
    return role == 'devTeam' || role == 'superAdmin';
  }

  static bool canInviteUsers(String roleKey) {
    final role = normalizeRoleKey(roleKey);
    return role == 'devTeam' || role == 'superAdmin' || role == 'chairperson';
  }

  static bool canEditSystemSettings(String roleKey) {
    final role = normalizeRoleKey(roleKey);
    return role == 'devTeam' || role == 'superAdmin';
  }

  static bool canAccessAssignments(String roleKey) {
    final role = normalizeRoleKey(roleKey);
    return role == 'devTeam' ||
        role == 'superAdmin' ||
        role == 'chairperson';
  }

  static bool canManageCategoryAssignments(String roleKey) {
    final role = normalizeRoleKey(roleKey);
    return role == 'devTeam' || role == 'superAdmin' || role == 'chairperson';
  }

  static bool canSuspendUsers(String roleKey) {
    final role = normalizeRoleKey(roleKey);
    return role == 'devTeam' || role == 'superAdmin';
  }
}
