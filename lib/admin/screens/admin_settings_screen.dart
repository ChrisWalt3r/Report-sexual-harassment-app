import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../constants/app_colors.dart';
import '../../models/admin_user.dart';
import '../models/role_access.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audit_log_entry.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

// ---------------------------------------------------------------------------
// AdminSettingsScreen
// ---------------------------------------------------------------------------

class AdminSettingsScreen extends StatefulWidget {
  final AdminUser? admin;
  final bool embedded;
  const AdminSettingsScreen({super.key, this.admin, this.embedded = false});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<_SettingsTab> _tabs;
  String _currentRoleKey = 'moderator';

  @override
  void initState() {
    super.initState();
    _currentRoleKey =
        RoleAccess.normalizeRoleKey(widget.admin?.role.value ?? 'moderator');
    _tabs = _tabsForRole(_currentRoleKey);
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadCurrentRoleKey();
  }

  @override
  void didUpdateWidget(covariant AdminSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUid = oldWidget.admin?.uid;
    final newUid = widget.admin?.uid;
    if (oldUid != newUid) {
      final fallback =
          RoleAccess.normalizeRoleKey(widget.admin?.role.value ?? 'moderator');
      _retargetTabsForRole(fallback);
      _loadCurrentRoleKey();
    }
  }

  void _retargetTabsForRole(String roleKey) {
    final oldIndex = _tabController.index;
    final newTabs = _tabsForRole(roleKey);
    _tabController.dispose();
    final newController = TabController(length: newTabs.length, vsync: this);
    newController.index = oldIndex.clamp(0, newTabs.length - 1) as int;
    setState(() {
      _currentRoleKey = roleKey;
      _tabs = newTabs;
      _tabController = newController;
    });
  }

  List<_SettingsTab> _tabsForRole(String roleKey) {
    final canSystem = RoleAccess.canEditSystemSettings(roleKey);
    final canAssign = RoleAccess.canAccessAssignments(roleKey);
    return [
      _SettingsTab(icon: Icons.history,              label: 'Logs',          builder: _buildLogsTab),
      _SettingsTab(icon: Icons.notifications,        label: 'Notify',        builder: _buildNotificationsTab),
      _SettingsTab(icon: Icons.admin_panel_settings, label: 'Admins',        builder: _buildAdminsTab),
      _SettingsTab(icon: Icons.timer,                label: 'SLA',           builder: _buildSlaTab),
      _SettingsTab(icon: Icons.security,             label: 'Security',      builder: _buildSecurityTab),
      _SettingsTab(icon: Icons.email,                label: 'Templates',     builder: _buildEmailTemplatesTab),
      _SettingsTab(icon: Icons.manage_search,        label: 'Login History', builder: _buildLoginHistoryTab),
      if (canSystem)
        _SettingsTab(icon: Icons.settings,           label: 'System',        builder: _buildSystemTab),
      if (canAssign)
        _SettingsTab(icon: Icons.assignment_ind,     label: 'Assign',        builder: _buildChairpersonAssignTab),
    ];
  }

  Future<void> _loadCurrentRoleKey() async {
    final uid = widget.admin?.uid;
    final email = widget.admin?.email;
    if ((uid == null || uid.isEmpty) && (email == null || email.isEmpty)) {
      return;
    }

    try {
      Map<String, dynamic>? data;

      if (uid != null && uid.isNotEmpty) {
        final byUid =
            await FirebaseFirestore.instance.collection('admins').doc(uid).get();
        data = byUid.data();
      }

      if ((data == null || data.isEmpty) && email != null && email.isNotEmpty) {
        final byEmail = await FirebaseFirestore.instance
            .collection('admins')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (byEmail.docs.isNotEmpty) {
          data = byEmail.docs.first.data();
        }
      }

      final resolved = RoleAccess.normalizeRoleKey(
        (data?['shcRole'] ?? data?['role'] ?? widget.admin?.role.value)
            as String?,
      );
      if (!mounted || resolved == _currentRoleKey) return;
      _retargetTabsForRole(resolved);
    } catch (_) {
      // Keep fallback role from auth model if Firestore lookup fails.
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmbedded = widget.embedded;
    final tabBar = TabBar(
      controller: _tabController,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      indicatorColor: AppColors.primaryGreen,
      labelColor: AppColors.primaryGreen,
      unselectedLabelColor: Colors.grey,
      tabs: _tabs.map((t) => Tab(icon: Icon(t.icon), text: t.label)).toList(),
    );
    final tabView = TabBarView(
      controller: _tabController,
      children: _tabs.map((t) => t.builder()).toList(),
    );

    return Scaffold(
      appBar: isEmbedded
          ? null
          : AppBar(
              title: const Text('Admin Settings'),
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: Colors.white,
              bottom: tabBar,
            ),
      body: isEmbedded
          ? Column(children: [tabBar, Expanded(child: tabView)])
          : tabView,
    );
  }

  // =========================================================================
  // TAB BUILDERS
  // =========================================================================

  Widget _buildLogsTab()            => const _AuditLogTable();
  Widget _buildSlaTab()             => _SlaSettingsPanel(admin: widget.admin);
  Widget _buildSecurityTab()        => _SecuritySettingsPanel(admin: widget.admin);
  Widget _buildEmailTemplatesTab()  => _EmailTemplatesPanel(admin: widget.admin);
  Widget _buildLoginHistoryTab()    => const _LoginHistoryPanel();

  Widget _buildChairpersonAssignTab() => _CategoryAssignmentPanel(
        admin: widget.admin,
        currentRoleKey: _currentRoleKey,
      );

  Widget _buildNotificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsHeader(
            icon: Icons.notifications,
            title: 'Notifications Center',
            subtitle: 'Broadcast messages to user groups.',
          ),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.send),
              label: const Text('Send Notification'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white),
              onPressed: () => _showSendNotificationDialog(context),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              onPressed: () => setState(() {}),
            ),
          ]),
          const SizedBox(height: 16),
          const Expanded(child: _NotificationList()),
        ],
      ),
    );
  }

  void _showSendNotificationDialog(BuildContext context) {
    final messageController = TextEditingController();
    String recipient = 'all';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Send Notification'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                decoration: const InputDecoration(
                    labelText: 'Message', border: OutlineInputBorder()),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: recipient,
                items: const [
                  DropdownMenuItem(value: 'all',         child: Text('All Users')),
                  DropdownMenuItem(value: 'admins',      child: Text('Admins Only')),
                  DropdownMenuItem(value: 'committee',   child: Text('Committee')),
                  DropdownMenuItem(value: 'chairperson', child: Text('Chairperson')),
                ],
                onChanged: (v) => setDialogState(() => recipient = v ?? 'all'),
                decoration: const InputDecoration(labelText: 'Recipient Group'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white),
              onPressed: () async {
                final msg = messageController.text.trim();
                if (msg.isEmpty) return;
                await FirebaseFirestore.instance.collection('notifications').add({
                  'message':   msg,
                  'recipient': recipient,
                  'sentBy':    widget.admin?.email ?? 'Unknown',
                  'timestamp': Timestamp.now(),
                });
                await _writeAuditLog('notify', 'notification', null,
                    'Sent notification to $recipient');
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  _showSuccess('Notification sent to $recipient.');
                  setState(() {});
                }
              },
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminsTab() {
    final canInviteUsers = RoleAccess.canInviteUsers(_currentRoleKey);
    final canManageUsers = RoleAccess.canManageUsers(_currentRoleKey);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsHeader(
            icon: Icons.admin_panel_settings,
            title: 'Admin & Committee Management',
            subtitle: 'Manage roles, access, and committee membership.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10, runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('Invite Admin'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white),
                onPressed:
                  canInviteUsers ? () => _showInviteAdminDialog(context) : null,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                onPressed: () => setState(() {}),
              ),
              if (canManageUsers) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.group_add),
                  label: const Text('Create Ad Hoc Committee'),
                  onPressed: () => _showCreateAdHocCommitteeDialog(context),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Bulk Import CSV'),
                  onPressed: () => _showBulkImportDialog(context),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _AdminList(
              canManageUsers: canManageUsers,
              canSuspendUsers: RoleAccess.canSuspendUsers(_currentRoleKey),
              adminEmail: widget.admin?.email ?? '',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 2,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.rule_folder_outlined,
                    color: AppColors.primaryGreen,
                    size: 18,
                  ),
                ),
                title: const Text(
                  'Ad Hoc Committee Rules',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  '7 governance checks for constitution and assignment compliance',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
                children: [
                  ...[
                    'All members must have no previous allegations of sexual harassment.',
                    'No conflict of interest.',
                    'At least half of members are female.',
                    'Odd number of members.',
                    'Student reps only if students are involved.',
                    'No junior staff to investigate senior staff unless victim is junior.',
                    'If perpetrator is Top Management, Council committee investigates.',
                  ].asMap().entries.map((entry) {
                    final index = entry.key + 1;
                    final rule = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$index',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rule,
                              style: const TextStyle(fontSize: 13, height: 1.35),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateAdHocCommitteeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Ad Hoc Committee'),
        content: const Text(
            'Ad hoc committee creation UI coming soon. This will allow super admins to '
            'select members, enforce rules, and co-opt students as needed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showBulkImportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bulk Import Admins via CSV'),
        content: const Text(
            'Upload a CSV file with columns: email, role.\n\nCSV import UI coming soon.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showInviteAdminDialog(BuildContext context) {
    if (!RoleAccess.canInviteUsers(_currentRoleKey)) {
      _showError('You do not have permission to invite admin users.');
      return;
    }

    final emailController = TextEditingController();
    String selectedRole = 'committeeMember';
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Invite New Admin'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email is required';
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  items: const [
                    DropdownMenuItem(value: 'committeeMember', child: Text('Committee Member')),
                    DropdownMenuItem(value: 'chairperson', child: Text('Chairperson')),
                    DropdownMenuItem(value: 'adHocMember', child: Text('Ad Hoc Member')),
                    DropdownMenuItem(value: 'advisor',     child: Text('Advisor')),
                    DropdownMenuItem(value: 'studentRep',  child: Text('Student Representative')),
                    DropdownMenuItem(value: 'technicalOfficer', child: Text('Technical Officer')),
                    DropdownMenuItem(value: 'superAdmin',  child: Text('Super Admin')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => selectedRole = v ?? 'committeeMember'),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final email = emailController.text.trim();
                final token = const Uuid().v4();
                await FirebaseFirestore.instance.collection('admin_invites').add({
                  'email':     email,
                  'role':      selectedRole,
                  'invitedBy': widget.admin?.email ?? 'Unknown',
                  'timestamp': Timestamp.now(),
                  'token':     token,
                  'accepted':  false,
                });
                await _writeAuditLog(
                    'invite', 'admin_invite', email,
                    'Invited $email as $selectedRole');
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _showSuccess('Invite sent to $email.');
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: _SystemSettingsPanel(admin: widget.admin),
    );
  }

  // =========================================================================
  // SHARED HELPERS
  // =========================================================================

  Future<void> _writeAuditLog(
      String action, String targetType, String? targetId, String details) async {
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action':      action,
      'performedBy': widget.admin?.email ?? 'Unknown',
      'targetType':  targetType,
      if (targetId != null) 'targetId': targetId,
      'details':     details,
      'timestamp':   Timestamp.now(),
    });
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Text(message),
      ]),
      backgroundColor: Colors.green[700],
      duration: const Duration(seconds: 3),
    ));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.error_outline, color: Colors.white),
        const SizedBox(width: 8),
        Expanded(child: Text(message)),
      ]),
      backgroundColor: Colors.red[700],
      duration: const Duration(seconds: 3),
    ));
  }
}

// ===========================================================================
// _SettingsTab
// ===========================================================================

class _SettingsTab {
  final IconData icon;
  final String label;
  final Widget Function() builder;
  _SettingsTab({required this.icon, required this.label, required this.builder});
}

class _CategoryAssignmentPanel extends StatefulWidget {
  final AdminUser? admin;
  final String currentRoleKey;

  const _CategoryAssignmentPanel({
    required this.admin,
    required this.currentRoleKey,
  });

  @override
  State<_CategoryAssignmentPanel> createState() =>
      _CategoryAssignmentPanelState();
}

class _CategoryAssignmentPanelState extends State<_CategoryAssignmentPanel> {
  bool _loading = true;
  bool _saving = false;

  List<String> _categories = [];
  List<Map<String, dynamic>> _admins = [];
  Map<String, Map<String, dynamic>> _rulesByCategory = {};

  static const List<String> _fallbackCategories = [
    'Verbal Harassment',
    'Physical Harassment',
    'Online / Cyber Harassment',
    'Stalking',
    'Abuse of Authority',
    'Retaliation',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _loadAssignmentData();
  }

  String _normalizeDocId(String value) {
    final cleaned = value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return cleaned.isEmpty ? 'uncategorized' : cleaned;
  }

  String _resolveCategory(Map<String, dynamic> data) {
    final raw = data['category'] ?? data['reportCategory'] ?? data['type'];
    final value = (raw ?? '').toString().trim();
    return value.isEmpty ? 'Other' : value;
  }

  Future<void> _loadAssignmentData() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final reportsFuture = FirebaseFirestore.instance
          .collection('reports')
          .limit(1200)
          .get();
      final adminsFuture =
          FirebaseFirestore.instance.collection('admins').get();
      final rulesFuture = FirebaseFirestore.instance
          .collection('report_category_assignments')
          .get();

      final results = await Future.wait([reportsFuture, adminsFuture, rulesFuture]);

      final reports = results[0] as QuerySnapshot;
      final admins = results[1] as QuerySnapshot;
      final rules = results[2] as QuerySnapshot;

      final categories = <String>{..._fallbackCategories};
      for (final doc in reports.docs) {
        final data = doc.data() as Map<String, dynamic>;
        categories.add(_resolveCategory(data));
      }

      final assignableAdmins = admins.docs
          .map((d) {
            final data = d.data() as Map<String, dynamic>;
            final roleKey = RoleAccess.normalizeRoleKey(
              (data['shcRole'] ?? data['role']) as String?,
            );
            final isActive = data['active'] != false && data['isActive'] != false;
            return {
              'uid': d.id,
              'email': (data['email'] ?? '').toString(),
              'name': (data['fullName'] ?? data['name'] ?? 'Unnamed').toString(),
              'roleKey': roleKey,
              'isActive': isActive,
            };
          })
          .where((a) {
            final role = a['roleKey'] as String;
            final active = a['isActive'] as bool;
            if (!active) return false;
            return role == 'chairperson' ||
                role == 'committeeMember' ||
                role == 'adHocMember' ||
                role == 'advisor' ||
                role == 'technicalOfficer' ||
                role == 'studentRep' ||
                role == 'superAdmin';
          })
          .toList()
        ..sort((a, b) =>
            (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase()));

      final ruleMap = <String, Map<String, dynamic>>{};
      for (final doc in rules.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final category = (data['category'] ?? '').toString().trim();
        if (category.isEmpty) continue;
        ruleMap[category] = {'id': doc.id, ...data};
      }

      if (!mounted) return;
      setState(() {
        _categories = categories.toList()..sort();
        _admins = assignableAdmins;
        _rulesByCategory = ruleMap;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load assignments: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Future<void> _saveCategoryAssignment(
    String category,
    Map<String, dynamic>? assignee,
  ) async {
    if (!RoleAccess.canManageCategoryAssignments(widget.currentRoleKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to manage assignments.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final docId = _normalizeDocId(category);
      final ref = FirebaseFirestore.instance
          .collection('report_category_assignments')
          .doc(docId);

      final payload = <String, dynamic>{
        'category': category,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.admin?.email ?? 'Unknown',
      };

      if (assignee == null) {
        payload.addAll({
          'active': false,
          'assigneeUid': null,
          'assigneeEmail': null,
          'assigneeName': null,
          'assigneeRole': null,
        });
      } else {
        payload.addAll({
          'active': true,
          'assigneeUid': assignee['uid'],
          'assigneeEmail': assignee['email'],
          'assigneeName': assignee['name'],
          'assigneeRole': assignee['roleKey'],
        });
      }

      await ref.set(payload, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'category_assignment_update',
        'performedBy': widget.admin?.email ?? 'Unknown',
        'targetType': 'report_category_assignment',
        'targetId': category,
        'details': assignee == null
            ? 'Unassigned category "$category"'
            : 'Assigned "$category" to ${assignee['name']} (${assignee['email']})',
        'timestamp': Timestamp.now(),
      });

      if (!mounted) return;
      setState(() {
        _rulesByCategory[category] = {
          ...?_rulesByCategory[category],
          'category': category,
          'active': assignee != null,
          'assigneeUid': assignee?['uid'],
          'assigneeEmail': assignee?['email'],
          'assigneeName': assignee?['name'],
          'assigneeRole': assignee?['roleKey'],
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            assignee == null
                ? 'Category unassigned.'
                : 'Assignment saved for "$category".',
          ),
          backgroundColor: Colors.green[700],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save assignment: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final canManage =
        RoleAccess.canManageCategoryAssignments(widget.currentRoleKey);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsHeader(
            icon: Icons.assignment_ind,
            title: 'Category Assignment Rules',
            subtitle:
                'Route report categories to committee members by governance role.',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  canManage
                      ? 'Chairperson and higher privileges can assign default handlers per category.'
                      : 'View-only mode: only Chairperson, Super Admin, or Dev Team can edit assignments.',
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _loadAssignmentData,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _categories.isEmpty
                ? Center(
                    child: Text(
                      'No categories found yet.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.separated(
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final rule = _rulesByCategory[category];
                      final assignedUid = (rule?['assigneeUid'] as String?);
                      final currentAssignee = assignedUid == null
                          ? null
                          : _admins.cast<Map<String, dynamic>?>().firstWhere(
                              (a) => a?['uid'] == assignedUid,
                              orElse: () => null,
                            );

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                category,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: DropdownButtonFormField<String>(
                                value: currentAssignee?['uid'] as String?,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  labelText: 'Assigned handler',
                                  isDense: true,
                                ),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Unassigned'),
                                  ),
                                  ..._admins.map(
                                    (a) => DropdownMenuItem<String>(
                                      value: a['uid'] as String,
                                      child: Text(
                                        '${a['name']} (${RoleAccess.displayName(a['roleKey'] as String)})',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                                onChanged: (!canManage || _saving)
                                    ? null
                                    : (value) {
                                        final assignee = value == null
                                            ? null
                                            : _admins.firstWhere(
                                                (a) => a['uid'] == value,
                                                orElse: () => <String, dynamic>{},
                                              );
                                        _saveCategoryAssignment(
                                          category,
                                          assignee == null || assignee.isEmpty
                                              ? null
                                              : assignee,
                                        );
                                      },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// _SettingsHeader — consistent section title
// ===========================================================================

class _SettingsHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _SettingsHeader({
    required this.icon, required this.title, required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primaryGreen),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}

// ===========================================================================
// _AuditLogTable
// ===========================================================================

class _AuditLogTable extends StatefulWidget {
  const _AuditLogTable();
  @override
  State<_AuditLogTable> createState() => _AuditLogTableState();
}

class _AuditLogTableState extends State<_AuditLogTable> {
  List<AuditLogEntry> _logs = [];
  bool _loading = true;
  String _search = '';
  String _actionFilter = 'All';
  int _rowsPerPage = 10;
  int _page = 0;

  final List<String> _actions = [
    'All', 'edit', 'delete', 'login', 'assign', 'invite', 'revoke',
    'role_change', 'system_update', 'notify', 'sla_update',
    'security_update', 'template_update', 'conflict_flag',
  ];

  static const Map<String, Color> _actionColors = {
    'delete':          Colors.red,
    'revoke':          Colors.red,
    'invite':          Colors.blue,
    'role_change':     Colors.orange,
    'system_update':   Colors.purple,
    'security_update': Colors.deepOrange,
    'notify':          Colors.teal,
    'login':           Colors.green,
    'conflict_flag':   Colors.amber,
  };

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final query = await FirebaseFirestore.instance
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .get();
    if (!mounted) return;
    setState(() {
      _logs = query.docs.map((d) => AuditLogEntry.fromFirestore(d)).toList();
      _loading = false;
    });
  }

  List<AuditLogEntry> get _filteredLogs {
    var logs = _logs;
    if (_actionFilter != 'All') {
      logs = logs.where((l) => l.action == _actionFilter).toList();
    }
    if (_search.isNotEmpty) {
      final q = _search.toLowerCase();
      logs = logs.where((l) =>
          l.performedBy.toLowerCase().contains(q) ||
          (l.details  ?? '').toLowerCase().contains(q) ||
          (l.targetId ?? '').toLowerCase().contains(q)).toList();
    }
    return logs;
  }

  Future<void> _exportPDF() async {
    final pdf = pw.Document();
    final headers = ['Action', 'By', 'Target', 'Type', 'Details', 'Time'];
    final data = _filteredLogs.map((l) => [
      l.action,
      l.performedBy,
      l.targetId   ?? '',
      l.targetType ?? '',
      l.details    ?? '',
      DateFormat('yyyy-MM-dd HH:mm').format(l.timestamp.toDate()),
    ]).toList();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (pw.Context c) => [
        pw.Text('Audit Log Report',
            style: pw.TextStyle(
                fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Exported: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
        pw.SizedBox(height: 12),
        pw.Table.fromTextArray(
          headers: headers,
          data: data,
          headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.green800),
          cellStyle: const pw.TextStyle(fontSize: 9),
          rowDecoration: pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
        ),
      ],
    ));
    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final logs       = _filteredLogs;
    final start      = _page * _rowsPerPage;
    final end        = (start + _rowsPerPage).clamp(0, logs.length);
    final pageLogs   = logs.sublist(start, end);
    final totalPages = logs.isEmpty ? 1 : ((logs.length - 1) / _rowsPerPage).floor() + 1;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsHeader(
            icon: Icons.history,
            title: 'Audit Log',
            subtitle: 'All admin actions are recorded here.',
          ),
          const SizedBox(height: 12),
          // Filter bar
          Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by admin, details, or target…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
                onChanged: (v) => setState(() { _search = v; _page = 0; }),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButtonHideUnderline(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButton<String>(
                  value: _actionFilter,
                  isDense: true,
                  items: _actions.map((a) => DropdownMenuItem(
                    value: a, child: Text(a.capitalize()),
                  )).toList(),
                  onChanged: (v) =>
                      setState(() { _actionFilter = v ?? 'All'; _page = 0; }),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Export PDF'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white),
              onPressed: _exportPDF,
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              onPressed: _fetchLogs,
            ),
          ]),
          const SizedBox(height: 4),
          Text('${logs.length} records',
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Expanded(
            child: logs.isEmpty
                ? const Center(child: Text('No audit log entries found.'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 64),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppColors.primaryGreen.withOpacity(0.08)),
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(label: Text('Action',    style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Performed By', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Target',    style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Type',      style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Details',   style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Time',      style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: pageLogs.map((l) {
                          final actionColor =
                              _actionColors[l.action] ?? Colors.blueGrey;
                          return DataRow(cells: [
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: actionColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(l.action,
                                  style: TextStyle(
                                      color: actionColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12)),
                            )),
                            DataCell(Text(l.performedBy, style: const TextStyle(fontSize: 13))),
                            DataCell(Text(l.targetId   ?? '—', style: const TextStyle(fontSize: 13))),
                            DataCell(Text(l.targetType ?? '—', style: const TextStyle(fontSize: 13))),
                            DataCell(ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: Text(l.details ?? '—',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13)),
                            )),
                            DataCell(Text(
                              DateFormat('dd MMM yyyy HH:mm')
                                  .format(l.timestamp.toDate()),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            )),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
          ),
          // Pagination bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Showing ${logs.isEmpty ? 0 : start + 1}–$end of ${logs.length}',
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: _page > 0 ? () => setState(() => _page = 0) : null,
                    tooltip: 'First page',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  ),
                  Text('Page ${_page + 1} of $totalPages',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed:
                        end < logs.length ? () => setState(() => _page++) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    onPressed: end < logs.length
                        ? () => setState(() => _page = totalPages - 1)
                        : null,
                    tooltip: 'Last page',
                  ),
                ]),
                DropdownButtonHideUnderline(
                  child: Row(children: [
                    const Text('Rows:', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 6),
                    DropdownButton<int>(
                      value: _rowsPerPage,
                      isDense: true,
                      items: [10, 20, 50].map((n) => DropdownMenuItem(
                        value: n, child: Text('$n'),
                      )).toList(),
                      onChanged: (v) =>
                          setState(() { _rowsPerPage = v ?? 10; _page = 0; }),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// _NotificationList
// ===========================================================================

class _NotificationList extends StatelessWidget {
  const _NotificationList();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('No notifications sent yet.',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        final docs = snapshot.data!.docs;
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final data      = docs[i].data() as Map<String, dynamic>;
            final msg       = data['message']   as String? ?? '';
            final recipient = data['recipient'] as String? ?? 'all';
            final sentBy    = data['sentBy']    as String? ?? 'Unknown';
            final ts        = data['timestamp'] as Timestamp?;
            final time      = ts != null
                ? DateFormat('dd MMM yyyy HH:mm').format(ts.toDate())
                : '—';
            final chipColors = {
              'all':         Colors.blue,
              'admins':      Colors.red,
              'committee':   Colors.orange,
              'chairperson': Colors.purple,
            };
            return ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    (chipColors[recipient] ?? Colors.grey).withOpacity(0.15),
                child: Icon(Icons.notifications,
                    color: chipColors[recipient] ?? Colors.grey, size: 20),
              ),
              title: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: (chipColors[recipient] ?? Colors.grey).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(recipient,
                      style: TextStyle(
                          fontSize: 11,
                          color: chipColors[recipient] ?? Colors.grey,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Text('by $sentBy', style: const TextStyle(fontSize: 12)),
              ]),
              trailing: Text(time,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            );
          },
        );
      },
    );
  }
}

// ===========================================================================
// _AdminList
// ===========================================================================

class _AdminList extends StatefulWidget {
  final bool canManageUsers;
  final bool canSuspendUsers;
  final String adminEmail;
  const _AdminList({
    this.canManageUsers = false,
    this.canSuspendUsers = false,
    required this.adminEmail,
  });
  @override
  State<_AdminList> createState() => _AdminListState();
}

class _AdminListState extends State<_AdminList> {
  // Use a key to force rebuild after mutations
  Key _listKey = UniqueKey();

  void _refresh() => setState(() => _listKey = UniqueKey());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      key: _listKey,
      future: FirebaseFirestore.instance
          .collection('admins')
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No admins found.'));
        }
        final docs = [...snapshot.data!.docs]
          ..sort((a, b) {
            final da = a.data() as Map<String, dynamic>;
            final db = b.data() as Map<String, dynamic>;
            final aKey = ((da['email'] ?? da['fullName'] ?? a.id) as String)
                .toLowerCase();
            final bKey = ((db['email'] ?? db['fullName'] ?? b.id) as String)
                .toLowerCase();
            return aKey.compareTo(bKey);
          });
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final data        = docs[i].data() as Map<String, dynamic>;
            final id          = docs[i].id;
            final email       = data['email']            as String?  ?? id;
            final role        = data['role']             as String?  ?? 'committee';
            final isActive    =
              data['active'] != false && data['isActive'] != false;
            final hasConflict = data['conflictOfInterest'] == true;

            final roleColor = _roleColor(role);

            return ListTile(
              leading: Stack(
                children: [
                  CircleAvatar(
                    backgroundColor: roleColor.withOpacity(0.15),
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : '?',
                      style: TextStyle(
                          color: roleColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (hasConflict)
                    const Positioned(
                      right: 0, bottom: 0,
                      child: CircleAvatar(
                        radius: 7,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.flag, color: Colors.orange, size: 11),
                      ),
                    ),
                ],
              ),
              title: Text(email,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      decoration: isActive ? null : TextDecoration.lineThrough,
                      color: isActive ? null : Colors.grey)),
              subtitle: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                    child: Text(RoleAccess.displayName(role),
                      style: TextStyle(
                          fontSize: 11,
                          color: roleColor,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                Icon(isActive ? Icons.check_circle : Icons.cancel,
                    size: 13,
                    color: isActive ? Colors.green : Colors.red),
                const SizedBox(width: 3),
                Text(isActive ? 'Active' : 'Revoked',
                    style: TextStyle(
                        fontSize: 12,
                        color: isActive ? Colors.green : Colors.red)),
                if (hasConflict) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.flag, size: 13, color: Colors.orange),
                  const Text(' Conflict flagged',
                      style: TextStyle(fontSize: 12, color: Colors.orange)),
                ],
              ]),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.canManageUsers)
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: 'Change Role',
                      onPressed: () => _showChangeRoleDialog(context, id, role),
                    ),
                  IconButton(
                    icon: const Icon(Icons.flag_outlined, size: 20),
                    tooltip: 'Flag Conflict of Interest',
                    color: hasConflict ? Colors.orange : null,
                    onPressed: () =>
                        _showConflictOfInterestDialog(context, id, email),
                  ),
                  IconButton(
                    icon: Icon(
                        isActive ? Icons.block : Icons.check_circle,
                        size: 20,
                        color: isActive ? Colors.red : Colors.green),
                    tooltip: isActive ? 'Revoke Access' : 'Restore Access',
                    onPressed: widget.canSuspendUsers
                      ? () => _toggleAdminStatus(context, id, isActive)
                      : null,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _roleColor(String role) {
    switch (RoleAccess.normalizeRoleKey(role)) {
      case 'devTeam':     return Colors.deepPurple;
      case 'superAdmin':  return Colors.red;
      case 'chairperson': return Colors.purple;
      case 'committeeMember': return AppColors.primaryGreen;
      case 'adHocMember': return Colors.teal;
      case 'advisor': return Colors.amber.shade700;
      case 'studentRep': return Colors.indigo;
      case 'technicalOfficer': return Colors.blue;
      default:            return Colors.grey;
    }
  }

  void _showChangeRoleDialog(
      BuildContext context, String adminId, String currentRole) {
    String selectedRole = RoleAccess.normalizeRoleKey(currentRole);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Admin Role'),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            decoration: const InputDecoration(
                labelText: 'New Role', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'committeeMember', child: Text('Committee Member')),
              DropdownMenuItem(value: 'chairperson', child: Text('Chairperson')),
              DropdownMenuItem(value: 'adHocMember', child: Text('Ad Hoc Member')),
              DropdownMenuItem(value: 'advisor',     child: Text('Advisor')),
              DropdownMenuItem(value: 'studentRep',  child: Text('Student Representative')),
              DropdownMenuItem(value: 'technicalOfficer', child: Text('Technical Officer')),
              DropdownMenuItem(value: 'superAdmin',  child: Text('Super Admin')),
            ],
            onChanged: (v) =>
                setDialogState(() => selectedRole = v ?? currentRole),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('admins')
                    .doc(adminId)
                    .update({
                  'role': selectedRole,
                  'shcRole': selectedRole,
                });
                await FirebaseFirestore.instance.collection('audit_logs').add({
                  'action':      'role_change',
                  'performedBy': widget.adminEmail,
                  'targetType':  'admin',
                  'targetId':    adminId,
                  'details':     'Changed role to $selectedRole',
                  'timestamp':   Timestamp.now(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Row(children: [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Role updated.'),
                      ]),
                      backgroundColor: Colors.green[700],
                    ),
                  );
                }
                _refresh();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showConflictOfInterestDialog(
      BuildContext context, String adminId, String email) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          const Icon(Icons.flag, color: Colors.orange),
          const SizedBox(width: 8),
          Expanded(
              child:
                  Text('Flag Conflict of Interest', overflow: TextOverflow.ellipsis)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Admin: $email',
                style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            const Text(
                'This will prevent this admin from being assigned to related cases.',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Reason (required)',
                  border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason.')),
                );
                return;
              }
              await FirebaseFirestore.instance
                  .collection('admins')
                  .doc(adminId)
                  .update({
                'conflictOfInterest': true,
                'conflictReason':     reason,
              });
              await FirebaseFirestore.instance.collection('audit_logs').add({
                'action':      'conflict_flag',
                'performedBy': widget.adminEmail,
                'targetType':  'admin',
                'targetId':    adminId,
                'details':     'Flagged conflict of interest: $reason',
                'timestamp':   Timestamp.now(),
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(children: [
                      Icon(Icons.flag, color: Colors.white),
                      SizedBox(width: 8),
                      Text('Conflict of interest flagged.'),
                    ]),
                    backgroundColor: Colors.orange[700],
                  ),
                );
              }
              _refresh();
            },
            child: const Text('Flag', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAdminStatus(
      BuildContext context, String adminId, bool isActive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(isActive ? Icons.block : Icons.check_circle,
              color: isActive ? Colors.red : Colors.green),
          const SizedBox(width: 8),
          Text(isActive ? 'Revoke Access' : 'Restore Access'),
        ]),
        content: Text(isActive
            ? 'This admin will no longer be able to log in.'
            : 'This admin will regain access to the system.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.red : Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Revoke' : 'Restore',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(adminId)
          .update({
        'active': !isActive,
        'isActive': !isActive,
      });
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action':      isActive ? 'revoke' : 'restore',
        'performedBy': widget.adminEmail,
        'targetType':  'admin',
        'targetId':    adminId,
        'details':     isActive ? 'Revoked admin access' : 'Restored admin access',
        'timestamp':   Timestamp.now(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              Icon(isActive ? Icons.block : Icons.check_circle,
                  color: Colors.white),
              const SizedBox(width: 8),
              Text(isActive ? 'Access revoked.' : 'Access restored.'),
            ]),
            backgroundColor: isActive ? Colors.red[700] : Colors.green[700],
          ),
        );
      }
      _refresh();
    }
  }
}

// ===========================================================================
// _SlaSettingsPanel
// ===========================================================================

class _SlaSettingsPanel extends StatefulWidget {
  final AdminUser? admin;
  const _SlaSettingsPanel({this.admin});
  @override
  State<_SlaSettingsPanel> createState() => _SlaSettingsPanelState();
}

class _SlaSettingsPanelState extends State<_SlaSettingsPanel> {
  bool _loading  = true;
  bool _saving   = false;
  Map<String, dynamic> _sla = {};

  final _resolutionOptions = [7, 14, 21, 30, 45, 60, 90];
  final _escalationOptions = [3, 5, 7, 10, 14];
  final _reminderOptions   = [1, 2, 3, 5, 7];
  final _caseNumberFormats = [
    'SH-{YEAR}-{SEQ}',
    'CASE-{SEQ}',
    '{YEAR}/{SEQ}',
    'HR-{YEAR}-{SEQ}',
  ];

  static const Map<String, dynamic> _slaDefaults = {
    'resolution_days':       30,
    'escalation_after_days': 7,
    'reminder_every_days':   3,
    'auto_escalate':         true,
    'escalation_contact':    '',
    'case_number_format':    'SH-{YEAR}-{SEQ}',
    'next_case_seq':         1,
  };

  late TextEditingController _escalationEmailController;

  @override
  void initState() {
    super.initState();
    _escalationEmailController = TextEditingController();
    _fetchSla();
  }

  @override
  void dispose() {
    _escalationEmailController.dispose();
    super.dispose();
  }

  Future<void> _fetchSla() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance
        .collection('system').doc('sla').get();
    setState(() {
      _sla = doc.exists
          ? {..._slaDefaults, ...?(doc.data())}
          : Map<String, dynamic>.from(_slaDefaults);
      _escalationEmailController.text =
          (_sla['escalation_contact'] as String?) ?? '';
      _loading = false;
    });
  }

  Future<void> _updateSla(String key, dynamic value) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('system').doc('sla').set(
        {
          key:             value,
          'last_update':    Timestamp.now(),
          'last_update_by': widget.admin?.email ?? 'Unknown',
        },
        SetOptions(merge: true),
      );
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action':      'sla_update',
        'performedBy': widget.admin?.email ?? 'Unknown',
        'targetType':  'sla',
        'details':     'Updated $key to $value',
        'timestamp':   Timestamp.now(),
      });
      await _fetchSla();
      if (mounted) _showSuccess('SLA setting saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Text(message),
      ]),
      backgroundColor: Colors.green[700],
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final autoEscalate = _sla['auto_escalate'] as bool? ?? true;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsHeader(
                  icon: Icons.timer,
                  title: 'SLA & Auto-Escalation',
                  subtitle:
                      'Configure case deadlines, escalation rules, and numbering.',
                ),
                const SizedBox(height: 24),

                // ── Resolution deadline ──
                _SectionCard(
                  title: 'Case Resolution Deadline',
                  child: Row(children: [
                    const Text('Cases must be resolved within:'),
                    const SizedBox(width: 12),
                    _StyledDropdown<int>(
                      value: (_sla['resolution_days'] as int?) ?? 30,
                      items: _resolutionOptions
                          .map((d) => DropdownMenuItem(
                              value: d, child: Text('$d days')))
                          .toList(),
                      onChanged: (v) => _updateSla('resolution_days', v ?? 30),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // ── Auto-escalation ──
                _SectionCard(
                  title: 'Auto-Escalation',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingRow(
                        label: 'Escalate when a case is unactioned:',
                        trailing: Switch(
                          value: autoEscalate,
                          activeColor: AppColors.primaryGreen,
                          onChanged: (v) => _updateSla('auto_escalate', v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 24, runSpacing: 12, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Escalate after:'),
                          const SizedBox(width: 8),
                          _StyledDropdown<int>(
                            value: (_sla['escalation_after_days'] as int?) ?? 7,
                            items: _escalationOptions
                                .map((d) => DropdownMenuItem(
                                    value: d, child: Text('$d days')))
                                .toList(),
                            onChanged: autoEscalate
                                ? (v) => _updateSla(
                                    'escalation_after_days', v ?? 7)
                                : null,
                          ),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Remind every:'),
                          const SizedBox(width: 8),
                          _StyledDropdown<int>(
                            value:
                                (_sla['reminder_every_days'] as int?) ?? 3,
                            items: _reminderOptions
                                .map((d) => DropdownMenuItem(
                                    value: d, child: Text('$d days')))
                                .toList(),
                            onChanged: autoEscalate
                                ? (v) => _updateSla(
                                    'reminder_every_days', v ?? 3)
                                : null,
                          ),
                        ]),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Text('Escalation contact email:'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _escalationEmailController,
                            enabled: autoEscalate,
                            decoration: InputDecoration(
                              hintText: 'e.g. chairperson@institution.edu',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white),
                          onPressed: autoEscalate
                              ? () => _updateSla(
                                  'escalation_contact',
                                  _escalationEmailController.text.trim())
                              : null,
                          child: const Text('Save'),
                        ),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Case numbering ──
                _SectionCard(
                  title: 'Case Numbering Format',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Text('Format template:'),
                        const SizedBox(width: 12),
                        _StyledDropdown<String>(
                          value: (_sla['case_number_format'] as String?) ??
                              'SH-{YEAR}-{SEQ}',
                          items: _caseNumberFormats
                              .map((f) => DropdownMenuItem(
                                  value: f, child: Text(f)))
                              .toList(),
                          onChanged: (v) => _updateSla(
                              'case_number_format', v ?? 'SH-{YEAR}-{SEQ}'),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: Row(children: [
                          const Icon(Icons.preview,
                              size: 16, color: Colors.blueGrey),
                          const SizedBox(width: 8),
                          const Text('Preview: ',
                              style: TextStyle(color: Colors.blueGrey)),
                          Text(
                            ((_sla['case_number_format'] as String?) ??
                                    'SH-{YEAR}-{SEQ}')
                                .replaceAll(
                                    '{YEAR}', DateTime.now().year.toString())
                                .replaceAll(
                                    '{SEQ}',
                                    ((_sla['next_case_seq'] as int?) ?? 1)
                                        .toString()
                                        .padLeft(4, '0')),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey,
                                fontFamily: 'monospace'),
                          ),
                        ]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Summary ──
                _SectionCard(
                  title: 'Current SLA Summary',
                  child: Column(children: [
                    _SummaryRow('Resolution deadline',
                        '${(_sla['resolution_days'] as int?) ?? 30} days'),
                    _SummaryRow('Auto-escalation',
                        autoEscalate ? 'Enabled' : 'Disabled',
                        valueColor:
                            autoEscalate ? Colors.green : Colors.red),
                    _SummaryRow('Escalate after',
                        '${(_sla['escalation_after_days'] as int?) ?? 7} days'),
                    _SummaryRow('Remind every',
                        '${(_sla['reminder_every_days'] as int?) ?? 3} days'),
                    _SummaryRow('Escalation contact',
                        ((_sla['escalation_contact'] as String?)
                                ?.isNotEmpty ==
                            true)
                            ? _sla['escalation_contact'] as String
                            : '—'),
                    _SummaryRow('Case number format',
                        (_sla['case_number_format'] as String?) ??
                            'SH-{YEAR}-{SEQ}'),
                  ]),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        if (_saving)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// _SecuritySettingsPanel
// ===========================================================================

class _SecuritySettingsPanel extends StatefulWidget {
  final AdminUser? admin;
  const _SecuritySettingsPanel({this.admin});
  @override
  State<_SecuritySettingsPanel> createState() => _SecuritySettingsPanelState();
}

class _SecuritySettingsPanelState extends State<_SecuritySettingsPanel> {
  bool _loading = true;
  bool _saving  = false;
  Map<String, dynamic> _sec = {};

  final _lockoutAttemptOptions  = [3, 5, 10];
  final _lockoutDurationOptions = [5, 15, 30, 60];

  static const Map<String, dynamic> _secDefaults = {
    'lockout_enabled':       true,
    'lockout_attempts':      5,
    'lockout_duration_mins': 15,
    'ip_allowlist_enabled':  false,
    'ip_allowlist':          '',
    'two_fa_superAdmin':     true,
    'two_fa_chairperson':    true,
    'two_fa_committee':      false,
    'two_fa_technical':      false,
  };

  late TextEditingController _ipController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _fetchSecurity();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _fetchSecurity() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance
        .collection('system').doc('security').get();
    setState(() {
      _sec = doc.exists
          ? {..._secDefaults, ...?(doc.data())}
          : Map<String, dynamic>.from(_secDefaults);
      _ipController.text = (_sec['ip_allowlist'] as String?) ?? '';
      _loading = false;
    });
  }

  Future<void> _updateSec(String key, dynamic value) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('system').doc('security').set(
        {
          key:             value,
          'last_update':    Timestamp.now(),
          'last_update_by': widget.admin?.email ?? 'Unknown',
        },
        SetOptions(merge: true),
      );
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action':      'security_update',
        'performedBy': widget.admin?.email ?? 'Unknown',
        'targetType':  'security',
        'details':     'Updated $key to $value',
        'timestamp':   Timestamp.now(),
      });
      await _fetchSecurity();
      if (mounted) _showSuccess('Security setting saved.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.check_circle, color: Colors.white),
        const SizedBox(width: 8),
        Text(message),
      ]),
      backgroundColor: Colors.green[700],
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final lockoutEnabled = _sec['lockout_enabled']      as bool? ?? true;
    final ipEnabled      = _sec['ip_allowlist_enabled'] as bool? ?? false;

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SettingsHeader(
                  icon: Icons.security,
                  title: 'Security Settings',
                  subtitle:
                      'Login lockout, IP restrictions, and per-role 2FA.',
                ),
                const SizedBox(height: 24),

                // ── Lockout ──
                _SectionCard(
                  title: 'Failed Login Lockout',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingRow(
                        label:
                            'Lock account after too many failed login attempts:',
                        trailing: Switch(
                          value: lockoutEnabled,
                          activeColor: AppColors.primaryGreen,
                          onChanged: (v) => _updateSec('lockout_enabled', v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(spacing: 24, runSpacing: 12, children: [
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Lock after:'),
                          const SizedBox(width: 8),
                          _StyledDropdown<int>(
                            value: (_sec['lockout_attempts'] as int?) ?? 5,
                            items: _lockoutAttemptOptions
                                .map((n) => DropdownMenuItem(
                                    value: n, child: Text('$n attempts')))
                                .toList(),
                            onChanged: lockoutEnabled
                                ? (v) =>
                                    _updateSec('lockout_attempts', v ?? 5)
                                : null,
                          ),
                        ]),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Text('Lock duration:'),
                          const SizedBox(width: 8),
                          _StyledDropdown<int>(
                            value:
                                (_sec['lockout_duration_mins'] as int?) ?? 15,
                            items: _lockoutDurationOptions
                                .map((m) => DropdownMenuItem(
                                    value: m, child: Text('$m min')))
                                .toList(),
                            onChanged: lockoutEnabled
                                ? (v) => _updateSec(
                                    'lockout_duration_mins', v ?? 15)
                                : null,
                          ),
                        ]),
                      ]),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── IP allowlist ──
                _SectionCard(
                  title: 'IP Allowlist',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SettingRow(
                        label: 'Restrict admin logins to specific IP ranges:',
                        trailing: Switch(
                          value: ipEnabled,
                          activeColor: AppColors.primaryGreen,
                          onChanged: (v) =>
                              _updateSec('ip_allowlist_enabled', v),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(children: [
                        const Text('Allowed IPs:'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _ipController,
                            enabled: ipEnabled,
                            decoration: InputDecoration(
                              hintText:
                                  'e.g. 192.168.1.0/24, 10.0.0.1',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white),
                          onPressed: ipEnabled
                              ? () => _updateSec(
                                  'ip_allowlist',
                                  _ipController.text.trim())
                              : null,
                          child: const Text('Save'),
                        ),
                      ]),
                      if (ipEnabled)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(children: [
                            const Icon(Icons.info_outline,
                                size: 14, color: Colors.blue),
                            const SizedBox(width: 6),
                            Text(
                              'Separate multiple IPs or CIDR ranges with commas.',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue[700]),
                            ),
                          ]),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Per-role 2FA ──
                _SectionCard(
                  title: 'Two-Factor Authentication',
                  child: Column(
                    children: [
                      ...[
                        {'key': 'two_fa_superAdmin',  'label': 'Super Admin'},
                        {'key': 'two_fa_chairperson', 'label': 'Chairperson'},
                        {'key': 'two_fa_committee',   'label': 'Committee Member'},
                        {'key': 'two_fa_technical',   'label': 'Technical'},
                      ].map((r) {
                        final enabled =
                            _sec[r['key']] as bool? ?? false;
                        return _SettingRow(
                          label: 'Require 2FA for ${r['label']}:',
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: enabled
                                    ? Colors.green.withOpacity(0.12)
                                    : Colors.grey.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                enabled ? 'Required' : 'Off',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: enabled
                                        ? Colors.green[700]
                                        : Colors.grey),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: enabled,
                              activeColor: AppColors.primaryGreen,
                              onChanged: (v) => _updateSec(r['key']!, v),
                            ),
                          ]),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Summary ──
                _SectionCard(
                  title: 'Security Summary',
                  child: Column(children: [
                    _SummaryRow('Lockout',
                        lockoutEnabled ? 'Enabled' : 'Disabled',
                        valueColor: lockoutEnabled ? Colors.green : Colors.red),
                    _SummaryRow('Lockout threshold',
                        '${(_sec['lockout_attempts'] as int?) ?? 5} attempts'),
                    _SummaryRow('Lockout duration',
                        '${(_sec['lockout_duration_mins'] as int?) ?? 15} min'),
                    _SummaryRow('IP Allowlist',
                        ipEnabled ? 'Enabled' : 'Disabled',
                        valueColor: ipEnabled ? Colors.green : Colors.grey),
                    ...['superAdmin', 'chairperson', 'committee', 'technical']
                        .map((role) {
                      final required =
                          _sec['two_fa_$role'] as bool? ?? false;
                      return _SummaryRow('2FA – ${role.capitalize()}',
                          required ? 'Required' : 'Not required',
                          valueColor:
                              required ? Colors.green : Colors.grey);
                    }),
                  ]),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        if (_saving)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

// ===========================================================================
// _EmailTemplatesPanel
// ===========================================================================

class _EmailTemplatesPanel extends StatefulWidget {
  final AdminUser? admin;
  const _EmailTemplatesPanel({this.admin});
  @override
  State<_EmailTemplatesPanel> createState() => _EmailTemplatesPanelState();
}

class _EmailTemplatesPanelState extends State<_EmailTemplatesPanel> {
  bool _loading = true;
  bool _saving  = false;
  bool _isDirty = false;
  String _selectedKey = 'case_received';

  final List<Map<String, String>> _templateDefs = [
    {'key': 'case_received', 'label': 'Case Received Confirmation'},
    {'key': 'case_assigned', 'label': 'Case Assigned to Committee'},
    {'key': 'case_update',   'label': 'Case Status Update'},
    {'key': 'case_resolved', 'label': 'Case Resolved'},
    {'key': 'admin_invite',  'label': 'Admin Invitation'},
    {'key': 'escalation',    'label': 'Escalation Alert'},
    {'key': 'sla_reminder',  'label': 'SLA Reminder'},
  ];

  Map<String, Map<String, String>> _templates = {};
  late TextEditingController _subjectCtrl;
  late TextEditingController _bodyCtrl;

  @override
  void initState() {
    super.initState();
    _subjectCtrl = TextEditingController()
      ..addListener(() => setState(() => _isDirty = true));
    _bodyCtrl = TextEditingController()
      ..addListener(() => setState(() => _isDirty = true));
    _fetchTemplates();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  static const Map<String, String> _defaultSubjects = {
    'case_received': 'Your report has been received — {{caseNumber}}',
    'case_assigned': 'Case {{caseNumber}} has been assigned',
    'case_update':   'Update on case {{caseNumber}}',
    'case_resolved': 'Case {{caseNumber}} has been resolved',
    'admin_invite':  'You have been invited to join the admin panel',
    'escalation':    'ESCALATION: Case {{caseNumber}} requires immediate attention',
    'sla_reminder':  'Reminder: Case {{caseNumber}} SLA deadline approaching',
  };

  static const Map<String, String> _defaultBodies = {
    'case_received':
        'Dear {{recipientName}},\n\n'
        'We have received your report ({{caseNumber}}) and it is currently under review. '
        'We will keep you informed of any developments.\n\n'
        'Regards,\n{{institutionName}}',
    'case_assigned':
        'Dear Committee Member,\n\n'
        'Case {{caseNumber}} has been assigned to you. '
        'Please review it within the SLA period.\n\n'
        'Regards,\n{{institutionName}}',
    'case_update':
        'Dear {{recipientName}},\n\n'
        'There is an update on case {{caseNumber}}:\n\n'
        '{{updateDetails}}\n\n'
        'Regards,\n{{institutionName}}',
    'case_resolved':
        'Dear {{recipientName}},\n\n'
        'Case {{caseNumber}} has been resolved.\n\n'
        '{{resolutionSummary}}\n\n'
        'Regards,\n{{institutionName}}',
    'admin_invite':
        'Dear {{recipientName}},\n\n'
        'You have been invited as {{role}}. '
        'Use the link below to set up your account:\n\n'
        '{{inviteLink}}\n\n'
        'Regards,\n{{institutionName}}',
    'escalation':
        'Dear {{escalationContact}},\n\n'
        'Case {{caseNumber}} has been unactioned for {{days}} days and requires your immediate attention.\n\n'
        'Regards,\nSystem',
    'sla_reminder':
        'Dear {{assigneeName}},\n\n'
        'This is a reminder that case {{caseNumber}} is due in {{daysRemaining}} days.\n\n'
        'Regards,\nSystem',
  };

  Future<void> _fetchTemplates() async {
    setState(() => _loading = true);
    final doc  = await FirebaseFirestore.instance
        .collection('system').doc('email_templates').get();
    final data = (doc.exists ? doc.data() : null) ?? {};
    final Map<String, Map<String, String>> fetched = {};
    for (final t in _templateDefs) {
      final key = t['key']!;
      if (data.containsKey(key) && data[key] is Map) {
        fetched[key] = Map<String, String>.from(data[key] as Map);
      } else {
        fetched[key] = {
          'subject': _defaultSubjects[key] ?? '',
          'body':    _defaultBodies[key]    ?? '',
        };
      }
    }
    setState(() {
      _templates = fetched;
      _loading   = false;
      _isDirty   = false;
      _loadTemplate(_selectedKey);
    });
  }

  void _loadTemplate(String key) {
    _subjectCtrl.removeListener(() {});
    _bodyCtrl.removeListener(() {});
    _subjectCtrl.text = _templates[key]?['subject'] ?? '';
    _bodyCtrl.text    = _templates[key]?['body']    ?? '';
    _isDirty = false;
    // Re-attach listeners after setting values
    _subjectCtrl.addListener(() => setState(() => _isDirty = true));
    _bodyCtrl.addListener(() => setState(() => _isDirty = true));
  }

  Future<void> _saveTemplate() async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('system')
          .doc('email_templates')
          .set(
        {
          _selectedKey: {
            'subject': _subjectCtrl.text.trim(),
            'body':    _bodyCtrl.text.trim(),
          },
          'last_update':    Timestamp.now(),
          'last_update_by': widget.admin?.email ?? 'Unknown',
        },
        SetOptions(merge: true),
      );
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action':      'template_update',
        'performedBy': widget.admin?.email ?? 'Unknown',
        'targetType':  'email_template',
        'targetId':    _selectedKey,
        'details':     'Updated email template: $_selectedKey',
        'timestamp':   Timestamp.now(),
      });
      await _fetchTemplates();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('Template saved.'),
          ]),
          backgroundColor: Colors.green[700],
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsHeader(
            icon: Icons.email,
            title: 'Email Templates',
            subtitle:
                'Customize system emails. Use {{placeholders}} for dynamic content.',
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Template selector
                  Row(children: [
                    const Text('Template:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                    _StyledDropdown<String>(
                      value: _selectedKey,
                      items: _templateDefs
                          .map((t) => DropdownMenuItem(
                              value: t['key'], child: Text(t['label']!)))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        if (_isDirty) {
                          showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Unsaved Changes'),
                              content: const Text(
                                  'You have unsaved changes. Discard them?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Discard')),
                              ],
                            ),
                          ).then((confirmed) {
                            if (confirmed == true) {
                              setState(() => _selectedKey = v);
                              _loadTemplate(v);
                            }
                          });
                        } else {
                          setState(() => _selectedKey = v);
                          _loadTemplate(v);
                        }
                      },
                    ),
                    if (_isDirty) ...[
                      const SizedBox(width: 12),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.edit, size: 12, color: Colors.orange),
                          SizedBox(width: 4),
                          Text('Unsaved',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ],
                  ]),
                  const SizedBox(height: 16),

                  // Subject field
                  TextField(
                    controller: _subjectCtrl,
                    decoration: InputDecoration(
                      labelText: 'Subject',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Body field
                  Container(
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      controller: _bodyCtrl,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        labelText: 'Body',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.all(12),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Actions
                  Row(children: [
                    ElevatedButton.icon(
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: const Text('Save Template'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white),
                      onPressed: (_saving || !_isDirty) ? null : _saveTemplate,
                    ),
                    const SizedBox(width: 12),
                    TextButton.icon(
                      icon: const Icon(Icons.restore),
                      label: const Text('Reset to Default'),
                      onPressed: () => setState(() {
                        _subjectCtrl.text = _defaultSubjects[_selectedKey] ?? '';
                        _bodyCtrl.text    = _defaultBodies[_selectedKey]    ?? '';
                        _isDirty = true;
                      }),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Placeholders
                  const Text('Available placeholders:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 4,
                    children: [
                      '{{caseNumber}}', '{{recipientName}}', '{{institutionName}}',
                      '{{role}}', '{{inviteLink}}', '{{days}}', '{{daysRemaining}}',
                      '{{updateDetails}}', '{{resolutionSummary}}',
                      '{{assigneeName}}', '{{escalationContact}}',
                    ].map((p) => ActionChip(
                      label: Text(p,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                      backgroundColor: Colors.blue.withOpacity(0.08),
                      onPressed: () {
                        final ctrl = _bodyCtrl;
                        final text    = ctrl.text;
                        final sel     = ctrl.selection;
                        final newText = sel.isValid
                            ? text.replaceRange(sel.start, sel.end, p)
                            : text + p;
                        ctrl.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                              offset: sel.isValid ? sel.start + p.length : newText.length),
                        );
                      },
                    )).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// _LoginHistoryPanel
// ===========================================================================

class _LoginHistoryPanel extends StatefulWidget {
  const _LoginHistoryPanel();
  @override
  State<_LoginHistoryPanel> createState() => _LoginHistoryPanelState();
}

class _LoginHistoryPanelState extends State<_LoginHistoryPanel> {
  bool _loading = true;
  List<Map<String, dynamic>> _entries = [];
  String _search    = '';
  String _statusFilter = 'All';
  int _page         = 0;
  static const int _perPage = 15;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _loading = true);
    final snap = await FirebaseFirestore.instance
        .collection('admin_login_history')
        .orderBy('timestamp', descending: true)
        .limit(300)
        .get();
    setState(() {
      _entries = snap.docs.map((d) => d.data()).toList();
      _loading = false;
    });
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _entries;
    if (_statusFilter != 'All') {
      list = list
          .where((e) =>
              (e['status'] as String? ?? '').toLowerCase() ==
              _statusFilter.toLowerCase())
          .toList();
    }
    if (_search.isEmpty) return list;
    final q = _search.toLowerCase();
    return list.where((e) =>
        (e['email']  ?? '').toString().toLowerCase().contains(q) ||
        (e['ip']     ?? '').toString().toLowerCase().contains(q) ||
        (e['device'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final entries    = _filtered;
    final start      = _page * _perPage;
    final end        = (start + _perPage).clamp(0, entries.length);
    final pageData   = entries.sublist(start, end);
    final totalPages =
        entries.isEmpty ? 1 : ((entries.length - 1) / _perPage).floor() + 1;

    // Stats
    final total    = _entries.length;
    final success  = _entries.where((e) => e['status'] == 'success').length;
    final failed   = _entries.where((e) => e['status'] != 'success').length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsHeader(
            icon: Icons.manage_search,
            title: 'Admin Login History',
            subtitle:
                'Every sign-in attempt with IP address, device, and outcome.',
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(children: [
            _StatBadge(label: 'Total',    value: total,   color: Colors.blueGrey),
            const SizedBox(width: 12),
            _StatBadge(label: 'Success',  value: success, color: Colors.green),
            const SizedBox(width: 12),
            _StatBadge(label: 'Failed',   value: failed,  color: Colors.red),
            const Spacer(),
            OutlinedButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
              onPressed: _fetch,
            ),
          ]),
          const SizedBox(height: 12),

          // Filter row
          Row(children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by email, IP, or device…',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  isDense: true,
                ),
                onChanged: (v) => setState(() { _search = v; _page = 0; }),
              ),
            ),
            const SizedBox(width: 12),
            _StyledDropdown<String>(
              value: _statusFilter,
              items: ['All', 'success', 'failed', 'locked']
                  .map((s) => DropdownMenuItem(
                      value: s, child: Text(s.capitalize())))
                  .toList(),
              onChanged: (v) =>
                  setState(() { _statusFilter = v ?? 'All'; _page = 0; }),
            ),
          ]),
          const SizedBox(height: 8),

          entries.isEmpty
              ? const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.history_toggle_off,
                            size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text(
                          'No login history found.\n\n'
                          'Login events are written to admin_login_history when admins sign in.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minWidth: MediaQuery.of(context).size.width - 64),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                            AppColors.primaryGreen.withOpacity(0.08)),
                        columnSpacing: 16,
                        columns: const [
                          DataColumn(label: Text('Email',  style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('IP Address', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Device', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('Time',   style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: pageData.map((e) {
                          final ts     = e['timestamp'] as Timestamp?;
                          final time   = ts != null
                              ? DateFormat('dd MMM yyyy HH:mm').format(ts.toDate())
                              : '—';
                          final status = (e['status'] as String? ?? 'unknown');
                          final isOk   = status == 'success';
                          return DataRow(cells: [
                            DataCell(Text(e['email'] as String? ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500))),
                            DataCell(Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isOk
                                    ? Colors.green.withOpacity(0.12)
                                    : Colors.red.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(
                                  isOk ? Icons.check_circle : Icons.cancel,
                                  color: isOk ? Colors.green : Colors.red,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(status.capitalize(),
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isOk ? Colors.green[700] : Colors.red[700])),
                              ]),
                            )),
                            DataCell(Text(e['ip'] as String? ?? '—',
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 12))),
                            DataCell(Text(e['device'] as String? ?? '—',
                                style: const TextStyle(fontSize: 12))),
                            DataCell(Text(time,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey))),
                          ]);
                        }).toList(),
                      ),
                    ),
                  ),
                ),

          // Pagination
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Showing ${entries.isEmpty ? 0 : start + 1}–$end of ${entries.length}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed:
                        _page > 0 ? () => setState(() => _page--) : null,
                  ),
                  Text('Page ${_page + 1} of $totalPages',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: end < entries.length
                        ? () => setState(() => _page++)
                        : null,
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// _SystemSettingsPanel
// ===========================================================================

class _SystemSettingsPanel extends StatefulWidget {
  final AdminUser? admin;
  const _SystemSettingsPanel({this.admin});
  @override
  State<_SystemSettingsPanel> createState() => _SystemSettingsPanelState();
}

class _SystemSettingsPanelState extends State<_SystemSettingsPanel> {
  bool _loading = true;
  bool _saving  = false;
  Map<String, dynamic> _settings = {};

  final _features = [
    {'key': 'notifications',     'label': 'Notifications',     'icon': Icons.notifications},
    {'key': 'report_editing',    'label': 'Report Editing',     'icon': Icons.edit},
    {'key': 'maintenance_mode',  'label': 'Maintenance Mode',   'icon': Icons.construction},
    {'key': 'user_registration', 'label': 'User Registration',  'icon': Icons.person_add},
    {'key': 'admin_2fa',         'label': 'Admin 2FA (Global)', 'icon': Icons.security},
  ];

  final _retentionOptions = [30, 90, 180, 365];
  final _fontOptions      = ['Roboto', 'Open Sans', 'Lato', 'Montserrat', 'Nunito'];
  final _colorOptions     = [
    {'label': 'Green',  'value': 0xFF388E3C, 'color': Colors.green},
    {'label': 'Blue',   'value': 0xFF1976D2, 'color': Colors.blue},
    {'label': 'Purple', 'value': 0xFF7B1FA2, 'color': Colors.purple},
    {'label': 'Red',    'value': 0xFFD32F2F, 'color': Colors.red},
    {'label': 'Orange', 'value': 0xFFF57C00, 'color': Colors.orange},
  ];
  final _timeoutOptions = [5, 10, 15, 30, 60];

  late TextEditingController _maintenanceReasonCtrl;
  late TextEditingController _fileTypesCtrl;
  late TextEditingController _minPasswordLengthCtrl;

  static const Map<String, dynamic> _defaults = {
    'notifications':            true,
    'report_editing':           true,
    'maintenance_mode':         false,
    'maintenance_reason':       '',
    'audit_log_retention_days': 90,
    'allowed_file_types':       'pdf,jpg,png',
    'user_registration':        true,
    'admin_2fa':                false,
    'font_family':              'Roboto',
    'primary_color':            0xFF388E3C,
    'session_timeout':          15,
    'min_password_length':      8,
    'require_special_char':     true,
  };

  @override
  void initState() {
    super.initState();
    _maintenanceReasonCtrl = TextEditingController();
    _fileTypesCtrl         = TextEditingController();
    _minPasswordLengthCtrl = TextEditingController();
    _fetchSettings();
  }

  @override
  void dispose() {
    _maintenanceReasonCtrl.dispose();
    _fileTypesCtrl.dispose();
    _minPasswordLengthCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance
        .collection('system').doc('settings').get();
    setState(() {
      _settings = doc.exists
          ? {..._defaults, ...?(doc.data())}
          : Map<String, dynamic>.from(_defaults);
      _loading = false;
      _maintenanceReasonCtrl.text =
          (_settings['maintenance_reason'] as String?) ?? '';
      _fileTypesCtrl.text =
          (_settings['allowed_file_types'] as String?) ?? '';
      _minPasswordLengthCtrl.text =
          ((_settings['min_password_length'] as int?) ?? 8).toString();
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('system').doc('settings').set(
        {
          key:             value,
          'last_update':    Timestamp.now(),
          'last_update_by': widget.admin?.email ?? 'Unknown',
        },
        SetOptions(merge: true),
      );
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action':      'system_update',
        'performedBy': widget.admin?.email ?? 'Unknown',
        'targetType':  'system',
        'details':     'Updated $key to $value',
        'timestamp':   Timestamp.now(),
      });
      // Optimistic local update
      setState(() {
        _settings[key] = value;
        _saving = false;
      });
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      rethrow;
    }
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning, color: Colors.orange),
          SizedBox(width: 8),
          Text('Reset All Settings'),
        ]),
        content: const Text(
            'This will reset all system settings to their defaults. '
            'This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _loading = true);
      await FirebaseFirestore.instance.collection('system').doc('settings').set({
        ..._defaults,
        'last_update':    Timestamp.now(),
        'last_update_by': widget.admin?.email ?? 'Unknown',
      });
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action':      'system_update',
        'performedBy': widget.admin?.email ?? 'Unknown',
        'targetType':  'system',
        'details':     'Reset all settings to default',
        'timestamp':   Timestamp.now(),
      });
      await _fetchSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.restore, color: Colors.white),
            SizedBox(width: 8),
            Text('Settings reset to defaults.'),
          ]),
          backgroundColor: Colors.orange[700],
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    final maintenanceOn =
        (_settings['maintenance_mode'] as bool?) ?? false;
    final lastUpdate     = _settings['last_update'] as Timestamp?;
    final lastUpdatedBy  = _settings['last_update_by'] as String?;

    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SettingsHeader(
                icon: Icons.settings,
                title: 'System Settings',
                subtitle: 'Application-wide toggles, appearance, and policies.',
              ),
              const SizedBox(height: 20),

              // ── Feature toggles ──
              _SectionCard(
                title: 'Feature Toggles',
                child: Column(
                  children: _features.map((f) {
                    final key   = f['key'] as String;
                    final label = f['label'] as String;
                    final icon  = f['icon'] as IconData;
                    final val   = (_settings[key] as bool?) ?? true;

                    if (key == 'maintenance_mode') {
                      return _FeatureToggleRow(
                        icon:    icon,
                        label:   label,
                        value:   val,
                        onChanged: (newVal) async {
                          if (newVal) {
                            final reason = await _askMaintenanceReason();
                            if (reason == null) return;
                            await _updateSetting('maintenance_mode', true);
                            await _updateSetting('maintenance_reason', reason);
                            _maintenanceReasonCtrl.text = reason;
                          } else {
                            await _updateSetting('maintenance_mode', false);
                            await _updateSetting('maintenance_reason', '');
                            _maintenanceReasonCtrl.text = '';
                          }
                        },
                        warningColor: maintenanceOn ? Colors.orange : null,
                      );
                    }
                    return _FeatureToggleRow(
                      icon:      icon,
                      label:     label,
                      value:     val,
                      onChanged: (v) => _updateSetting(key, v),
                    );
                  }).toList(),
                ),
              ),
              if (maintenanceOn)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    border: Border.all(color: Colors.orange.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.warning_amber, color: Colors.orange),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Maintenance Mode active: '
                        '${(_settings['maintenance_reason'] as String?)?.isNotEmpty == true ? _settings['maintenance_reason'] : 'No reason provided'}',
                        style: const TextStyle(
                            color: Colors.deepOrange,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),

              // ── Appearance ──
              _SectionCard(
                title: 'Appearance',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const SizedBox(width: 120, child: Text('App Font:')),
                      _StyledDropdown<String>(
                        value: (_settings['font_family'] as String?) ?? 'Roboto',
                        items: _fontOptions
                            .map((f) => DropdownMenuItem(
                                value: f,
                                child: Text(f,
                                    style: TextStyle(fontFamily: f))))
                            .toList(),
                        onChanged: (v) =>
                            _updateSetting('font_family', v ?? 'Roboto'),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const SizedBox(
                          width: 120, child: Text('Primary Color:')),
                      _StyledDropdown<int>(
                        value: (_settings['primary_color'] as int?) ??
                            0xFF388E3C,
                        items: _colorOptions
                            .map((c) => DropdownMenuItem(
                                  value: c['value'] as int,
                                  child: Row(children: [
                                    Container(
                                      width:  18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: c['color'] as Color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(c['label'] as String),
                                  ]),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            _updateSetting('primary_color', v ?? 0xFF388E3C),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Session & password ──
              _SectionCard(
                title: 'Session & Password Policy',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const SizedBox(width: 180, child: Text('Session timeout:')),
                      _StyledDropdown<int>(
                        value: (_settings['session_timeout'] as int?) ?? 15,
                        items: _timeoutOptions
                            .map((t) => DropdownMenuItem(
                                value: t, child: Text('$t minutes')))
                            .toList(),
                        onChanged: (v) =>
                            _updateSetting('session_timeout', v ?? 15),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const SizedBox(
                          width: 180, child: Text('Min password length:')),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _minPasswordLengthCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(2),
                          ],
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                          onFieldSubmitted: (v) => _updateSetting(
                              'min_password_length', int.tryParse(v) ?? 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        onPressed: () => _updateSetting(
                            'min_password_length',
                            int.tryParse(_minPasswordLengthCtrl.text) ?? 8),
                        child: const Text('Save', style: TextStyle(fontSize: 13)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _SettingRow(
                      label: 'Require special character in password:',
                      trailing: Switch(
                        value: (_settings['require_special_char'] as bool?) ??
                            true,
                        activeColor: AppColors.primaryGreen,
                        onChanged: (v) =>
                            _updateSetting('require_special_char', v),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Data & files ──
              _SectionCard(
                title: 'Data & File Handling',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const SizedBox(
                          width: 180,
                          child: Text('Audit log retention:')),
                      _StyledDropdown<int>(
                        value: (_settings['audit_log_retention_days'] as int?) ??
                            90,
                        items: _retentionOptions
                            .map((d) => DropdownMenuItem(
                                value: d, child: Text('$d days')))
                            .toList(),
                        onChanged: (v) => _updateSetting(
                            'audit_log_retention_days', v ?? 90),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      const SizedBox(
                          width: 180,
                          child: Text('Allowed file types:')),
                      Expanded(
                        child: TextFormField(
                          controller: _fileTypesCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. pdf,jpg,png',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            isDense: true,
                          ),
                          onFieldSubmitted: (v) =>
                              _updateSetting('allowed_file_types', v.trim()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8)),
                        onPressed: () => _updateSetting(
                            'allowed_file_types',
                            _fileTypesCtrl.text.trim()),
                        child: const Text('Save', style: TextStyle(fontSize: 13)),
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Status summary ──
              _SectionCard(
                title: 'Current System Status',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._features.map((f) {
                      final val = (_settings[f['key'] as String] as bool?) ?? true;
                      return _SummaryRow(
                        f['label'] as String, val ? 'Enabled' : 'Disabled',
                        valueColor: val ? Colors.green : Colors.red,
                      );
                    }),
                    _SummaryRow('Font', (_settings['font_family'] as String?) ?? 'Roboto'),
                    _SummaryRow('Session Timeout',
                        '${(_settings['session_timeout'] as int?) ?? 15} min'),
                    _SummaryRow('Password Policy',
                        'Min ${(_settings['min_password_length'] as int?) ?? 8} chars'
                        '${((_settings['require_special_char'] as bool?) ?? true) ? ', special char required' : ''}'),
                    _SummaryRow('Audit Log Retention',
                        '${(_settings['audit_log_retention_days'] as int?) ?? 90} days'),
                    _SummaryRow('Allowed File Types',
                        (_settings['allowed_file_types'] as String?) ?? '—'),
                    if (lastUpdate != null && lastUpdatedBy != null)
                      _SummaryRow(
                        'Last Updated',
                        '${DateFormat('dd MMM yyyy HH:mm').format(lastUpdate.toDate())} by $lastUpdatedBy',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Danger zone ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Danger Zone',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red)),
                        Text('Reset all settings to their factory defaults.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.restore),
                    label: const Text('Reset to Defaults'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white),
                    onPressed: _resetToDefaults,
                  ),
                ]),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
        if (_saving)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black12,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Future<String?> _askMaintenanceReason() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.construction, color: Colors.orange),
          SizedBox(width: 8),
          Text('Enable Maintenance Mode'),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Reason (shown to users)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white),
            onPressed: () {
              final reason = ctrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx, reason);
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared helper widgets
// ===========================================================================

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    letterSpacing: 0.3)),
            const Divider(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  const _SettingRow({required this.label, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: Text(label)),
      trailing,
    ]);
  }
}

class _FeatureToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? warningColor;
  const _FeatureToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.warningColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: warningColor ?? Colors.grey),
        const SizedBox(width: 10),
        Expanded(child: Text(label)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: value
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            value ? 'ON' : 'OFF',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: value ? Colors.green[700] : Colors.red[700]),
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          activeColor: warningColor ?? AppColors.primaryGreen,
          onChanged: onChanged,
        ),
      ]),
    );
  }
}

class _StyledDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  const _StyledDropdown({
    required this.value,
    required this.items,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatBadge(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('$value',
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
      ]),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _SummaryRow(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(
          width: 200,
          child: Text('$label:',
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
                color: valueColor),
          ),
        ),
      ]),
    );
  }
}
extension StringCap on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
}