import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/admin_user.dart';
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

  @override
  void initState() {
    super.initState();
    final isChairperson = widget.admin?.role == AdminRole.superAdmin;

    _tabs = [
      _SettingsTab(
        icon: Icons.history,
        label: 'Logs',
        builder: _buildLogsTab,
      ),
      _SettingsTab(
        icon: Icons.notifications,
        label: 'Notifications',
        builder: _buildNotificationsTab,
      ),
      _SettingsTab(
        icon: Icons.admin_panel_settings,
        label: 'Admins',
        builder: _buildAdminsTab,
      ),
      if (!isChairperson)
        _SettingsTab(
          icon: Icons.settings,
          label: 'System',
          builder: _buildSystemTab,
        ),
      if (isChairperson)
        _SettingsTab(
          icon: Icons.assignment_ind,
          label: 'Assign Reports',
          builder: _buildChairpersonAssignTab,
        ),
    ];
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEmbedded = widget.embedded;
    return Scaffold(
      appBar: isEmbedded
          ? null
          : AppBar(
              title: const Text('Admin Settings'),
              backgroundColor: AppColors.primaryGreen,
              bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: _tabs
                    .map((t) => Tab(icon: Icon(t.icon), text: t.label))
                    .toList(),
              ),
            ),
      body: isEmbedded
          ? Column(
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: _tabs
                      .map((t) => Tab(icon: Icon(t.icon), text: t.label))
                      .toList(),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: _tabs.map((t) => t.builder()).toList(),
                  ),
                ),
              ],
            )
          : TabBarView(
              controller: _tabController,
              children: _tabs.map((t) => t.builder()).toList(),
            ),
    );
  }

  // -------------------------------------------------------------------------
  // Tab builders
  // -------------------------------------------------------------------------

  Widget _buildLogsTab() => const _AuditLogTable();

  Widget _buildChairpersonAssignTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Assign reports to committee members.'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.assignment_ind),
            label: const Text('Assign Report'),
            onPressed: () {
              // TODO: Implement assignment logic
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notifications Center',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Send Notification'),
                    onPressed: () => _showSendNotificationDialog(context),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: () => setState(() {}),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // FIX #3: Use SizedBox with fixed height instead of Expanded
              // inside an unbounded Column to avoid overflow errors.
              const SizedBox(height: 300, child: _NotificationList()),
              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'Notification Configuration',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                  'Notification channels, templates, and settings coming soon.'),
            ],
          ),
        ),
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
                decoration: const InputDecoration(labelText: 'Message'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: recipient,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Users')),
                  DropdownMenuItem(
                      value: 'admins', child: Text('Admins Only')),
                  DropdownMenuItem(
                      value: 'committee', child: Text('Committee')),
                  DropdownMenuItem(
                      value: 'chairperson', child: Text('Chairperson')),
                ],
                onChanged: (v) =>
                    setDialogState(() => recipient = v ?? 'all'),
                decoration:
                    const InputDecoration(labelText: 'Recipient Group'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final msg = messageController.text.trim();
                if (msg.isEmpty) return;
                await FirebaseFirestore.instance
                    .collection('notifications')
                    .add({
                  'message': msg,
                  'recipient': recipient,
                  'sentBy': widget.admin?.email ?? 'Unknown',
                  'timestamp': Timestamp.now(),
                });
                await FirebaseFirestore.instance
                    .collection('audit_logs')
                    .add({
                  'action': 'notify',
                  'performedBy': widget.admin?.email ?? 'Unknown',
                  'targetType': 'notification',
                  'details': 'Sent notification to $recipient',
                  'timestamp': Timestamp.now(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Notification sent.')),
                  );
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
    // FIX #2: Compare against AdminRole enum, not a raw string.
    final isSuperAdmin = widget.admin?.role == AdminRole.superAdmin;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin & Committee Management',
                  style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invite Admin'),
                    onPressed: isSuperAdmin
                        ? () => _showInviteAdminDialog(context)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: () => setState(() {}),
                  ),
                  const SizedBox(width: 16),
                  if (isSuperAdmin)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.group_add),
                      label: const Text('Create Ad Hoc Committee'),
                      onPressed: () =>
                          _showCreateAdHocCommitteeDialog(context),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(child: _AdminList(isSuperAdmin: isSuperAdmin)),
              const SizedBox(height: 24),
              const Text('Roles:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Super Admin')),
                  Chip(label: Text('Chairperson')),
                  Chip(label: Text('Advisor')),
                  Chip(label: Text('Committee Member')),
                  Chip(label: Text('Ad Hoc')),
                  Chip(label: Text('Student Rep')),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Ad Hoc Committee Rules:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  '• All members must have no previous allegations of sexual harassment.'),
              const Text('• No conflict of interest.'),
              const Text('• At least half of members are female.'),
              const Text('• Odd number of members.'),
              const Text(
                  '• Student reps only if students involved.'),
              const Text(
                  '• No junior staff to investigate senior staff unless victim is junior.'),
              const Text(
                  '• If perpetrator is Top Management, Council committee investigates.'),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateAdHocCommitteeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Ad Hoc Committee'),
        content: const Text(
            'Ad hoc committee creation UI coming soon. This will allow super admins to select members, enforce rules, and co-opt students as needed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
      ),
    );
  }

  // FIX #1: Moved _showInviteAdminDialog INSIDE the class.
  void _showInviteAdminDialog(BuildContext context) {
    final emailController = TextEditingController();
    String selectedRole = 'committee';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Invite New Admin'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(
                      value: 'committee',
                      child: Text('Committee Member')),
                  DropdownMenuItem(
                      value: 'chairperson',
                      child: Text('Chairperson')),
                  DropdownMenuItem(
                      value: 'technical', child: Text('Technical')),
                  DropdownMenuItem(
                      value: 'superAdmin',
                      child: Text('Super Admin')),
                ],
                onChanged: (v) =>
                    setDialogState(() => selectedRole = v ?? 'committee'),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;
                // FIX #4: Use UUID v4 for a proper cryptographically
                // random invite token instead of UniqueKey().toString().
                final token = const Uuid().v4();
                await FirebaseFirestore.instance
                    .collection('admin_invites')
                    .add({
                  'email': email,
                  'role': selectedRole,
                  'invitedBy': widget.admin?.email ?? 'Unknown',
                  'timestamp': Timestamp.now(),
                  'token': token,
                  'accepted': false,
                });
                await FirebaseFirestore.instance
                    .collection('audit_logs')
                    .add({
                  'action': 'invite',
                  'performedBy': widget.admin?.email ?? 'Unknown',
                  'targetType': 'admin_invite',
                  'targetId': email,
                  'details': 'Invited $email as $selectedRole',
                  'timestamp': Timestamp.now(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Invite sent to $email.')),
                  );
                }
              },
              child: const Text('Send Invite'),
            ),
          ],
        ),
      ),
    );
  }

  // FIX #1: Moved _buildSystemTab INSIDE the class.
  Widget _buildSystemTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _SystemSettingsPanel(admin: widget.admin),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SettingsTab
// ---------------------------------------------------------------------------

class _SettingsTab {
  final IconData icon;
  final String label;
  final Widget Function() builder;

  _SettingsTab({
    required this.icon,
    required this.label,
    required this.builder,
  });
}

// ---------------------------------------------------------------------------
// _AuditLogTable
// ---------------------------------------------------------------------------

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
    'All',
    'edit',
    'delete',
    'login',
    'assign',
    'invite',
    'revoke'
  ];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }

  Future<void> _fetchLogs() async {
    setState(() => _loading = true);
    final query = await FirebaseFirestore.instance
        .collection('audit_logs')
        .orderBy('timestamp', descending: true)
        .limit(200)
        .get();
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
      logs = logs
          .where((l) =>
              l.performedBy.toLowerCase().contains(q) ||
              (l.details ?? '').toLowerCase().contains(q) ||
              (l.targetId ?? '').toLowerCase().contains(q))
          .toList();
    }
    return logs;
  }

  Future<void> _exportPDF() async {
    final pdf = pw.Document();
    final headers = ['Action', 'By', 'Target', 'Type', 'Details', 'Time'];
    final data = _filteredLogs
        .map((l) => [
              l.action,
              l.performedBy,
              l.targetId ?? '',
              l.targetType ?? '',
              l.details ?? '',
              DateFormat('yyyy-MM-dd HH:mm').format(l.timestamp.toDate()),
            ])
        .toList();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Table.fromTextArray(
          headers: headers,
          data: data,
        ),
      ),
    );
    final bytes = await pdf.save();
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final logs = _filteredLogs;
    final start = _page * _rowsPerPage;
    final end = (start + _rowsPerPage).clamp(0, logs.length);
    final pageLogs = logs.sublist(start, end);
    final totalPages =
        logs.isEmpty ? 1 : ((logs.length - 1) / _rowsPerPage).floor() + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by admin, details, or target',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() {
                    _search = v;
                    _page = 0;
                  }),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _actionFilter,
                items: _actions
                    .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(a.capitalize()),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _actionFilter = v ?? 'All';
                  _page = 0;
                }),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
                onPressed: _exportPDF,
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Action')),
                DataColumn(label: Text('By')),
                DataColumn(label: Text('Target')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Details')),
                DataColumn(label: Text('Time')),
              ],
              rows: pageLogs
                  .map((l) => DataRow(cells: [
                        DataCell(Text(l.action)),
                        DataCell(Text(l.performedBy)),
                        DataCell(Text(l.targetId ?? '')),
                        DataCell(Text(l.targetType ?? '')),
                        DataCell(Text(l.details ?? '')),
                        DataCell(Text(DateFormat('yyyy-MM-dd HH:mm')
                            .format(l.timestamp.toDate()))),
                      ]))
                  .toList(),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: _page > 0 ? () => setState(() => _page--) : null,
            ),
            Text('Page ${_page + 1} of $totalPages'),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed:
                  end < logs.length ? () => setState(() => _page++) : null,
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _NotificationList
// ---------------------------------------------------------------------------

class _NotificationList extends StatefulWidget {
  const _NotificationList();

  @override
  State<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<_NotificationList> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('notifications')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No notifications found.'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final msg = data['message'] ?? '';
            final recipient = data['recipient'] ?? 'all';
            final sentBy = data['sentBy'] ?? 'Unknown';
            final ts = data['timestamp'] as Timestamp?;
            final time = ts != null
                ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
                : '';
            return ListTile(
              leading: const Icon(Icons.notifications),
              title: Text(msg),
              subtitle: Text('To: $recipient | By: $sentBy | $time'),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _AdminList
// ---------------------------------------------------------------------------

class _AdminList extends StatefulWidget {
  final bool isSuperAdmin;
  const _AdminList({this.isSuperAdmin = false});

  @override
  State<_AdminList> createState() => _AdminListState();
}

class _AdminListState extends State<_AdminList> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('admins').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(child: Text('No admins found.'));
        }
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final email = data['email'] ?? '';
            final role = data['role'] ?? 'committee';
            final status = data['active'] == false ? 'Revoked' : 'Active';
            return ListTile(
              leading: Icon(Icons.person,
                  color: role == 'superAdmin'
                      ? Colors.red
                      : AppColors.primaryGreen),
              title: Text(email),
              subtitle: Text('Role: $role | Status: $status'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isSuperAdmin)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Change Role',
                      onPressed: () =>
                          _showChangeRoleDialog(context, id, role),
                    ),
                  IconButton(
                    icon: Icon(status == 'Active'
                        ? Icons.block
                        : Icons.check_circle),
                    tooltip: status == 'Active'
                        ? 'Revoke Access'
                        : 'Restore Access',
                    onPressed: () =>
                        _toggleAdminStatus(context, id, status == 'Active'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showChangeRoleDialog(
      BuildContext context, String adminId, String currentRole) {
    String selectedRole = currentRole;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Admin Role'),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            items: const [
              DropdownMenuItem(
                  value: 'committee', child: Text('Committee Member')),
              DropdownMenuItem(
                  value: 'chairperson', child: Text('Chairperson')),
              DropdownMenuItem(
                  value: 'technical', child: Text('Technical')),
              DropdownMenuItem(
                  value: 'superAdmin', child: Text('Super Admin')),
            ],
            onChanged: (v) =>
                setDialogState(() => selectedRole = v ?? currentRole),
            decoration: const InputDecoration(labelText: 'Role'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                // FIX #5: Actually persist the role change to Firestore.
                await FirebaseFirestore.instance
                    .collection('admins')
                    .doc(adminId)
                    .update({'role': selectedRole});
                await FirebaseFirestore.instance
                    .collection('audit_logs')
                    .add({
                  'action': 'role_change',
                  'performedBy': 'superAdmin',
                  'targetType': 'admin',
                  'targetId': adminId,
                  'details': 'Changed role to $selectedRole',
                  'timestamp': Timestamp.now(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Role updated.')),
                  );
                }
                setState(() {});
              },
              child: const Text('Change Role'),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleAdminStatus(
      BuildContext context, String adminId, bool isActive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Revoke Access' : 'Restore Access'),
        content: Text(isActive
            ? 'Are you sure you want to revoke this admin?'
            : 'Restore this admin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Revoke' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      // FIX #5: Actually persist the status toggle to Firestore.
      await FirebaseFirestore.instance
          .collection('admins')
          .doc(adminId)
          .update({'active': !isActive});
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': isActive ? 'revoke' : 'restore',
        'performedBy': 'superAdmin',
        'targetType': 'admin',
        'targetId': adminId,
        'details':
            isActive ? 'Revoked admin access' : 'Restored admin access',
        'timestamp': Timestamp.now(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isActive
              ? 'Access revoked.'
              : 'Access restored.'),
        ));
      }
      setState(() {});
    }
  }
}

// ---------------------------------------------------------------------------
// _SystemSettingsPanel
// ---------------------------------------------------------------------------

class _SystemSettingsPanel extends StatefulWidget {
  final AdminUser? admin;
  const _SystemSettingsPanel({this.admin});

  @override
  State<_SystemSettingsPanel> createState() => _SystemSettingsPanelState();
}

class _SystemSettingsPanelState extends State<_SystemSettingsPanel> {
  bool _loading = true;
  Map<String, dynamic> _settings = {};

  final _features = [
    {'key': 'notifications', 'label': 'Notifications'},
    {'key': 'report_editing', 'label': 'Report Editing'},
    {'key': 'maintenance_mode', 'label': 'Maintenance Mode'},
    {'key': 'user_registration', 'label': 'User Registration'},
    {'key': 'admin_2fa', 'label': 'Admin 2FA'},
  ];
  final _retentionOptions = [30, 90, 180, 365];
  final _fontOptions = ['Roboto', 'Open Sans', 'Lato', 'Montserrat', 'Nunito'];
  final _colorOptions = [
    {'label': 'Green', 'value': 0xFF388E3C},
    {'label': 'Blue', 'value': 0xFF1976D2},
    {'label': 'Purple', 'value': 0xFF7B1FA2},
    {'label': 'Red', 'value': 0xFFD32F2F},
    {'label': 'Orange', 'value': 0xFFF57C00},
  ];
  final _timeoutOptions = [5, 10, 15, 30, 60];

  TextEditingController? _maintenanceReasonController;
  TextEditingController? _fileTypesController;
  TextEditingController? _minPasswordLengthController;
  bool _requireSpecialChar = false;

  static const Map<String, dynamic> _defaults = {
    'notifications': true,
    'report_editing': true,
    'maintenance_mode': false,
    'maintenance_reason': '',
    'audit_log_retention_days': 90,
    'allowed_file_types': 'pdf,jpg,png',
    'user_registration': true,
    'admin_2fa': false,
    'font_family': 'Roboto',
    'primary_color': 0xFF388E3C,
    'session_timeout': 15,
    'min_password_length': 8,
    'require_special_char': true,
    'app_version': '1.0.0',
    'last_update': null,
    'last_update_by': null,
  };

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  @override
  void dispose() {
    _maintenanceReasonController?.dispose();
    _fileTypesController?.dispose();
    _minPasswordLengthController?.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    setState(() => _loading = true);
    final doc = await FirebaseFirestore.instance
        .collection('system')
        .doc('settings')
        .get();
    setState(() {
      _settings = doc.exists
          ? (doc.data() ?? Map.from(_defaults))
          : Map.from(_defaults);
      _loading = false;
      _maintenanceReasonController =
          TextEditingController(text: _settings['maintenance_reason'] ?? '');
      _fileTypesController =
          TextEditingController(text: _settings['allowed_file_types'] ?? '');
      _minPasswordLengthController = TextEditingController(
          text: (_settings['min_password_length'] ?? 8).toString());
      _requireSpecialChar = _settings['require_special_char'] ?? true;
    });
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    await FirebaseFirestore.instance
        .collection('system')
        .doc('settings')
        .set({
      key: value,
      'last_update': Timestamp.now(),
      'last_update_by': widget.admin?.email ?? 'Unknown',
    }, SetOptions(merge: true));
    await FirebaseFirestore.instance.collection('audit_logs').add({
      'action': 'system_update',
      'performedBy': widget.admin?.email ?? 'Unknown',
      'targetType': 'system',
      'details': 'Updated $key to $value',
      'timestamp': Timestamp.now(),
    });
    await _fetchSettings();
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text(
            'Are you sure you want to reset all system settings to default values? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Reset')),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => _loading = true);
      await FirebaseFirestore.instance
          .collection('system')
          .doc('settings')
          .set({
        ..._defaults,
        'last_update': Timestamp.now(),
        'last_update_by': widget.admin?.email ?? 'Unknown',
      });
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'action': 'system_update',
        'performedBy': widget.admin?.email ?? 'Unknown',
        'targetType': 'system',
        'details': 'Reset all settings to default',
        'timestamp': Timestamp.now(),
      });
      await _fetchSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Settings',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          // Feature toggles
          ..._features.map((f) {
            if (f['key'] == 'maintenance_mode') {
              return Row(
                children: [
                  Expanded(child: Text(f['label']!)),
                  Switch(
                    value: _settings['maintenance_mode'] ?? false,
                    onChanged: (val) async {
                      if (val) {
                        final reason = await showDialog<String>(
                          context: context,
                          builder: (ctx) {
                            final ctrl = TextEditingController();
                            return AlertDialog(
                              title: const Text('Enable Maintenance Mode'),
                              content: TextField(
                                controller: ctrl,
                                decoration: const InputDecoration(
                                    labelText: 'Reason (visible to users)'),
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, ctrl.text.trim()),
                                  child: const Text('Enable'),
                                ),
                              ],
                            );
                          },
                        );
                        if (reason == null || reason.isEmpty) return;
                        await _updateSetting('maintenance_mode', true);
                        await _updateSetting('maintenance_reason', reason);
                      } else {
                        await _updateSetting('maintenance_mode', false);
                        await _updateSetting('maintenance_reason', '');
                      }
                    },
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: Text(f['label']!)),
                Switch(
                  value: _settings[f['key']] ?? true,
                  onChanged: (val) => _updateSetting(f['key']!, val),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),
          // Font
          Row(
            children: [
              const Text('App Font:'),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _settings['font_family'] ?? 'Roboto',
                items: _fontOptions
                    .map((f) => DropdownMenuItem(
                          value: f,
                          child:
                              Text(f, style: TextStyle(fontFamily: f)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    _updateSetting('font_family', v ?? 'Roboto'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Primary color
          Row(
            children: [
              const Text('Primary Color:'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _settings['primary_color'] ?? 0xFF388E3C,
                items: _colorOptions
                    .map((c) => DropdownMenuItem(
                          value: c['value'] as int,
                          child: Row(children: [
                            Container(
                                width: 20,
                                height: 20,
                                color: Color(c['value'] as int)),
                            const SizedBox(width: 8),
                            Text(c['label'] as String),
                          ]),
                        ))
                    .toList(),
                onChanged: (v) =>
                    _updateSetting('primary_color', v ?? 0xFF388E3C),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Session timeout
          Row(
            children: [
              const Text('Session Timeout:'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _settings['session_timeout'] ?? 15,
                items: _timeoutOptions
                    .map((t) =>
                        DropdownMenuItem(value: t, child: Text('$t min')))
                    .toList(),
                onChanged: (v) =>
                    _updateSetting('session_timeout', v ?? 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Password policy
          Row(
            children: [
              const Text('Password Policy:'),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: _minPasswordLengthController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Min Length', isDense: true),
                  onSubmitted: (v) => _updateSetting(
                      'min_password_length', int.tryParse(v) ?? 8),
                ),
              ),
              const SizedBox(width: 12),
              Row(
                children: [
                  Checkbox(
                    value: _requireSpecialChar,
                    onChanged: (v) {
                      setState(() => _requireSpecialChar = v ?? true);
                      _updateSetting('require_special_char', v ?? true);
                    },
                  ),
                  const Text('Require Special Char'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Audit log retention
          Row(
            children: [
              const Text('Audit Log Retention:'),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: _settings['audit_log_retention_days'] ?? 90,
                items: _retentionOptions
                    .map((d) =>
                        DropdownMenuItem(value: d, child: Text('$d days')))
                    .toList(),
                onChanged: (v) =>
                    _updateSetting('audit_log_retention_days', v ?? 90),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Allowed file types
          Row(
            children: [
              const Text('Allowed File Types:'),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _fileTypesController,
                  decoration:
                      const InputDecoration(hintText: 'e.g. pdf,jpg,png'),
                  onSubmitted: (v) =>
                      _updateSetting('allowed_file_types', v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _updateSetting('allowed_file_types',
                    _fileTypesController?.text.trim() ?? ''),
                child: const Text('Save'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Maintenance banner
          if (_settings['maintenance_mode'] == true)
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Maintenance Mode Enabled: ${_settings['maintenance_reason'] ?? ''}',
                        style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          // Reset + version
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.restore),
                label: const Text('Reset to Default'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300]),
                onPressed: _resetToDefaults,
              ),
              const SizedBox(width: 24),
              Text(
                  'App Version: ${_settings['app_version'] ?? '1.0.0'}'),
            ],
          ),
          const SizedBox(height: 16),
          // Status summary
          const Text('Current System Status:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._features.map((f) => Text(
              '${f['label']}: ${(_settings[f['key']] ?? true) ? 'Enabled' : 'Disabled'}')),
          Text('Font: ${_settings['font_family'] ?? 'Roboto'}'),
          Text(
              'Primary Color: ${(_colorOptions.firstWhere((c) => c['value'] == (_settings['primary_color'] ?? 0xFF388E3C), orElse: () => {'label': 'Green'}))['label']}'),
          Text(
              'Session Timeout: ${_settings['session_timeout'] ?? 15} min'),
          Text(
              'Password Policy: Min ${_settings['min_password_length'] ?? 8} chars, Special Char: ${_settings['require_special_char'] == true ? 'Required' : 'Not Required'}'),
          Text(
              'Audit Log Retention: ${_settings['audit_log_retention_days'] ?? 90} days'),
          Text(
              'Allowed File Types: ${_settings['allowed_file_types'] ?? ''}'),
          if (_settings['maintenance_mode'] == true)
            Text(
              'Reason: ${_settings['maintenance_reason'] ?? ''}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          const SizedBox(height: 16),
          if (_settings['last_update'] != null &&
              _settings['last_update_by'] != null)
            Text(
                'Last updated: ${_settings['last_update'] is Timestamp ? DateFormat('yyyy-MM-dd HH:mm').format((_settings['last_update'] as Timestamp).toDate()) : _settings['last_update'].toString()} by ${_settings['last_update_by']}'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

extension StringCap on String {
  String capitalize() =>
      isEmpty ? this : this[0].toUpperCase() + substring(1);
}