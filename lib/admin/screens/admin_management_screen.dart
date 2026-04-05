import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/admin_user.dart';
import '../../services/admin_auth_service.dart';
import '../../constants/app_colors.dart';

// ---------------------------------------------------------------------------
// ROLE SYSTEM
// The SHC role hierarchy, from highest authority to narrowest scope.
// Dev team members are identified by their UIDs and can never be removed
// or demoted through the UI — only via the Firebase Console directly.
// ---------------------------------------------------------------------------

enum SHCRole {
  // ── Internal / technical ──────────────────────────────────────────
  devTeam,          // Developer team — full system access, cannot be managed via UI
  superAdmin,       // Institution-level super admin (e.g. HR Director)

  // ── Harassment Committee ──────────────────────────────────────────
  chairperson,      // Heads the Sexual Harassment Committee
  committeeMember,  // Standing committee member
  adHocMember,      // Temporary member for a specific case

  // ── Support roles ─────────────────────────────────────────────────
  advisor,          // External advisor / legal counsel
  studentRep,       // Student representative (involved if student is a party)
  technicalOfficer, // IT / records officer — view-only on most case data
}

extension SHCRoleX on SHCRole {
  String get displayName {
    switch (this) {
      case SHCRole.devTeam:          return 'Dev Team';
      case SHCRole.superAdmin:       return 'Super Admin';
      case SHCRole.chairperson:      return 'Chairperson';
      case SHCRole.committeeMember:  return 'Committee Member';
      case SHCRole.adHocMember:      return 'Ad Hoc Member';
      case SHCRole.advisor:          return 'Advisor';
      case SHCRole.studentRep:       return 'Student Representative';
      case SHCRole.technicalOfficer: return 'Technical Officer';
    }
  }

  String get description {
    switch (this) {
      case SHCRole.devTeam:
        return 'Full system access. Manages infrastructure and technical configuration.';
      case SHCRole.superAdmin:
        return 'Institution-level administrator. Manages committees and system settings.';
      case SHCRole.chairperson:
        return 'Heads the Sexual Harassment Committee. Assigns cases and oversees proceedings.';
      case SHCRole.committeeMember:
        return 'Standing member of the Sexual Harassment Committee. Reviews and adjudicates cases.';
      case SHCRole.adHocMember:
        return 'Temporary committee member appointed for a specific case or period.';
      case SHCRole.advisor:
        return 'External advisor or legal counsel. Provides guidance on proceedings.';
      case SHCRole.studentRep:
        return 'Student representative. Involved when a student is a party to a case.';
      case SHCRole.technicalOfficer:
        return 'IT or records officer. Manages documentation and technical records.';
    }
  }

  /// Firestore string representation
  String get firestoreKey {
    switch (this) {
      case SHCRole.devTeam:          return 'devTeam';
      case SHCRole.superAdmin:       return 'superAdmin';
      case SHCRole.chairperson:      return 'chairperson';
      case SHCRole.committeeMember:  return 'committeeMember';
      case SHCRole.adHocMember:      return 'adHocMember';
      case SHCRole.advisor:          return 'advisor';
      case SHCRole.studentRep:       return 'studentRep';
      case SHCRole.technicalOfficer: return 'technicalOfficer';
    }
  }

  static SHCRole fromFirestore(String? value) {
    switch (value?.trim()) {
      case 'devTeam':          return SHCRole.devTeam;
      case 'dev_team':         return SHCRole.devTeam;
      case 'superAdmin':       return SHCRole.superAdmin;
      case 'super_admin':      return SHCRole.superAdmin;
      case 'chairperson':      return SHCRole.chairperson;
      case 'committeeMember':  return SHCRole.committeeMember;
      case 'committee_member': return SHCRole.committeeMember;
      case 'adHocMember':      return SHCRole.adHocMember;
      case 'ad_hoc_member':    return SHCRole.adHocMember;
      case 'advisor':          return SHCRole.advisor;
      case 'studentRep':       return SHCRole.studentRep;
      case 'student_rep':      return SHCRole.studentRep;
      case 'technicalOfficer': return SHCRole.technicalOfficer;
      case 'technical_officer': return SHCRole.technicalOfficer;
      default:                 return SHCRole.committeeMember;
    }
  }

  Color get color {
    switch (this) {
      case SHCRole.devTeam:          return const Color(0xFF6C3FC5); // Deep purple
      case SHCRole.superAdmin:       return const Color(0xFFD44000); // Burnt orange
      case SHCRole.chairperson:      return const Color(0xFF006B3C); // Forest green
      case SHCRole.committeeMember:  return const Color(0xFF0066CC); // Institutional blue
      case SHCRole.adHocMember:      return const Color(0xFF007A8A); // Teal
      case SHCRole.advisor:          return const Color(0xFF8B6914); // Amber/gold
      case SHCRole.studentRep:       return const Color(0xFF5C6BC0); // Indigo
      case SHCRole.technicalOfficer: return const Color(0xFF455A64); // Blue-grey
    }
  }

  IconData get icon {
    switch (this) {
      case SHCRole.devTeam:          return Icons.code;
      case SHCRole.superAdmin:       return Icons.shield;
      case SHCRole.chairperson:      return Icons.gavel;
      case SHCRole.committeeMember:  return Icons.people;
      case SHCRole.adHocMember:      return Icons.person_add_alt;
      case SHCRole.advisor:          return Icons.balance;
      case SHCRole.studentRep:       return Icons.school;
      case SHCRole.technicalOfficer: return Icons.settings_applications;
    }
  }

  /// Hierarchy level — lower = more authority
  int get hierarchyLevel {
    switch (this) {
      case SHCRole.devTeam:          return 0;
      case SHCRole.superAdmin:       return 1;
      case SHCRole.chairperson:      return 2;
      case SHCRole.committeeMember:  return 3;
      case SHCRole.adHocMember:      return 4;
      case SHCRole.advisor:          return 5;
      case SHCRole.studentRep:       return 6;
      case SHCRole.technicalOfficer: return 7;
    }
  }

  bool get isProtected => this == SHCRole.devTeam;

  // ── Permission gates ──────────────────────────────────────────────

  bool get canManageUsers =>
      this == SHCRole.devTeam || this == SHCRole.superAdmin;

  bool get canInviteUsers =>
      this == SHCRole.devTeam ||
      this == SHCRole.superAdmin ||
      this == SHCRole.chairperson;

  bool get canViewAllCases =>
      this == SHCRole.devTeam ||
      this == SHCRole.superAdmin ||
      this == SHCRole.chairperson ||
      this == SHCRole.committeeMember;

  bool get canEditSystemSettings =>
      this == SHCRole.devTeam || this == SHCRole.superAdmin;

  bool get canDeleteUsers => this == SHCRole.devTeam;

  bool get canPromoteToSuperAdmin => this == SHCRole.devTeam;
}

// ---------------------------------------------------------------------------
// AdminManagementScreen
// ---------------------------------------------------------------------------

class AdminManagementScreen extends StatefulWidget {
  final bool embedded;
  const AdminManagementScreen({super.key, this.embedded = false});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen>
    with SingleTickerProviderStateMixin {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  SHCRole? _roleFilter;
  late TabController _tabController;

  // Dev-team UIDs and emails are the ground truth.
  // In production, seed these from your Firebase project's first deployment.
  static const Set<String> _devTeamEmails = {
    'dev@shc-system.app',
    'lead@shc-system.app',
    // Add real dev team emails here
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  bool _isDevTeam(Map<String, dynamic> data) {
    final role  = data['role']  as String? ?? '';
    final email = data['email'] as String? ?? '';
    return role == SHCRole.devTeam.firestoreKey ||
        _devTeamEmails.contains(email.toLowerCase());
  }

  bool _canActOn(SHCRole currentUserRole, SHCRole targetRole) {
    // Cannot manage dev team members through the UI
    if (targetRole == SHCRole.devTeam) return false;
    // Can only manage roles below yours in the hierarchy
    return currentUserRole.hierarchyLevel < targetRole.hierarchyLevel;
  }

  // -------------------------------------------------------------------------
  // Dialogs
  // -------------------------------------------------------------------------

  void _showCreateAdminDialog(SHCRole currentUserRole) {
    final emailCtrl    = TextEditingController();
    final passwordCtrl = TextEditingController();
    final nameCtrl     = TextEditingController();
    var selectedRole   = SHCRole.committeeMember;
    var isLoading      = false;
    var obscurePassword = true;

    // Roles the current user may create
    final allowedRoles = SHCRole.values
        .where((r) =>
            !r.isProtected &&
            (currentUserRole == SHCRole.devTeam ||
          r.hierarchyLevel > currentUserRole.hierarchyLevel ||
          (currentUserRole == SHCRole.superAdmin &&
            r == SHCRole.superAdmin)))
        .toList()
      ..sort((a, b) => a.hierarchyLevel.compareTo(b.hierarchyLevel));

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: EdgeInsets.zero,
          title: _DialogHeader(
            icon: Icons.person_add,
            title: 'Add Committee Member',
            subtitle: 'Create a new account and assign a role',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FormField(
                    controller: nameCtrl,
                    label: 'Full Name',
                    icon: Icons.badge_outlined,
                    hint: 'e.g. Dr. Jane Mukasa',
                  ),
                  const SizedBox(height: 14),
                  _FormField(
                    controller: emailCtrl,
                    label: 'Institutional Email',
                    icon: Icons.email_outlined,
                    hint: 'e.g. j.mukasa@must.ac.ug',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 14),
                  // Password field with toggle
                  StatefulBuilder(
                    builder: (_, setPass) => TextFormField(
                      controller: passwordCtrl,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: 'Temporary Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () =>
                              setPass(() => obscurePassword = !obscurePassword),
                        ),
                        hintText: 'Min 8 characters',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Role selector
                  const Text('Role',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  ...allowedRoles.map((role) {
                    final selected = selectedRole == role;
                    return GestureDetector(
                      onTap: () => setS(() => selectedRole = role),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                          color: selected
                              ? role.color.withOpacity(0.08)
                              : Colors.grey.shade50,
                          border: Border.all(
                            color: selected
                                ? role.color
                                : Colors.grey.shade300,
                            width: selected ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: role.color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(role.icon, size: 16, color: role.color),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(role.displayName,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: selected
                                            ? role.color
                                            : Colors.black87)),
                                Text(role.description,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle,
                                color: role.color, size: 18),
                        ]),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              icon: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.person_add, size: 18),
              label: const Text('Create Account'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen),
              onPressed: isLoading
                  ? null
                  : () async {
                      final name  = nameCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final pass  = passwordCtrl.text;

                      if (name.isEmpty || email.isEmpty || pass.isEmpty) {
                        _showError(ctx, 'Please fill in all fields.');
                        return;
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
                        _showError(ctx, 'Enter a valid email address.');
                        return;
                      }
                      if (pass.length < 8) {
                        _showError(
                            ctx, 'Password must be at least 8 characters.');
                        return;
                      }

                      setS(() => isLoading = true);
                      try {
                        final svc = context.read<AdminAuthService>();
                        await svc.createAdmin(
                          email: email,
                          password: pass,
                          fullName: name,
                          role: _mapToAdminRole(selectedRole),
                        );
                        // Write extended role data to Firestore
                        final query = await _firestore
                            .collection('admins')
                            .where('email', isEqualTo: email)
                            .limit(1)
                            .get();
                        if (query.docs.isNotEmpty) {
                          await query.docs.first.reference.set({
                            'shcRole':    selectedRole.firestoreKey,
                            'invitedAt':  FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));
                        }
                        await _writeAuditLog(
                          action:     'create_admin',
                          targetType: 'admin',
                          targetId:   email,
                          details:    'Created $name as ${selectedRole.displayName}',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSuccess('Account created for $name.');
                      } catch (e) {
                        if (ctx.mounted) _showError(ctx, e.toString());
                      } finally {
                        setS(() => isLoading = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditAdminDialog(
      Map<String, dynamic> data, String docId, SHCRole currentUserRole) {
    final targetRole = SHCRoleX.fromFirestore(
        (data['shcRole'] ?? data['role']) as String?);
    var selectedRole = targetRole;
    var isActive     = data['active'] != false;
    var isLoading    = false;

    final allowedRoles = SHCRole.values
      .where((r) {
        final canAssign = currentUserRole == SHCRole.devTeam ||
          r.hierarchyLevel > currentUserRole.hierarchyLevel;
        final isCurrentRole = r == targetRole;
        return !r.isProtected && (canAssign || isCurrentRole);
      })
        .toList()
      ..sort((a, b) => a.hierarchyLevel.compareTo(b.hierarchyLevel));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          titlePadding: EdgeInsets.zero,
          title: _DialogHeader(
            icon: Icons.edit_note,
            title: 'Edit Member',
            subtitle: (data['email'] as String?) ?? '',
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Role',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<SHCRole>(
                  value: selectedRole,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    prefixIcon:
                        Icon(selectedRole.icon, color: selectedRole.color),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                  ),
                  items: allowedRoles
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Row(children: [
                              Container(
                                width: 10,
                                height: 10,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: r.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(r.displayName),
                            ]),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setS(() => selectedRole = v);
                  },
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(
                      isActive ? Icons.check_circle : Icons.cancel,
                      color: isActive ? Colors.green : Colors.red,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Account Active',
                            style: TextStyle(fontWeight: FontWeight.w500))),
                    Switch(
                      value: isActive,
                      activeColor: AppColors.primaryGreen,
                      onChanged: (v) => setS(() => isActive = v),
                    ),
                  ]),
                ),
                if (selectedRole != targetRole || isActive != (data['active'] != false))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        border:
                            Border.all(color: Colors.orange.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline,
                            color: Colors.orange, size: 16),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Changes take effect immediately.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.deepOrange),
                          ),
                        ),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton.icon(
              icon: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: const Text('Save Changes'),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen),
              onPressed: isLoading
                  ? null
                  : () async {
                      setS(() => isLoading = true);
                      try {
                        await _firestore
                            .collection('admins')
                            .doc(docId)
                            .update({
                          'shcRole': selectedRole.firestoreKey,
                          'role':    _mapToAdminRole(selectedRole).name,
                          'active':  isActive,
                        });
                        await _writeAuditLog(
                          action:     'edit_admin',
                          targetType: 'admin',
                          targetId:   (data['email'] as String?) ?? docId,
                          details:
                              'Changed role to ${selectedRole.displayName}, '
                              'active=$isActive',
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showSuccess('Member updated.');
                      } catch (e) {
                        if (ctx.mounted) _showError(ctx, e.toString());
                      } finally {
                        setS(() => isLoading = false);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteAdminDialog(
      Map<String, dynamic> data, String docId) {
    final name = (data['fullName'] ?? data['email'] ?? 'this member') as String;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: _DialogHeader(
            icon: Icons.delete_forever,
            iconColor: Colors.red,
            title: 'Remove Member',
            subtitle: 'This action cannot be undone.'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to permanently remove:'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(children: [
                const Icon(Icons.person, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Text(name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
            ),
            const SizedBox(height: 12),
            const Text(
              'Their account and access will be revoked immediately. '
              'Case history and audit logs are preserved.',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Remove Member'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                final svc = context.read<AdminAuthService>();
                await svc.deleteAdmin(docId);
                await _writeAuditLog(
                  action:     'delete_admin',
                  targetType: 'admin',
                  targetId:   (data['email'] as String?) ?? docId,
                  details:    'Removed member $name',
                );
                if (ctx.mounted) Navigator.pop(ctx);
                _showSuccess('$name has been removed.');
              } catch (e) {
                if (ctx.mounted) _showError(ctx, e.toString());
              }
            },
          ),
        ],
      ),
    );
  }

  void _showRoleHierarchyDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titlePadding: EdgeInsets.zero,
        title: _DialogHeader(
          icon: Icons.account_tree,
          title: 'Role Hierarchy',
          subtitle: 'Permission levels and responsibilities',
        ),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: SHCRole.values.map((role) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    border: Border.all(color: role.color.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: role.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(role.icon, color: role.color, size: 20),
                    ),
                    title: Row(children: [
                      Text(role.displayName,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: role.color)),
                      const SizedBox(width: 8),
                      if (role.isProtected)
                        _Badge(label: 'PROTECTED', color: Colors.purple),
                    ]),
                    subtitle: Text(role.description,
                        style: const TextStyle(fontSize: 12)),
                    dense: true,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Utilities
  // -------------------------------------------------------------------------

  /// Maps SHCRole → the legacy AdminRole enum used by AdminAuthService.
  /// Chairperson and committee roles map to superAdmin/moderator until
  /// AdminAuthService is updated to accept SHCRole directly.
  AdminRole _mapToAdminRole(SHCRole shcRole) {
    switch (shcRole) {
      case SHCRole.devTeam:
      case SHCRole.superAdmin:
        return AdminRole.superAdmin;
      case SHCRole.chairperson:
      case SHCRole.committeeMember:
      case SHCRole.adHocMember:
      case SHCRole.advisor:
      case SHCRole.studentRep:
      case SHCRole.technicalOfficer:
        return AdminRole.moderator;
    }
  }

  Future<void> _writeAuditLog({
    required String action,
    required String targetType,
    required String targetId,
    required String details,
  }) async {
    await _firestore.collection('audit_logs').add({
      'action':      action,
      'performedBy': context.read<AdminAuthService>().currentAdminEmail ?? 'Unknown',
      'targetType':  targetType,
      'targetId':    targetId,
      'details':     details,
      'timestamp':   FieldValue.serverTimestamp(),
    });
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Text(message),
      ]),
      backgroundColor: Colors.green.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showError(BuildContext ctx, String message) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AdminUser?>(
      future: context.read<AdminAuthService>().getCurrentAdmin(),
      builder: (context, adminSnapshot) {
        final currentAdmin   = adminSnapshot.data;
        final currentShcRole = SHCRoleX.fromFirestore(
            currentAdmin?.role.name ?? 'committeeMember');

        final body = Column(
          children: [
            // ── Toolbar ─────────────────────────────────────────────
            _buildToolbar(currentShcRole),
            // ── Stats strip ─────────────────────────────────────────
            _buildStatsStrip(),
            // ── Member list ─────────────────────────────────────────
            Expanded(child: _buildMemberList(currentShcRole)),
          ],
        );

        if (widget.embedded) {
          return Stack(
            children: [
              body,
              if (currentShcRole.canInviteUsers)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: FloatingActionButton.extended(
                    heroTag: 'admin_mgmt_fab',
                    onPressed: () => _showCreateAdminDialog(currentShcRole),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Member'),
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                  ),
                ),
            ],
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: AppBar(
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Committee Members',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
                Text('Sexual Harassment Committee',
                    style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
            backgroundColor: AppColors.primaryGreen,
            foregroundColor: Colors.white,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.account_tree_outlined),
                tooltip: 'Role Hierarchy',
                onPressed: _showRoleHierarchyDialog,
              ),
              if (currentShcRole.canInviteUsers)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add Member'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _showCreateAdminDialog(currentShcRole),
                  ),
                ),
            ],
          ),
          body: body,
        );
      },
    );
  }

  Widget _buildToolbar(SHCRole currentShcRole) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by name or email…',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppColors.primaryGreen, width: 1.5),
              ),
              isDense: true,
            ),
            onChanged: (v) =>
                setState(() => _searchQuery = v.toLowerCase()),
          ),
        ),
        const SizedBox(width: 10),
        // Role filter
        _RoleFilterChip(
          selected: _roleFilter,
          onChanged: (r) => setState(() => _roleFilter = r),
        ),
        const SizedBox(width: 10),
        // Role hierarchy reference
        OutlinedButton.icon(
          icon: const Icon(Icons.account_tree_outlined, size: 16),
          label: const Text('Roles'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: _showRoleHierarchyDialog,
        ),
      ]),
    );
  }

  Widget _buildStatsStrip() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('admins').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final docs = snapshot.data!.docs;

        final total   = docs.length;
        final active  = docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          return data['active'] != false;
        }).length;
        final byRole  = <SHCRole, int>{};
        for (final doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final role = SHCRoleX.fromFirestore(
              (data['shcRole'] ?? data['role']) as String?);
          byRole[role] = (byRole[role] ?? 0) + 1;
        }

        return Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(children: [
            _StatTile(value: '$total', label: 'Total', color: Colors.blueGrey),
            const SizedBox(width: 10),
            _StatTile(value: '$active', label: 'Active', color: Colors.green),
            const SizedBox(width: 10),
            _StatTile(
              value: '${byRole[SHCRole.committeeMember] ?? 0}',
              label: 'Committee',
              color: const Color(0xFF0066CC),
            ),
            const SizedBox(width: 10),
            _StatTile(
              value: '${byRole[SHCRole.chairperson] ?? 0}',
              label: 'Chairpersons',
              color: const Color(0xFF006B3C),
            ),
          ]),
        );
      },
    );
  }

  Widget _buildMemberList(SHCRole currentShcRole) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('admins').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        var docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final role  = SHCRoleX.fromFirestore(
              (data['shcRole'] ?? data['role']) as String?);
          if (_roleFilter != null && role != _roleFilter) return false;
          if (_searchQuery.isEmpty) return true;
          final name  = (data['fullName'] ?? '') as String;
          final email = (data['email']    ?? '') as String;
          return name.toLowerCase().contains(_searchQuery) ||
              email.toLowerCase().contains(_searchQuery);
        }).toList();

        // Sort by hierarchy level then name
        docs.sort((a, b) {
          final da = a.data() as Map<String, dynamic>;
          final db = b.data() as Map<String, dynamic>;
          final ra = SHCRoleX.fromFirestore((da['shcRole'] ?? da['role']) as String?);
          final rb = SHCRoleX.fromFirestore((db['shcRole'] ?? db['role']) as String?);
          if (ra.hierarchyLevel != rb.hierarchyLevel) {
            return ra.hierarchyLevel.compareTo(rb.hierarchyLevel);
          }
          return ((da['fullName'] ?? '') as String)
              .compareTo((db['fullName'] ?? '') as String);
        });

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty || _roleFilter != null
                      ? 'No members match the current filter.'
                      : 'No committee members found.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
                if (_searchQuery.isNotEmpty || _roleFilter != null)
                  TextButton(
                    onPressed: () => setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                      _roleFilter = null;
                    }),
                    child: const Text('Clear filters'),
                  ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc  = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _MemberCard(
              data:             data,
              docId:            doc.id,
              currentShcRole:   currentShcRole,
              canActOn:         _canActOn,
              onEdit: (d, id) =>
                  _showEditAdminDialog(d, id, currentShcRole),
              onDelete: (d, id) => _showDeleteAdminDialog(d, id),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _MemberCard
// ---------------------------------------------------------------------------

class _MemberCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  final SHCRole currentShcRole;
  final bool Function(SHCRole current, SHCRole target) canActOn;
  final void Function(Map<String, dynamic>, String) onEdit;
  final void Function(Map<String, dynamic>, String) onDelete;

  const _MemberCard({
    required this.data,
    required this.docId,
    required this.currentShcRole,
    required this.canActOn,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name      = (data['fullName'] ?? data['email'] ?? 'Unknown') as String;
    final email     = (data['email']    ?? '') as String;
    final isActive  = data['active'] != false;
    final shcRole   = SHCRoleX.fromFirestore(
        (data['shcRole'] ?? data['role']) as String?);
    final isDevTeam = shcRole == SHCRole.devTeam;
    final canAct    = canActOn(currentShcRole, shcRole);

    final initials = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDevTeam
              ? shcRole.color.withOpacity(0.4)
              : Colors.grey.shade200,
          width: isDevTeam ? 1.5 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Avatar
          Stack(clipBehavior: Clip.none, children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    shcRole.color,
                    shcRole.color.withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
            ),
            if (!isActive)
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child:
                      const Icon(Icons.block, size: 8, color: Colors.white),
                ),
              ),
          ]),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(
                    child: Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 6),
                  if (isDevTeam)
                    _Badge(
                        label: 'PROTECTED',
                        color: shcRole.color,
                        icon: Icons.shield),
                ]),
                const SizedBox(height: 2),
                Text(email,
                    style: TextStyle(
                        color: Colors.grey.shade600, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  _RolePill(role: shcRole),
                  _StatusPill(isActive: isActive),
                ]),
              ],
            ),
          ),

          // Actions
          if (canAct && currentShcRole.canManageUsers)
            PopupMenuButton<String>(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              offset: const Offset(0, 8),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: const [
                    Icon(Icons.edit_outlined, size: 18),
                    SizedBox(width: 10),
                    Text('Edit Member'),
                  ]),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.person_remove_outlined,
                        size: 18, color: Colors.red),
                    const SizedBox(width: 10),
                    Text('Remove Member',
                        style: TextStyle(color: Colors.red.shade700)),
                  ]),
                ),
              ],
              onSelected: (v) {
                if (v == 'edit')   onEdit(data, docId);
                if (v == 'delete') onDelete(data, docId);
              },
            )
          else if (!canAct && !isDevTeam)
            Tooltip(
              message: 'Insufficient permissions',
              child: Icon(Icons.lock_outline,
                  size: 18, color: Colors.grey.shade400),
            ),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small shared widgets
// ---------------------------------------------------------------------------

class _DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? iconColor;
  const _DialogHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? AppColors.primaryGreen;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String hint;
  final TextInputType keyboardType;
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.hint,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final SHCRole role;
  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: role.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: role.color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(role.icon, size: 11, color: role.color),
        const SizedBox(width: 4),
        Text(role.displayName,
            style: TextStyle(
                fontSize: 11,
                color: role.color,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool isActive;
  const _StatusPill({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          isActive ? Icons.circle : Icons.circle,
          size: 7,
          color: isActive ? Colors.green.shade600 : Colors.red.shade600,
        ),
        const SizedBox(width: 4),
        Text(isActive ? 'Active' : 'Inactive',
            style: TextStyle(
                fontSize: 11,
                color: isActive
                    ? Colors.green.shade700
                    : Colors.red.shade700,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Badge({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
        ],
        Text(label,
            style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: color,
                letterSpacing: 0.5)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatTile(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
      ]),
    );
  }
}

class _RoleFilterChip extends StatelessWidget {
  final SHCRole? selected;
  final ValueChanged<SHCRole?> onChanged;
  const _RoleFilterChip({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final result = await showMenu<SHCRole?>(
          context: context,
          position: _buttonPosition(context),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          items: [
            const PopupMenuItem<SHCRole?>(
              value: null,
              child: Text('All Roles'),
            ),
            ...SHCRole.values.map((r) => PopupMenuItem<SHCRole?>(
                  value: r,
                  child: Row(children: [
                    Icon(r.icon, size: 16, color: r.color),
                    const SizedBox(width: 8),
                    Text(r.displayName),
                  ]),
                )),
          ],
        );
        if (result != null || selected != null) {
          onChanged(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected != null
              ? selected!.color.withOpacity(0.08)
              : Colors.grey.shade50,
          border: Border.all(
            color: selected != null
                ? selected!.color.withOpacity(0.5)
                : Colors.grey.shade300,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          if (selected != null)
            Icon(selected!.icon, size: 16, color: selected!.color)
          else
            Icon(Icons.filter_list, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 6),
          Text(
            selected?.displayName ?? 'Filter by Role',
            style: TextStyle(
                fontSize: 13,
                color: selected != null
                    ? selected!.color
                    : Colors.grey.shade700),
          ),
          if (selected != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => onChanged(null),
              child: Icon(Icons.close, size: 14, color: selected!.color),
            ),
          ],
        ]),
      ),
    );
  }

  RelativeRect _buttonPosition(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return RelativeRect.fill;
    final offset = box.localToGlobal(Offset.zero);
    return RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + box.size.height + 4,
      offset.dx + box.size.width,
      0,
    );
  }
}