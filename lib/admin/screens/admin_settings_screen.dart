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
    final isSuperAdmin = widget.admin?.role == AdminRole.superAdmin;

    _tabs = [
      _SettingsTab(icon: Icons.history,              label: 'Logs',         builder: _buildLogsTab),
      _SettingsTab(icon: Icons.notifications,        label: 'Notify',       builder: _buildNotificationsTab),
      _SettingsTab(icon: Icons.admin_panel_settings, label: 'Admins',       builder: _buildAdminsTab),
      _SettingsTab(icon: Icons.timer,                label: 'SLA',          builder: _buildSlaTab),
      _SettingsTab(icon: Icons.security,             label: 'Security',     builder: _buildSecurityTab),
      _SettingsTab(icon: Icons.email,                label: 'Templates',    builder: _buildEmailTemplatesTab),
      _SettingsTab(icon: Icons.manage_search,        label: 'Login History',builder: _buildLoginHistoryTab),
      if (!isSuperAdmin)
        _SettingsTab(icon: Icons.settings,           label: 'System',       builder: _buildSystemTab),
      if (isSuperAdmin)
        _SettingsTab(icon: Icons.assignment_ind,     label: 'Assign',       builder: _buildChairpersonAssignTab),
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
                tabs: _tabs.map((t) => Tab(icon: Icon(t.icon), text: t.label)).toList(),
              ),
            ),
      body: isEmbedded
          ? Column(
              children: [
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: _tabs.map((t) => Tab(icon: Icon(t.icon), text: t.label)).toList(),
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

  // =========================================================================
  // TAB BUILDERS
  // =========================================================================

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
              const Text('Notifications Center',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 300, child: _NotificationList()),
              const SizedBox(height: 16),
              const Divider(),
              const Text('Notification Configuration',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Notification channels, templates, and settings coming soon.'),
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
              onPressed: () async {
                final msg = messageController.text.trim();
                if (msg.isEmpty) return;
                await FirebaseFirestore.instance.collection('notifications').add({
                  'message':   msg,
                  'recipient': recipient,
                  'sentBy':    widget.admin?.email ?? 'Unknown',
                  'timestamp': Timestamp.now(),
                });
                await FirebaseFirestore.instance.collection('audit_logs').add({
                  'action':      'notify',
                  'performedBy': widget.admin?.email ?? 'Unknown',
                  'targetType':  'notification',
                  'details':     'Sent notification to $recipient',
                  'timestamp':   Timestamp.now(),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.person_add),
                    label: const Text('Invite Admin'),
                    onPressed: isSuperAdmin ? () => _showInviteAdminDialog(context) : null,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                    onPressed: () => setState(() {}),
                  ),
                  if (isSuperAdmin)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.group_add),
                      label: const Text('Create Ad Hoc Committee'),
                      onPressed: () => _showCreateAdHocCommitteeDialog(context),
                    ),
                  if (isSuperAdmin)
                    ElevatedButton.icon(
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Bulk Import CSV'),
                      onPressed: () => _showBulkImportDialog(context),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: _AdminList(
                  isSuperAdmin: isSuperAdmin,
                  adminEmail: widget.admin?.email ?? '',
                ),
              ),
              const SizedBox(height: 24),
              const Text('Roles:', style: TextStyle(fontWeight: FontWeight.bold)),
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
              const Text('• All members must have no previous allegations of sexual harassment.'),
              const Text('• No conflict of interest.'),
              const Text('• At least half of members are female.'),
              const Text('• Odd number of members.'),
              const Text('• Student reps only if students involved.'),
              const Text('• No junior staff to investigate senior staff unless victim is junior.'),
              const Text('• If perpetrator is Top Management, Council committee investigates.'),
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
                  DropdownMenuItem(value: 'committee',   child: Text('Committee Member')),
                  DropdownMenuItem(value: 'chairperson', child: Text('Chairperson')),
                  DropdownMenuItem(value: 'technical',   child: Text('Technical')),
                  DropdownMenuItem(value: 'superAdmin',  child: Text('Super Admin')),
                ],
                onChanged: (v) => setDialogState(() => selectedRole = v ?? 'committee'),
                decoration: const InputDecoration(labelText: 'Role'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text.trim();
                if (email.isEmpty) return;
                final token = const Uuid().v4();
                await FirebaseFirestore.instance.collection('admin_invites').add({
                  'email':     email,
                  'role':      selectedRole,
                  'invitedBy': widget.admin?.email ?? 'Unknown',
                  'timestamp': Timestamp.now(),
                  'token':     token,
                  'accepted':  false,
                });
                await FirebaseFirestore.instance.collection('audit_logs').add({
                  'action':      'invite',
                  'performedBy': widget.admin?.email ?? 'Unknown',
                  'targetType':  'admin_invite',
                  'targetId':    email,
                  'details':     'Invited $email as $selectedRole',
                  'timestamp':   Timestamp.now(),
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

  Widget _buildSlaTab()           => _SlaSettingsPanel(admin: widget.admin);
  Widget _buildSecurityTab()      => _SecuritySettingsPanel(admin: widget.admin);
  Widget _buildEmailTemplatesTab()=> _EmailTemplatesPanel(admin: widget.admin);
  Widget _buildLoginHistoryTab()  => const _LoginHistoryPanel();

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

// ===========================================================================
// _SettingsTab
// ===========================================================================

class _SettingsTab {
  final IconData icon;
  final String label;
  final Widget Function() builder;
  _SettingsTab({required this.icon, required this.label, required this.builder});
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
    pdf.addPage(pw.Page(
      build: (pw.Context c) => pw.Table.fromTextArray(headers: headers, data: data),
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
                  onChanged: (v) => setState(() { _search = v; _page = 0; }),
                ),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _actionFilter,
                items: _actions.map((a) => DropdownMenuItem(
                  value: a, child: Text(a.capitalize()),
                )).toList(),
                onChanged: (v) => setState(() { _actionFilter = v ?? 'All'; _page = 0; }),
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
              rows: pageLogs.map((l) => DataRow(cells: [
                DataCell(Text(l.action)),
                DataCell(Text(l.performedBy)),
                DataCell(Text(l.targetId   ?? '')),
                DataCell(Text(l.targetType ?? '')),
                DataCell(Text(l.details    ?? '')),
                DataCell(Text(DateFormat('yyyy-MM-dd HH:mm').format(l.timestamp.toDate()))),
              ])).toList(),
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
              onPressed: end < logs.length ? () => setState(() => _page++) : null,
            ),
          ],
        ),
      ],
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
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No notifications found.'));
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final data      = docs[i].data() as Map<String, dynamic>;
            final msg       = data['message']   ?? '';
            final recipient = data['recipient'] ?? 'all';
            final sentBy    = data['sentBy']    ?? 'Unknown';
            final ts        = data['timestamp'] as Timestamp?;
            final time      = ts != null
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

// ===========================================================================
// _AdminList
// ===========================================================================

class _AdminList extends StatefulWidget {
  final bool isSuperAdmin;
  final String adminEmail;
  const _AdminList({this.isSuperAdmin = false, required this.adminEmail});
  @override
  State<_AdminList> createState() => _AdminListState();
}

class _AdminListState extends State<_AdminList> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('admins').get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return const Center(child: Text('No admins found.'));
        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, i) {
            final data        = docs[i].data() as Map<String, dynamic>;
            final id          = docs[i].id;
            final email       = data['email']  ?? '';
            final role        = data['role']   ?? 'committee';
            final status      = data['active'] == false ? 'Revoked' : 'Active';
            final hasConflict = data['conflictOfInterest'] == true;
            return ListTile(
              leading: Stack(
                children: [
                  Icon(Icons.person,
                      color: role == 'superAdmin' ? Colors.red : AppColors.primaryGreen),
                  if (hasConflict)
                    const Positioned(
                      right: 0, bottom: 0,
                      child: Icon(Icons.flag, color: Colors.orange, size: 12),
                    ),
                ],
              ),
              title: Text(email),
              subtitle: Text('Role: $role | Status: $status'
                  '${hasConflict ? ' | ⚠ Conflict flagged' : ''}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.isSuperAdmin)
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Change Role',
                      onPressed: () => _showChangeRoleDialog(context, id, role),
                    ),
                  IconButton(
                    icon: const Icon(Icons.flag_outlined),
                    tooltip: 'Flag Conflict of Interest',
                    onPressed: () => _showConflictOfInterestDialog(context, id, email),
                  ),
                  IconButton(
                    icon: Icon(status == 'Active' ? Icons.block : Icons.check_circle),
                    tooltip: status == 'Active' ? 'Revoke Access' : 'Restore Access',
                    onPressed: () => _toggleAdminStatus(context, id, status == 'Active'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showChangeRoleDialog(BuildContext context, String adminId, String currentRole) {
    String selectedRole = currentRole;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Change Admin Role'),
          content: DropdownButtonFormField<String>(
            value: selectedRole,
            items: const [
              DropdownMenuItem(value: 'committee',   child: Text('Committee Member')),
              DropdownMenuItem(value: 'chairperson', child: Text('Chairperson')),
              DropdownMenuItem(value: 'technical',   child: Text('Technical')),
              DropdownMenuItem(value: 'superAdmin',  child: Text('Super Admin')),
            ],
            onChanged: (v) => setDialogState(() => selectedRole = v ?? currentRole),
            decoration: const InputDecoration(labelText: 'Role'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('admins').doc(adminId)
                    .update({'role': selectedRole});
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

  void _showConflictOfInterestDialog(BuildContext context, String adminId, String email) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Flag Conflict of Interest: $email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'This will prevent this admin from being assigned to related cases.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Reason', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('admins').doc(adminId)
                  .update({'conflictOfInterest': true, 'conflictReason': reason});
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
                  const SnackBar(content: Text('Conflict of interest flagged.')),
                );
              }
              setState(() {});
            },
            child: const Text('Flag'),
          ),
        ],
      ),
    );
  }

  void _toggleAdminStatus(BuildContext context, String adminId, bool isActive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isActive ? 'Revoke Access' : 'Restore Access'),
        content: Text(isActive
            ? 'Are you sure you want to revoke this admin?'
            : 'Restore this admin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Revoke' : 'Restore'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('admins').doc(adminId)
          .update({'active': !isActive});
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
          SnackBar(content: Text(isActive ? 'Access revoked.' : 'Access restored.')),
        );
      }
      setState(() {});
    }
  }
}

// ===========================================================================
// NEW: _SlaSettingsPanel — SLA deadlines, auto-escalation, case numbering
// ===========================================================================

class _SlaSettingsPanel extends StatefulWidget {
  final AdminUser? admin;
  const _SlaSettingsPanel({this.admin});
  @override
  State<_SlaSettingsPanel> createState() => _SlaSettingsPanelState();
}

class _SlaSettingsPanelState extends State<_SlaSettingsPanel> {
  bool _loading = true;
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
      _sla = doc.exists ? (doc.data() ?? Map.from(_slaDefaults)) : Map.from(_slaDefaults);
      _escalationEmailController.text = _sla['escalation_contact'] ?? '';
      _loading = false;
    });
  }

  Future<void> _updateSla(String key, dynamic value) async {
    await FirebaseFirestore.instance.collection('system').doc('sla').set(
      {
        key: value,
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
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final autoEscalate = _sla['auto_escalate'] ?? true;
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SLA & Auto-Escalation Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                    'Configure case deadlines, auto-escalation, and case numbering.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),

                // Resolution deadline
                const _SectionHeader('Case Resolution Deadline'),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Cases must be resolved within:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _sla['resolution_days'] ?? 30,
                    items: _resolutionOptions.map((d) =>
                        DropdownMenuItem(value: d, child: Text('$d days'))).toList(),
                    onChanged: (v) => _updateSla('resolution_days', v ?? 30),
                  ),
                ]),
                const SizedBox(height: 20),

                // Auto-escalation
                const _SectionHeader('Auto-Escalation'),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(
                      child: Text('Notify escalation contact when a case is unactioned:')),
                  Switch(
                    value: autoEscalate,
                    onChanged: (v) => _updateSla('auto_escalate', v),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Escalate after:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _sla['escalation_after_days'] ?? 7,
                    items: _escalationOptions.map((d) =>
                        DropdownMenuItem(value: d, child: Text('$d days'))).toList(),
                    onChanged: autoEscalate
                        ? (v) => _updateSla('escalation_after_days', v ?? 7)
                        : null,
                  ),
                  const SizedBox(width: 24),
                  const Text('Remind every:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _sla['reminder_every_days'] ?? 3,
                    items: _reminderOptions.map((d) =>
                        DropdownMenuItem(value: d, child: Text('$d days'))).toList(),
                    onChanged: autoEscalate
                        ? (v) => _updateSla('reminder_every_days', v ?? 3)
                        : null,
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Escalation contact email:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _escalationEmailController,
                      enabled: autoEscalate,
                      decoration: const InputDecoration(
                          hintText: 'e.g. chairperson@institution.edu',
                          isDense: true),
                      onSubmitted: (v) => _updateSla('escalation_contact', v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: autoEscalate
                        ? () => _updateSla('escalation_contact',
                            _escalationEmailController.text.trim())
                        : null,
                    child: const Text('Save'),
                  ),
                ]),
                const SizedBox(height: 24),

                // Case numbering
                const _SectionHeader('Case Numbering Format'),
                const SizedBox(height: 8),
                Row(children: [
                  const Text('Format:'),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _sla['case_number_format'] ?? 'SH-{YEAR}-{SEQ}',
                    items: _caseNumberFormats.map((f) =>
                        DropdownMenuItem(value: f, child: Text(f))).toList(),
                    onChanged: (v) => _updateSla('case_number_format', v ?? 'SH-{YEAR}-{SEQ}'),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    'Preview: ${(_sla['case_number_format'] ?? 'SH-{YEAR}-{SEQ}')
                        .replaceAll('{YEAR}', DateTime.now().year.toString())
                        .replaceAll('{SEQ}', (_sla['next_case_seq'] ?? 1)
                            .toString().padLeft(4, '0'))}',
                    style: const TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.blueGrey),
                  ),
                ]),
                const SizedBox(height: 24),

                // Summary
                const _SectionHeader('Current SLA Summary'),
                const SizedBox(height: 8),
                _SummaryRow('Resolution deadline',  '${_sla['resolution_days'] ?? 30} days'),
                _SummaryRow('Auto-escalation',      autoEscalate ? 'Enabled' : 'Disabled'),
                _SummaryRow('Escalate after',       '${_sla['escalation_after_days'] ?? 7} days'),
                _SummaryRow('Remind every',         '${_sla['reminder_every_days'] ?? 3} days'),
                _SummaryRow('Escalation contact',   _sla['escalation_contact'] ?? '—'),
                _SummaryRow('Case number format',   _sla['case_number_format'] ?? 'SH-{YEAR}-{SEQ}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// NEW: _SecuritySettingsPanel — lockout, IP allowlist, per-role 2FA
// ===========================================================================

class _SecuritySettingsPanel extends StatefulWidget {
  final AdminUser? admin;
  const _SecuritySettingsPanel({this.admin});
  @override
  State<_SecuritySettingsPanel> createState() => _SecuritySettingsPanelState();
}

class _SecuritySettingsPanelState extends State<_SecuritySettingsPanel> {
  bool _loading = true;
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
      _sec = doc.exists ? (doc.data() ?? Map.from(_secDefaults)) : Map.from(_secDefaults);
      _ipController.text = _sec['ip_allowlist'] ?? '';
      _loading = false;
    });
  }

  Future<void> _updateSec(String key, dynamic value) async {
    await FirebaseFirestore.instance.collection('system').doc('security').set(
      {
        key: value,
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
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final lockoutEnabled  = _sec['lockout_enabled']       ?? true;
    final ipEnabled       = _sec['ip_allowlist_enabled']  ?? false;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Security Settings',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text(
                    'Login lockout, IP restrictions, and per-role 2FA configuration.',
                    style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 24),

                // Lockout
                const _SectionHeader('Failed Login Lockout'),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(
                      child: Text('Lock account after failed login attempts:')),
                  Switch(
                    value: lockoutEnabled,
                    onChanged: (v) => _updateSec('lockout_enabled', v),
                  ),
                ]),
                Row(children: [
                  const Text('Lock after:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _sec['lockout_attempts'] ?? 5,
                    items: _lockoutAttemptOptions.map((n) =>
                        DropdownMenuItem(value: n, child: Text('$n attempts'))).toList(),
                    onChanged: lockoutEnabled
                        ? (v) => _updateSec('lockout_attempts', v ?? 5)
                        : null,
                  ),
                  const SizedBox(width: 24),
                  const Text('Lock duration:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: _sec['lockout_duration_mins'] ?? 15,
                    items: _lockoutDurationOptions.map((m) =>
                        DropdownMenuItem(value: m, child: Text('$m min'))).toList(),
                    onChanged: lockoutEnabled
                        ? (v) => _updateSec('lockout_duration_mins', v ?? 15)
                        : null,
                  ),
                ]),
                const SizedBox(height: 24),

                // IP allowlist
                const _SectionHeader('IP Allowlist'),
                const SizedBox(height: 8),
                Row(children: [
                  const Expanded(
                      child: Text('Restrict admin logins to specific IP ranges:')),
                  Switch(
                    value: ipEnabled,
                    onChanged: (v) => _updateSec('ip_allowlist_enabled', v),
                  ),
                ]),
                Row(children: [
                  const Text('Allowed IPs:'),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _ipController,
                      enabled: ipEnabled,
                      decoration: const InputDecoration(
                          hintText: 'e.g. 192.168.1.0/24, 10.0.0.1',
                          isDense: true),
                      onSubmitted: (v) => _updateSec('ip_allowlist', v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: ipEnabled
                        ? () => _updateSec('ip_allowlist', _ipController.text.trim())
                        : null,
                    child: const Text('Save'),
                  ),
                ]),
                const SizedBox(height: 24),

                // Per-role 2FA
                const _SectionHeader('Two-Factor Authentication (Per Role)'),
                const SizedBox(height: 8),
                ...[
                  {'key': 'two_fa_superAdmin',  'label': 'Super Admin'},
                  {'key': 'two_fa_chairperson', 'label': 'Chairperson'},
                  {'key': 'two_fa_committee',   'label': 'Committee Member'},
                  {'key': 'two_fa_technical',   'label': 'Technical'},
                ].map((r) => Row(children: [
                  Expanded(child: Text('Require 2FA for ${r['label']}:')),
                  Switch(
                    value: _sec[r['key']] ?? false,
                    onChanged: (v) => _updateSec(r['key']!, v),
                  ),
                ])),
                const SizedBox(height: 24),

                // Summary
                const _SectionHeader('Current Security Summary'),
                const SizedBox(height: 8),
                _SummaryRow('Lockout',           lockoutEnabled ? 'Enabled' : 'Disabled'),
                _SummaryRow('Lockout threshold', '${_sec['lockout_attempts'] ?? 5} attempts'),
                _SummaryRow('Lockout duration',  '${_sec['lockout_duration_mins'] ?? 15} min'),
                _SummaryRow('IP Allowlist',      ipEnabled ? 'Enabled' : 'Disabled'),
                _SummaryRow('2FA Super Admin',   (_sec['two_fa_superAdmin']  ?? true)  ? 'Required' : 'Not required'),
                _SummaryRow('2FA Chairperson',   (_sec['two_fa_chairperson'] ?? true)  ? 'Required' : 'Not required'),
                _SummaryRow('2FA Committee',     (_sec['two_fa_committee']   ?? false) ? 'Required' : 'Not required'),
                _SummaryRow('2FA Technical',     (_sec['two_fa_technical']   ?? false) ? 'Required' : 'Not required'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// NEW: _EmailTemplatesPanel — editable system email templates
// ===========================================================================

class _EmailTemplatesPanel extends StatefulWidget {
  final AdminUser? admin;
  const _EmailTemplatesPanel({this.admin});
  @override
  State<_EmailTemplatesPanel> createState() => _EmailTemplatesPanelState();
}

class _EmailTemplatesPanelState extends State<_EmailTemplatesPanel> {
  bool _loading = true;
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
    _subjectCtrl = TextEditingController();
    _bodyCtrl    = TextEditingController();
    _fetchTemplates();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  String _defaultSubject(String key) {
    const map = {
      'case_received': 'Your report has been received — {{caseNumber}}',
      'case_assigned': 'Case {{caseNumber}} has been assigned',
      'case_update':   'Update on case {{caseNumber}}',
      'case_resolved': 'Case {{caseNumber}} has been resolved',
      'admin_invite':  'You have been invited to join the admin panel',
      'escalation':    'ESCALATION: Case {{caseNumber}} requires immediate attention',
      'sla_reminder':  'Reminder: Case {{caseNumber}} SLA deadline approaching',
    };
    return map[key] ?? key;
  }

  String _defaultBody(String key) {
    const map = {
      'case_received':
          'Dear {{recipientName}},\n\nWe have received your report ({{caseNumber}}) '
          'and it is currently under review.\n\nRegards,\n{{institutionName}}',
      'case_assigned':
          'Dear Committee Member,\n\nCase {{caseNumber}} has been assigned to you. '
          'Please review it within the SLA period.\n\nRegards,\n{{institutionName}}',
      'case_update':
          'Dear {{recipientName}},\n\nThere is an update on case {{caseNumber}}:\n'
          '{{updateDetails}}\n\nRegards,\n{{institutionName}}',
      'case_resolved':
          'Dear {{recipientName}},\n\nCase {{caseNumber}} has been resolved.\n'
          '{{resolutionSummary}}\n\nRegards,\n{{institutionName}}',
      'admin_invite':
          'Dear {{recipientName}},\n\nYou have been invited as {{role}}. '
          'Use this link to set up your account:\n{{inviteLink}}\n\nRegards,\n{{institutionName}}',
      'escalation':
          'Dear {{escalationContact}},\n\nCase {{caseNumber}} has been unactioned '
          'for {{days}} days and requires immediate attention.\n\nRegards,\nSystem',
      'sla_reminder':
          'Dear {{assigneeName}},\n\nThis is a reminder that case {{caseNumber}} '
          'is due in {{daysRemaining}} days.\n\nRegards,\nSystem',
    };
    return map[key] ?? '';
  }

  Future<void> _fetchTemplates() async {
    setState(() => _loading = true);
    final doc  = await FirebaseFirestore.instance
        .collection('system').doc('email_templates').get();
    final data = (doc.exists ? doc.data() : null) ?? {};
    final Map<String, Map<String, String>> fetched = {};
    for (final t in _templateDefs) {
      final key = t['key']!;
      fetched[key] = (data.containsKey(key) && data[key] is Map)
          ? Map<String, String>.from(data[key] as Map)
          : {'subject': _defaultSubject(key), 'body': _defaultBody(key)};
    }
    setState(() {
      _templates = fetched;
      _loading   = false;
      _loadTemplate(_selectedKey);
    });
  }

  void _loadTemplate(String key) {
    _subjectCtrl.text = _templates[key]?['subject'] ?? '';
    _bodyCtrl.text    = _templates[key]?['body']    ?? '';
  }

  Future<void> _saveTemplate() async {
    await FirebaseFirestore.instance.collection('system').doc('email_templates').set(
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Template saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Email Templates',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text(
                  'Customize system emails. Use {{placeholders}} for dynamic content.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              Row(children: [
                const Text('Template:'),
                const SizedBox(width: 12),
                DropdownButton<String>(
                  value: _selectedKey,
                  items: _templateDefs.map((t) => DropdownMenuItem(
                    value: t['key'], child: Text(t['label']!),
                  )).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _selectedKey = v);
                    _loadTemplate(v);
                  },
                ),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: _subjectCtrl,
                decoration: const InputDecoration(
                    labelText: 'Subject', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _bodyCtrl,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Body',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save Template'),
                  onPressed: _saveTemplate,
                ),
                const SizedBox(width: 16),
                TextButton.icon(
                  icon: const Icon(Icons.restore),
                  label: const Text('Reset to Default'),
                  onPressed: () => setState(() {
                    _subjectCtrl.text = _defaultSubject(_selectedKey);
                    _bodyCtrl.text    = _defaultBody(_selectedKey);
                  }),
                ),
              ]),
              const SizedBox(height: 12),
              const Text('Available placeholders:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Wrap(
                spacing: 8, runSpacing: 4,
                children: [
                  Chip(label: Text('{{caseNumber}}')),
                  Chip(label: Text('{{recipientName}}')),
                  Chip(label: Text('{{institutionName}}')),
                  Chip(label: Text('{{role}}')),
                  Chip(label: Text('{{inviteLink}}')),
                  Chip(label: Text('{{days}}')),
                  Chip(label: Text('{{daysRemaining}}')),
                  Chip(label: Text('{{updateDetails}}')),
                  Chip(label: Text('{{resolutionSummary}}')),
                  Chip(label: Text('{{assigneeName}}')),
                  Chip(label: Text('{{escalationContact}}')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// NEW: _LoginHistoryPanel — paginated admin login history
// ===========================================================================

class _LoginHistoryPanel extends StatefulWidget {
  const _LoginHistoryPanel();
  @override
  State<_LoginHistoryPanel> createState() => _LoginHistoryPanelState();
}

class _LoginHistoryPanelState extends State<_LoginHistoryPanel> {
  bool _loading = true;
  List<Map<String, dynamic>> _entries = [];
  String _search = '';
  int _page = 0;
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
    if (_search.isEmpty) return _entries;
    final q = _search.toLowerCase();
    return _entries.where((e) =>
        (e['email']  ?? '').toString().toLowerCase().contains(q) ||
        (e['ip']     ?? '').toString().toLowerCase().contains(q) ||
        (e['device'] ?? '').toString().toLowerCase().contains(q) ||
        (e['status'] ?? '').toString().toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final entries    = _filtered;
    final start      = _page * _perPage;
    final end        = (start + _perPage).clamp(0, entries.length);
    final pageData   = entries.sublist(start, end);
    final totalPages = entries.isEmpty ? 1 : ((entries.length - 1) / _perPage).floor() + 1;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Text('Admin Login History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                  onPressed: _fetch,
                ),
              ]),
              const SizedBox(height: 4),
              const Text(
                  'Every admin sign-in attempt with IP address, device, and outcome.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search by email, IP, device, or status',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() { _search = v; _page = 0; }),
              ),
              const SizedBox(height: 12),
              entries.isEmpty
                  ? const Expanded(
                      child: Center(
                        child: Text(
                          'No login history found.\n\nLogin events are written to '
                          'admin_login_history automatically when admins sign in.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Email')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('IP Address')),
                            DataColumn(label: Text('Device')),
                            DataColumn(label: Text('Time')),
                          ],
                          rows: pageData.map((e) {
                            final ts      = e['timestamp'] as Timestamp?;
                            final time    = ts != null
                                ? DateFormat('yyyy-MM-dd HH:mm').format(ts.toDate())
                                : '—';
                            final status  = (e['status'] ?? 'unknown').toString();
                            final isOk    = status == 'success';
                            return DataRow(cells: [
                              DataCell(Text(e['email']  ?? '—')),
                              DataCell(Row(children: [
                                Icon(
                                  isOk ? Icons.check_circle : Icons.cancel,
                                  color: isOk ? Colors.green : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(status.capitalize()),
                              ])),
                              DataCell(Text(e['ip']     ?? '—')),
                              DataCell(Text(e['device'] ?? '—')),
                              DataCell(Text(time)),
                            ]);
                          }).toList(),
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
                    onPressed: end < entries.length ? () => setState(() => _page++) : null,
                  ),
                ],
              ),
            ],
          ),
        ),
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
  Map<String, dynamic> _settings = {};

  final _features = [
    {'key': 'notifications',    'label': 'Notifications'},
    {'key': 'report_editing',   'label': 'Report Editing'},
    {'key': 'maintenance_mode', 'label': 'Maintenance Mode'},
    {'key': 'user_registration','label': 'User Registration'},
    {'key': 'admin_2fa',        'label': 'Admin 2FA (Global)'},
  ];
  final _retentionOptions = [30, 90, 180, 365];
  final _fontOptions      = ['Roboto', 'Open Sans', 'Lato', 'Montserrat', 'Nunito'];
  final _colorOptions     = [
    {'label': 'Green',  'value': 0xFF388E3C},
    {'label': 'Blue',   'value': 0xFF1976D2},
    {'label': 'Purple', 'value': 0xFF7B1FA2},
    {'label': 'Red',    'value': 0xFFD32F2F},
    {'label': 'Orange', 'value': 0xFFF57C00},
  ];
  final _timeoutOptions = [5, 10, 15, 30, 60];

  TextEditingController? _maintenanceReasonController;
  TextEditingController? _fileTypesController;
  TextEditingController? _minPasswordLengthController;
  bool _requireSpecialChar = false;

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
    'app_version':              '1.0.0',
    'last_update':              null,
    'last_update_by':           null,
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
        .collection('system').doc('settings').get();
    setState(() {
      _settings = doc.exists ? (doc.data() ?? Map.from(_defaults)) : Map.from(_defaults);
      _loading  = false;
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
    await FirebaseFirestore.instance.collection('system').doc('settings').set(
      {
        key: value,
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
    await _fetchSettings();
  }

  Future<void> _resetToDefaults() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset All Settings'),
        content: const Text(
            'Are you sure you want to reset all system settings to defaults? '
            'This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('System Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._features.map((f) {
            if (f['key'] == 'maintenance_mode') {
              return Row(children: [
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
                                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
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
              ]);
            }
            return Row(children: [
              Expanded(child: Text(f['label']!)),
              Switch(
                value: _settings[f['key']] ?? true,
                onChanged: (val) => _updateSetting(f['key']!, val),
              ),
            ]);
          }),
          const SizedBox(height: 16),
          Row(children: [
            const Text('App Font:'),
            const SizedBox(width: 12),
            DropdownButton<String>(
              value: _settings['font_family'] ?? 'Roboto',
              items: _fontOptions.map((f) => DropdownMenuItem(
                value: f, child: Text(f, style: TextStyle(fontFamily: f)),
              )).toList(),
              onChanged: (v) => _updateSetting('font_family', v ?? 'Roboto'),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Primary Color:'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _settings['primary_color'] ?? 0xFF388E3C,
              items: _colorOptions.map((c) => DropdownMenuItem(
                value: c['value'] as int,
                child: Row(children: [
                  Container(width: 20, height: 20, color: Color(c['value'] as int)),
                  const SizedBox(width: 8),
                  Text(c['label'] as String),
                ]),
              )).toList(),
              onChanged: (v) => _updateSetting('primary_color', v ?? 0xFF388E3C),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Session Timeout:'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _settings['session_timeout'] ?? 15,
              items: _timeoutOptions.map((t) =>
                  DropdownMenuItem(value: t, child: Text('$t min'))).toList(),
              onChanged: (v) => _updateSetting('session_timeout', v ?? 15),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Password Policy:'),
            const SizedBox(width: 12),
            SizedBox(
              width: 60,
              child: TextField(
                controller: _minPasswordLengthController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Min Length', isDense: true),
                onSubmitted: (v) =>
                    _updateSetting('min_password_length', int.tryParse(v) ?? 8),
              ),
            ),
            const SizedBox(width: 12),
            Row(children: [
              Checkbox(
                value: _requireSpecialChar,
                onChanged: (v) {
                  setState(() => _requireSpecialChar = v ?? true);
                  _updateSetting('require_special_char', v ?? true);
                },
              ),
              const Text('Require Special Char'),
            ]),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Audit Log Retention:'),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _settings['audit_log_retention_days'] ?? 90,
              items: _retentionOptions.map((d) =>
                  DropdownMenuItem(value: d, child: Text('$d days'))).toList(),
              onChanged: (v) => _updateSetting('audit_log_retention_days', v ?? 90),
            ),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            const Text('Allowed File Types:'),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _fileTypesController,
                decoration: const InputDecoration(hintText: 'e.g. pdf,jpg,png'),
                onSubmitted: (v) => _updateSetting('allowed_file_types', v.trim()),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _updateSetting('allowed_file_types',
                  _fileTypesController?.text.trim() ?? ''),
              child: const Text('Save'),
            ),
          ]),
          const SizedBox(height: 16),
          if (_settings['maintenance_mode'] == true)
            Card(
              color: Colors.red[50],
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(children: [
                  const Icon(Icons.warning, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(child: Text(
                    'Maintenance Mode: ${_settings['maintenance_reason'] ?? ''}',
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  )),
                ]),
              ),
            ),
          const SizedBox(height: 16),
          Row(children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Reset to Default'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[300]),
              onPressed: _resetToDefaults,
            ),
            const SizedBox(width: 24),
            Text('App Version: ${_settings['app_version'] ?? '1.0.0'}'),
          ]),
          const SizedBox(height: 16),
          const Text('Current System Status:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._features.map((f) => Text(
              '${f['label']}: ${(_settings[f['key']] ?? true) ? 'Enabled' : 'Disabled'}')),
          Text('Font: ${_settings['font_family'] ?? 'Roboto'}'),
          Text('Primary Color: ${(_colorOptions.firstWhere((c) => c['value'] == (_settings['primary_color'] ?? 0xFF388E3C), orElse: () => {'label': 'Green'}))['label']}'),
          Text('Session Timeout: ${_settings['session_timeout'] ?? 15} min'),
          Text('Password Policy: Min ${_settings['min_password_length'] ?? 8} chars, '
              'Special Char: ${_settings['require_special_char'] == true ? 'Required' : 'Not Required'}'),
          Text('Audit Log Retention: ${_settings['audit_log_retention_days'] ?? 90} days'),
          Text('Allowed File Types: ${_settings['allowed_file_types'] ?? ''}'),
          if (_settings['maintenance_mode'] == true)
            Text('Reason: ${_settings['maintenance_reason'] ?? ''}',
                style: const TextStyle(fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          if (_settings['last_update'] != null && _settings['last_update_by'] != null)
            Text('Last updated: '
                '${_settings['last_update'] is Timestamp ? DateFormat('yyyy-MM-dd HH:mm').format((_settings['last_update'] as Timestamp).toDate()) : _settings['last_update'].toString()}'
                ' by ${_settings['last_update_by']}'),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared helper widgets
// ===========================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      const Divider(),
    ],
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      SizedBox(
          width: 200,
          child: Text('$label:', style: const TextStyle(color: Colors.grey))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
    ]),
  );
}

// ===========================================================================
// Extension
// ===========================================================================

extension StringCap on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}