import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:html' as html;
import '../../constants/app_colors.dart';
import '../../models/admin_user.dart';
import '../../services/firebase_ai_report_service.dart';
import '../widgets/ai_insights_panel.dart';
import '../../utils/user_role_utils.dart';

class ReportsManagementScreen extends StatefulWidget {
  final AdminUser admin;
  final bool embedded;

  const ReportsManagementScreen({
    super.key,
    required this.admin,
    this.embedded = false,
  });

  @override
  State<ReportsManagementScreen> createState() =>
      _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all';
  String _selectedFaculty = 'all';
  String _selectedDepartment = 'all';
  String _selectedRole = 'all';
  String _selectedStudyLevel = 'all';
  bool _anonymousOnly = false;
  DateTimeRange? _dateRange;

  // Cached user data for filtering
  Map<String, Map<String, dynamic>> _usersCache = {};
  bool _usersCacheLoaded = false;
  String _currentRoleKey = 'moderator';

  final List<String> _faculties = [
    'Faculty of Medicine',
    'Faculty of Science',
    'Faculty of Computing and Informatics',
    'Faculty of Applied Sciences and Technology',
    'Faculty of Business and Management Sciences',
    'Faculty of Interdisciplinary Studies',
  ];

  final Map<String, List<String>> _facultyDepartments = {
    'Faculty of Medicine': [
      'Anatomy',
      'Biochemistry',
      'Internal Medicine',
      'Surgery',
      'Pediatrics',
      'Obstetrics & Gynecology',
      'Family Medicine',
      'Medical Laboratory Sciences',
      'Pharmacy',
      'Microbiology',
      'Pathology',
      'Radiology',
      'Physiology',
      'Psychiatry',
      'Community Health',
      'Nursing/Midwifery',
    ],
    'Faculty of Science': ['Biology', 'Chemistry', 'Physics', 'Mathematics'],
    'Faculty of Computing and Informatics': [
      'Computer Science',
      'Information Technology',
      'Software Engineering',
    ],
    'Faculty of Applied Sciences and Technology': [
      'Biomedical Sciences & Engineering',
      'Civil Engineering',
      'Electrical & Electronics Engineering',
      'Mechanical Engineering',
      'Petroleum & Environmental Management',
    ],
    'Faculty of Business and Management Sciences': [
      'Accounting & Finance',
      'Business Administration',
      'Economics',
      'Procurement & Supply Chain Management',
      'Marketing & Entrepreneurship',
    ],
    'Faculty of Interdisciplinary Studies': [
      'Planning & Governance',
      'Human Development & Relational Sciences',
      'Environment & Livelihood Support Systems',
      'Community Engagement & Service Learning',
    ],
  };

  final List<String> _roles = UserRoleUtils.selectableRoles;
  final List<String> _studyLevels = ['Undergraduate', 'Postgraduate'];

  final Map<String, String> _statusLabels = {
    'all': 'All Reports',
    'pending': 'Pending',
    'submitted': 'Submitted',
    'under_review': 'Under Review',
    'investigating': 'Investigating',
    'resolved': 'Resolved',
    'closed': 'Closed',
  };

  final Map<String, Color> _statusColors = {
    'pending': Colors.orange,
    'submitted': AppColors.primaryGreen,
    'under_review': AppColors.secondaryOrange,
    'investigating': AppColors.primaryDark,
    'resolved': AppColors.mustGreen,
    'closed': Colors.grey,
  };

  final List<String> _workflowStages = const [
    'pending',
    'submitted',
    'under_review',
    'investigating',
    'resolved',
    'closed',
  ];

  @override
  void initState() {
    super.initState();
    _loadCurrentAdminRole();
    _loadUsersCache();
  }

  String _normalizeRoleKey(String? rawRole) {
    final compact = (rawRole ?? '')
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z]'), '')
        .toLowerCase();

    switch (compact) {
      case 'devteam':
        return 'devTeam';
      case 'superadmin':
        return 'superAdmin';
      case 'chairperson':
        return 'chairperson';
      case 'committeemember':
        return 'committeeMember';
      case 'adhocmember':
        return 'adHocMember';
      case 'advisor':
        return 'advisor';
      case 'studentrep':
        return 'studentRep';
      case 'technicalofficer':
        return 'technicalOfficer';
      case 'reviewer':
        return 'reviewer';
      case 'moderator':
        return 'moderator';
      default:
        return 'moderator';
    }
  }

  String _toTitle(String value) {
    final normalized = value.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return normalized;
    return normalized[0].toUpperCase() + normalized.substring(1);
  }

  Future<void> _loadCurrentAdminRole() async {
    try {
      final adminDoc =
          await _firestore.collection('admins').doc(widget.admin.uid).get();
      final data = adminDoc.data();
      final rawRole = (data?['shcRole'] ?? data?['role']) as String?;
      final normalized = _normalizeRoleKey(rawRole ?? widget.admin.role.value);
      if (!mounted) return;
      setState(() => _currentRoleKey = normalized);
    } catch (_) {
      final fallback = _normalizeRoleKey(widget.admin.role.value);
      if (!mounted) return;
      setState(() => _currentRoleKey = fallback);
    }
  }

  bool _canManageReportsByRole() {
    return {
      'devTeam',
      'superAdmin',
      'chairperson',
      'committeeMember',
      'adHocMember',
      'reviewer',
      'moderator',
    }.contains(_currentRoleKey);
  }

  bool _canAssignReportsByRole() {
    return {
      'devTeam',
      'superAdmin',
      'chairperson',
      'committeeMember',
      'reviewer',
    }.contains(_currentRoleKey);
  }

  Future<void> _loadUsersCache() async {
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      final Map<String, Map<String, dynamic>> cache = {};
      for (final doc in usersSnapshot.docs) {
        cache[doc.id] = doc.data();
      }
      if (!mounted) return;
      setState(() {
        _usersCache = cache;
        _usersCacheLoaded = true;
      });
    } catch (e) {
      print('Error loading users cache: $e');
    }
  }

  List<String> get _availableDepartments {
    if (_selectedFaculty == 'all') {
      return _facultyDepartments.values.expand((d) => d).toSet().toList()
        ..sort();
    }
    return _facultyDepartments[_selectedFaculty] ?? [];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getReportCategory(Map<String, dynamic> data) {
    final raw =
        data['category'] ?? data['reportCategory'] ?? data['type'] ?? 'N/A';
    final value = raw.toString().trim();
    return value.isEmpty ? 'N/A' : value;
  }

  bool _canTransitionStatus(String from, String to) {
    if (from == to) return false;
    if (!_workflowStages.contains(from) || !_workflowStages.contains(to)) {
      return false;
    }

    final fromIndex = _workflowStages.indexOf(from);
    final toIndex = _workflowStages.indexOf(to);

    switch (_currentRoleKey) {
      case 'devTeam':
      case 'superAdmin':
      case 'chairperson':
        // Full control for top governance roles.
        return true;
      case 'committeeMember':
      case 'adHocMember':
      case 'reviewer':
        // Working committee lanes: move the case forward only.
        return toIndex == fromIndex + 1;
      case 'advisor':
        // Advisors can push investigations but not close cases.
        return (from == 'under_review' && to == 'investigating') ||
            (from == 'investigating' && to == 'under_review');
      case 'technicalOfficer':
      case 'studentRep':
        return false;
      case 'moderator':
        // Legacy moderator role: triage into review.
        return from == 'submitted' && to == 'under_review';
      default:
        return false;
    }
  }

  Future<void> _updateReportStatus(
    String reportId,
    String newStatus, {
    String? resolutionMessage,
  }) async {
    try {
      // Get the report to find the userId
      final reportDoc =
          await _firestore.collection('reports').doc(reportId).get();
      final reportData = reportDoc.data();

      // Build update data
      final Map<String, dynamic> updateData = {
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': widget.admin.uid,
        'currentStage': newStatus,
      };

      // Add resolution details if provided
      if (resolutionMessage != null && resolutionMessage.isNotEmpty) {
        updateData['resolutionMessage'] = resolutionMessage;
        updateData['resolvedAt'] = FieldValue.serverTimestamp();
        updateData['resolvedBy'] = widget.admin.uid;
      }

      // Update report status
      await _firestore.collection('reports').doc(reportId).update(updateData);

      // Track process event for role-based auditing
      await _logProcessEvent(
        reportId: reportId,
        action: 'status_changed',
        stage: newStatus,
        meta: {
          'status': newStatus,
          if (resolutionMessage != null && resolutionMessage.isNotEmpty)
            'resolutionMessage': resolutionMessage,
        },
      );

      // Send notification to reporter (only if not anonymous)
      if (reportData != null &&
          reportData['isAnonymous'] != true &&
          reportData['userId'] != null) {
        // Create notification message based on status
        String notificationTitle = 'Report Status Updated';
        String notificationBody = '';

        switch (newStatus.toLowerCase()) {
          case 'pending':
            notificationBody = 'Your report is awaiting review.';
            break;
          case 'under review':
            notificationBody = 'Your report is now under review by our team.';
            break;
          case 'investigating':
            notificationBody =
                'Your report is being investigated. We will keep you updated.';
            break;
          case 'resolved':
            notificationBody =
                resolutionMessage != null && resolutionMessage.isNotEmpty
                    ? 'Your report has been resolved. Resolution: $resolutionMessage'
                    : 'Your report has been resolved. Thank you for reporting.';
            break;
          case 'closed':
            notificationBody = 'Your report has been closed.';
            break;
          case 'rejected':
            notificationBody = 'Your report has been reviewed and rejected.';
            break;
          default:
            notificationBody =
                'Your report status has been updated to: $newStatus';
        }

        // Create notification in Firestore
        await _firestore.collection('notifications').add({
          'userId': reportData['userId'],
          'title': notificationTitle,
          'body': notificationBody,
          'type': 'report_status_update',
          'reportId': reportId,
          'timestamp': FieldValue.serverTimestamp(),
          'isRead': false,
          'data': {
            'status': newStatus,
            'reportId': reportId,
            'updatedBy': widget.admin.uid,
            if (resolutionMessage != null && resolutionMessage.isNotEmpty)
              'resolutionMessage': resolutionMessage,
          },
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report status updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _logProcessEvent({
    required String reportId,
    required String action,
    required String stage,
    Map<String, dynamic>? meta,
  }) async {
    await _firestore
        .collection('reports')
        .doc(reportId)
        .collection('process_logs')
        .add({
          'action': action,
          'stage': stage,
          'actorId': widget.admin.uid,
          'actorEmail': widget.admin.email,
          'actorRole': _currentRoleKey,
          'timestamp': FieldValue.serverTimestamp(),
          'meta': meta ?? <String, dynamic>{},
        });
  }

  Future<List<Map<String, dynamic>>> _fetchAssignableAdmins() async {
    final query = await _firestore
        .collection('admins')
        .where('isActive', isEqualTo: true)
        .get();

    return query.docs
        .map((d) => <String, dynamic>{
              'uid': d.id,
              'email': (d.data()['email'] ?? '') as String,
              'name': (d.data()['fullName'] ?? d.data()['name'] ?? 'Unnamed')
                  as String,
              'role': (d.data()['shcRole'] ?? d.data()['role'] ?? 'moderator')
                  as String,
            })
        .where((a) {
          final role = _normalizeRoleKey(a['role'] as String?);
          return {
            'superAdmin',
            'chairperson',
            'committeeMember',
            'adHocMember',
            'reviewer',
          }.contains(role);
        })
        .where((a) => (a['uid'] as String).isNotEmpty)
        .toList();
  }

  Future<void> _showAssignReportDialog(
    String reportId,
    Map<String, dynamic> reportData,
  ) async {
    if (!_canAssignReportsByRole()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You do not have permission to assign reports.')),
        );
      }
      return;
    }

    final admins = await _fetchAssignableAdmins();
    if (!mounted) return;

    String? selectedUid = reportData['assignedToUid'] as String?;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Assign Report'),
          content: SizedBox(
            width: 420,
            child: admins.isEmpty
                ? const Text('No active admins available for assignment.')
                : DropdownButtonFormField<String>(
                    value: selectedUid,
                    decoration: const InputDecoration(
                      labelText: 'Assign to',
                      border: OutlineInputBorder(),
                    ),
                    items: admins
                        .map(
                          (a) => DropdownMenuItem<String>(
                            value: a['uid'] as String,
                            child: Text('${a['name']} (${a['email']})'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setS(() => selectedUid = v),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedUid == null
                  ? null
                  : () async {
                      final selected = admins.firstWhere(
                        (a) => a['uid'] == selectedUid,
                        orElse: () => <String, dynamic>{},
                      );
                      if (selected.isEmpty) return;

                      await _firestore.collection('reports').doc(reportId).update({
                        'assignedToUid': selected['uid'],
                        'assignedToEmail': selected['email'],
                        'assignedToName': selected['name'],
                        'assignedToRole': selected['role'],
                        'assignedAt': FieldValue.serverTimestamp(),
                        'assignedBy': widget.admin.uid,
                        'updatedAt': FieldValue.serverTimestamp(),
                        'updatedBy': widget.admin.uid,
                      });

                      await _logProcessEvent(
                        reportId: reportId,
                        action: 'assigned',
                        stage: (reportData['status'] ?? 'submitted') as String,
                        meta: {
                          'assignedToUid': selected['uid'],
                          'assignedToEmail': selected['email'],
                          'assignedToRole': selected['role'],
                        },
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Report assignment updated.')),
                        );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                    },
              child: const Text('Save Assignment'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResolutionDialog(String reportId) async {
    final resolutionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.green,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text('Resolve Report'),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.6,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Provide a resolution summary for the reporter. This message will be visible to the person who submitted the report.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: resolutionController,
                      maxLines: 5,
                      maxLength: 1000,
                      decoration: InputDecoration(
                        hintText:
                            'e.g., The incident has been investigated and appropriate disciplinary action has been taken...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        labelText: 'Resolution Message',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please provide a resolution message';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(context, resolutionController.text.trim());
                  }
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Resolve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
    );

    resolutionController.dispose();

    if (result != null) {
      await _updateReportStatus(
        reportId,
        'resolved',
        resolutionMessage: result,
      );
    }
  }

  Future<Map<String, dynamic>?> _fetchReporterData(
    Map<String, dynamic> reportData,
  ) async {
    if (reportData['isAnonymous'] == true || reportData['userId'] == null) {
      return null;
    }

    try {
      final userDoc =
          await _firestore.collection('users').doc(reportData['userId']).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
    } catch (e) {
      print('Error fetching user data: $e');
    }
    return null;
  }

  void _showReportDetails(DocumentSnapshot reportDoc) {
    final data = reportDoc.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder:
          (context) => FutureBuilder<Map<String, dynamic>?>(
            future: _fetchReporterData(data),
            builder: (context, userSnapshot) {
              final userData = userSnapshot.data;
              final status = data['status'] ?? 'submitted';
              final statusColor = _statusColors[status] ?? Colors.grey;

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.9,
                  constraints: const BoxConstraints(
                    maxWidth: 1000,
                    maxHeight: 900,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.assignment,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Report Details',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ID: ${reportDoc.id.substring(0, 8)}...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.8),
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _statusLabels[status] ?? status,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            IconButton(
                              icon: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Two column layout for wider screens
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isWide = constraints.maxWidth > 600;

                                  if (isWide) {
                                    return Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Left column
                                        Expanded(
                                          child: Column(
                                            children: [
                                              _buildDetailCard(
                                                'Report Information',
                                                Icons.info_outline,
                                                AppColors.primaryGreen,
                                                [
                                                  _buildDetailRow(
                                                    'Report ID',
                                                    reportDoc.id,
                                                  ),
                                                  _buildDetailRow(
                                                    'Category',
                                                    _getReportCategory(data),
                                                  ),
                                                  _buildDetailRow(
                                                    'Submitted',
                                                    data['createdAt'] != null
                                                        ? DateFormat(
                                                          'MMM dd, yyyy hh:mm a',
                                                        ).format(
                                                          (data['createdAt']
                                                                  as Timestamp)
                                                              .toDate(),
                                                        )
                                                        : 'N/A',
                                                  ),
                                                  _buildDetailRow(
                                                    'Anonymous',
                                                    (data['isAnonymous'] ==
                                                            true)
                                                        ? 'Yes'
                                                        : 'No',
                                                  ),
                                                  if (data['isAnonymous'] ==
                                                          true &&
                                                      data['trackingToken'] !=
                                                          null)
                                                    _buildTokenRow(
                                                      data['trackingToken'],
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              if (data['isAnonymous'] != true)
                                                _buildDetailCard(
                                                  'Reporter Information',
                                                  Icons.person_outline,
                                                  AppColors.secondaryOrange,
                                                  [
                                                    _buildDetailRow(
                                                      'Full Name',
                                                      userData?['fullName'] ??
                                                          data['reporterName'] ??
                                                          'N/A',
                                                    ),
                                                    _buildDetailRow(
                                                      'Email',
                                                      userData?['email'] ??
                                                          data['reporterEmail'] ??
                                                          'N/A',
                                                    ),
                                                    _buildDetailRow(
                                                      'Phone',
                                                      userData?['phoneNumber'] ??
                                                          data['reporterPhone'] ??
                                                          'N/A',
                                                    ),
                                                    if ((userData?['role'] ?? '')
                                                        .toString()
                                                        .isNotEmpty)
                                                      _buildDetailRow(
                                                        'Role',
                                                        UserRoleUtils
                                                            .displayRoleFromData(
                                                          userData,
                                                          fallback: 'N/A',
                                                        ),
                                                      ),
                                                    if (userData?['department'] !=
                                                        null)
                                                      _buildDetailRow(
                                                        'Faculty',
                                                        userData?['department'] ??
                                                            'N/A',
                                                      ),
                                                    if (userData?['facultyDepartment'] !=
                                                        null)
                                                      _buildDetailRow(
                                                        'Department',
                                                        userData?['facultyDepartment'] ??
                                                            'N/A',
                                                      ),
                                                  ],
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        // Right column
                                        Expanded(
                                          child: Column(
                                            children: [
                                              _buildDetailCard(
                                                'Incident Details',
                                                Icons.event_note_outlined,
                                                Colors.orange,
                                                [
                                                  _buildDetailRow(
                                                    'Location',
                                                    data['location'] ?? 'N/A',
                                                  ),
                                                  _buildDetailRow(
                                                    'Date',
                                                    data['incidentDate'] != null
                                                        ? DateFormat(
                                                          'MMM dd, yyyy',
                                                        ).format(
                                                          (data['incidentDate']
                                                                  as Timestamp)
                                                              .toDate(),
                                                        )
                                                        : (data['incidentDateString'] ??
                                                            data['date'] ??
                                                            'N/A'),
                                                  ),
                                                  _buildDetailRow(
                                                    'Time',
                                                    data['incidentTime'] ??
                                                        data['time'] ??
                                                        'N/A',
                                                  ),
                                                  if (data['perpetratorInfo'] !=
                                                          null &&
                                                      data['perpetratorInfo']
                                                          .toString()
                                                          .isNotEmpty)
                                                    _buildDetailRow(
                                                      'Person(s) Involved',
                                                      data['perpetratorInfo'],
                                                    ),
                                                  if (data['witnessName'] !=
                                                          null &&
                                                      data['witnessName']
                                                          .toString()
                                                          .isNotEmpty)
                                                    _buildDetailRow(
                                                      'Witness',
                                                      data['witnessName'],
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  // Single column for narrow screens
                                  return Column(
                                    children: [
                                      _buildDetailCard(
                                        'Report Information',
                                        Icons.info_outline,
                                        AppColors.primaryGreen,
                                        [
                                          _buildDetailRow(
                                            'Report ID',
                                            reportDoc.id,
                                          ),
                                          _buildDetailRow(
                                            'Category',
                                            _getReportCategory(data),
                                          ),
                                          _buildDetailRow(
                                            'Submitted',
                                            data['createdAt'] != null
                                                ? DateFormat(
                                                  'MMM dd, yyyy hh:mm a',
                                                ).format(
                                                  (data['createdAt']
                                                          as Timestamp)
                                                      .toDate(),
                                                )
                                                : 'N/A',
                                          ),
                                          _buildDetailRow(
                                            'Anonymous',
                                            (data['isAnonymous'] == true)
                                                ? 'Yes'
                                                : 'No',
                                          ),
                                          if (data['isAnonymous'] == true &&
                                              data['trackingToken'] != null)
                                            _buildTokenRow(
                                              data['trackingToken'],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      if (data['isAnonymous'] != true) ...[
                                        _buildDetailCard(
                                          'Reporter Information',
                                          Icons.person_outline,
                                          AppColors.secondaryOrange,
                                          [
                                            _buildDetailRow(
                                              'Full Name',
                                              userData?['fullName'] ??
                                                  data['reporterName'] ??
                                                  'N/A',
                                            ),
                                            _buildDetailRow(
                                              'Email',
                                              userData?['email'] ??
                                                  data['reporterEmail'] ??
                                                  'N/A',
                                            ),
                                            _buildDetailRow(
                                              'Phone',
                                              userData?['phoneNumber'] ??
                                                  data['reporterPhone'] ??
                                                  'N/A',
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                      ],
                                      _buildDetailCard(
                                        'Incident Details',
                                        Icons.event_note_outlined,
                                        Colors.orange,
                                        [
                                          _buildDetailRow(
                                            'Location',
                                            data['location'] ?? 'N/A',
                                          ),
                                          _buildDetailRow(
                                            'Date',
                                            data['incidentDate'] != null
                                                ? DateFormat(
                                                  'MMM dd, yyyy',
                                                ).format(
                                                  (data['incidentDate']
                                                          as Timestamp)
                                                      .toDate(),
                                                )
                                                : (data['incidentDateString'] ??
                                                    data['date'] ??
                                                    'N/A'),
                                          ),
                                          _buildDetailRow(
                                            'Time',
                                            data['incidentTime'] ??
                                                data['time'] ??
                                                'N/A',
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                },
                              ),

                              const SizedBox(height: 20),

                              // Complainant Response
                              if (data['complainantResponse'] != null &&
                                  data['complainantResponse']
                                      .toString()
                                      .isNotEmpty)
                                _buildDetailCard(
                                  'Complainant Response',
                                  Icons.question_answer_outlined,
                                  Colors.blue,
                                  [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.blue[50],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        data['complainantResponse'],
                                        style: const TextStyle(
                                          fontSize: 14,
                                          height: 1.6,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              if (data['complainantResponse'] != null &&
                                  data['complainantResponse']
                                      .toString()
                                      .isNotEmpty)
                                const SizedBox(height: 16),

                              // Description
                              _buildDetailCard(
                                'Incident Description',
                                Icons.description_outlined,
                                AppColors.primaryDark,
                                [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[50],
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      data['description'] ??
                                          'No description provided',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Evidence section
                              Builder(
                                builder: (context) {
                                  final imageUrls = _getListFromData(
                                    data,
                                    'imageUrls',
                                  );
                                  final videoUrls = _getListFromData(
                                    data,
                                    'videoUrls',
                                  );
                                  final audioUrls = _getListFromData(
                                    data,
                                    'audioUrls',
                                  );
                                  final hasEvidence =
                                      imageUrls.isNotEmpty ||
                                      videoUrls.isNotEmpty ||
                                      audioUrls.isNotEmpty;

                                  print('ADMIN DEBUG: imageUrls=$imageUrls');
                                  print('ADMIN DEBUG: videoUrls=$videoUrls');
                                  print('ADMIN DEBUG: audioUrls=$audioUrls');
                                  print(
                                    'ADMIN DEBUG: hasEvidence=$hasEvidence',
                                  );

                                  if (!hasEvidence) {
                                    return _buildDetailCard(
                                      'Evidence',
                                      Icons.folder_outlined,
                                      Colors.grey,
                                      [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.folder_off,
                                                color: Colors.grey[400],
                                                size: 24,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                'No evidence files submitted',
                                                style: TextStyle(
                                                  color: Colors.grey[500],
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (imageUrls.isNotEmpty) ...[
                                        _buildDetailCard(
                                          'Photo Evidence (${imageUrls.length})',
                                          Icons.photo_library_outlined,
                                          Colors.teal,
                                          [
                                            SizedBox(
                                              height: 200,
                                              child: ListView.builder(
                                                scrollDirection:
                                                    Axis.horizontal,
                                                itemCount: imageUrls.length,
                                                itemBuilder: (
                                                  context,
                                                  imgIndex,
                                                ) {
                                                  final url =
                                                      imageUrls[imgIndex];
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                          right: 12,
                                                        ),
                                                    child: GestureDetector(
                                                      onTap:
                                                          () => _showFullImage(
                                                            context,
                                                            url,
                                                            imgIndex + 1,
                                                          ),
                                                      child: ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        child: Stack(
                                                          children: [
                                                            Image.network(
                                                              url,
                                                              width: 180,
                                                              height: 200,
                                                              fit: BoxFit.cover,
                                                              loadingBuilder: (
                                                                context,
                                                                child,
                                                                progress,
                                                              ) {
                                                                if (progress ==
                                                                    null)
                                                                  return child;
                                                                return Container(
                                                                  width: 180,
                                                                  height: 200,
                                                                  color:
                                                                      Colors
                                                                          .grey[100],
                                                                  child: Center(
                                                                    child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                      color:
                                                                          AppColors
                                                                              .secondaryOrange,
                                                                    ),
                                                                  ),
                                                                );
                                                              },
                                                              errorBuilder:
                                                                  (
                                                                    context,
                                                                    error,
                                                                    stack,
                                                                  ) => Container(
                                                                    width: 180,
                                                                    height: 200,
                                                                    color:
                                                                        Colors
                                                                            .grey[200],
                                                                    child: Column(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        Icon(
                                                                          Icons
                                                                              .broken_image,
                                                                          color:
                                                                              Colors.grey[400],
                                                                          size:
                                                                              36,
                                                                        ),
                                                                        const SizedBox(
                                                                          height:
                                                                              4,
                                                                        ),
                                                                        Text(
                                                                          'Load failed',
                                                                          style: TextStyle(
                                                                            fontSize:
                                                                                11,
                                                                            color:
                                                                                Colors.grey[500],
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                            ),
                                                            Positioned(
                                                              bottom: 0,
                                                              left: 0,
                                                              right: 0,
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      vertical:
                                                                          6,
                                                                    ),
                                                                decoration: const BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    begin:
                                                                        Alignment
                                                                            .bottomCenter,
                                                                    end:
                                                                        Alignment
                                                                            .topCenter,
                                                                    colors: [
                                                                      Colors
                                                                          .black54,
                                                                      Colors
                                                                          .transparent,
                                                                    ],
                                                                  ),
                                                                ),
                                                                child: Row(
                                                                  mainAxisAlignment:
                                                                      MainAxisAlignment
                                                                          .center,
                                                                  children: [
                                                                    Icon(
                                                                      Icons
                                                                          .zoom_in,
                                                                      size: 14,
                                                                      color:
                                                                          Colors
                                                                              .white70,
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 4,
                                                                    ),
                                                                    Text(
                                                                      'Tap to view',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            10,
                                                                        color:
                                                                            Colors.white70,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                      ],

                                      if (videoUrls.isNotEmpty) ...[
                                        _buildDetailCard(
                                          'Video Evidence (${videoUrls.length})',
                                          Icons.videocam_outlined,
                                          Colors.purple,
                                          [
                                            ...videoUrls.asMap().entries.map((
                                              entry,
                                            ) {
                                              final videoUrl = entry.value;
                                              final videoNum = entry.key + 1;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: InkWell(
                                                  onTap: () async {
                                                    final uri = Uri.parse(
                                                      videoUrl,
                                                    );
                                                    if (await canLaunchUrl(
                                                      uri,
                                                    )) {
                                                      await launchUrl(
                                                        uri,
                                                        mode:
                                                            LaunchMode
                                                                .externalApplication,
                                                      );
                                                    }
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          14,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.purple[50],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                10,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color:
                                                                Colors
                                                                    .purple[100],
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: Icon(
                                                            Icons.videocam,
                                                            color:
                                                                Colors
                                                                    .purple[700],
                                                            size: 22,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 14,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Video $videoNum',
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              Text(
                                                                'Tap to open in browser',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      Colors
                                                                          .grey[500],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.open_in_new,
                                                          color:
                                                              Colors
                                                                  .purple[400],
                                                          size: 20,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                      ],

                                      // Audio Evidence
                                      if (audioUrls.isNotEmpty) ...[
                                        _buildDetailCard(
                                          'Audio Evidence (${audioUrls.length})',
                                          Icons.headphones_rounded,
                                          Colors.deepPurple,
                                          [
                                            ...audioUrls.asMap().entries.map((
                                              entry,
                                            ) {
                                              final audioUrl = entry.value;
                                              final audioNum = entry.key + 1;
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 8,
                                                ),
                                                child: InkWell(
                                                  onTap: () async {
                                                    final uri = Uri.parse(
                                                      audioUrl,
                                                    );
                                                    if (await canLaunchUrl(
                                                      uri,
                                                    )) {
                                                      await launchUrl(
                                                        uri,
                                                        mode:
                                                            LaunchMode
                                                                .externalApplication,
                                                      );
                                                    }
                                                  },
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.deepPurple
                                                          .withOpacity(0.05),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: Colors.deepPurple
                                                            .withOpacity(0.2),
                                                      ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Container(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors
                                                                .deepPurple
                                                                .withOpacity(
                                                                  0.1,
                                                                ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                          ),
                                                          child: const Icon(
                                                            Icons
                                                                .headphones_rounded,
                                                            color:
                                                                Colors
                                                                    .deepPurple,
                                                            size: 22,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 12,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                'Audio $audioNum',
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                height: 2,
                                                              ),
                                                              Text(
                                                                'Tap to listen in browser',
                                                                style: TextStyle(
                                                                  fontSize: 12,
                                                                  color:
                                                                      Colors
                                                                          .grey[500],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.open_in_new,
                                                          color: Colors
                                                              .deepPurple
                                                              .withOpacity(0.6),
                                                          size: 20,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                      ],
                                    ],
                                  );
                                },
                              ),

                              // AI Insights Panel
                              if (_canManageReportsByRole()) ...[
                                const SizedBox(height: 16),
                                AIInsightsPanel(
                                  reportData: data,
                                  reportId: reportDoc.id,
                                  currentStatus: data['status'] ?? 'submitted',
                                ),
                              ],

                              // Retraction Info (if retracted)
                              if (data['status'] == 'retracted') ...[
                                const SizedBox(height: 16),
                                _buildDetailCard(
                                  'Report Retraction',
                                  Icons.undo_rounded,
                                  Colors.deepOrange,
                                  [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.deepOrange.withOpacity(0.07),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['retractionReason'] ?? 'No reason provided',
                                            style: const TextStyle(fontSize: 14, height: 1.6),
                                          ),
                                          const SizedBox(height: 10),
                                          if (data['retractedAt'] != null)
                                            Text(
                                              'Retracted on ${DateFormat('MMM dd, yyyy hh:mm a').format((data['retractedAt'] as Timestamp).toDate())}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          if (data['retractedBy'] != null)
                                            Text(
                                              'Retracted by: ${data['retractedBy']}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Resolution Message
                              if (data['resolutionMessage'] != null &&
                                  (data['resolutionMessage'] as String)
                                      .isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildDetailCard(
                                  'Resolution',
                                  Icons.task_alt,
                                  Colors.green,
                                  [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50],
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            data['resolutionMessage'],
                                            style: const TextStyle(
                                              fontSize: 14,
                                              height: 1.6,
                                            ),
                                          ),
                                          if (data['resolvedAt'] != null) ...[
                                            const SizedBox(height: 10),
                                            Text(
                                              'Resolved on ${DateFormat('MMM dd, yyyy hh:mm a').format((data['resolvedAt'] as Timestamp).toDate())}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              // Status Update Section
                              if (_canManageReportsByRole()) ...[
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryGreen
                                                  .withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              Icons.edit_note,
                                              color: AppColors.primaryGreen,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          const Text(
                                            'Update Status',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      Wrap(
                                        spacing: 10,
                                        runSpacing: 10,
                                        children:
                                            _statusLabels.entries.where((e) => e.key != 'all').map((
                                              entry,
                                            ) {
                                              final isCurrentStatus =
                                                  data['status'] == entry.key;
                                              final canTransition =
                                                  _canTransitionStatus(
                                                    (data['status'] as String?) ??
                                                        'submitted',
                                                    entry.key,
                                                  );
                                              return ElevatedButton(
                                                onPressed:
                                                    (isCurrentStatus || !canTransition)
                                                        ? null
                                                        : () {
                                                          if (entry.key ==
                                                              'resolved') {
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                            _showResolutionDialog(
                                                              reportDoc.id,
                                                            );
                                                          } else {
                                                            _updateReportStatus(
                                                              reportDoc.id,
                                                              entry.key,
                                                            );
                                                            Navigator.pop(
                                                              context,
                                                            );
                                                          }
                                                        },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      _statusColors[entry.key],
                                                  foregroundColor: Colors.white,
                                                  disabledBackgroundColor:
                                                      Colors.grey[300],
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 20,
                                                        vertical: 12,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  entry.value,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 16),
                              _buildDetailCard(
                                'Assignment',
                                Icons.assignment_ind,
                                AppColors.secondaryOrange,
                                [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.orange[50],
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (data['assignedToName'] as String?)
                                                      ?.isNotEmpty ==
                                                  true
                                              ? data['assignedToName'] as String
                                              : 'Unassigned',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          (data['assignedToEmail'] as String?) ??
                                              'No assignee email',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Role: ${(data['assignedToRole'] as String?) ?? 'N/A'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        if (data['assignedAt'] != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            'Assigned on ${DateFormat('MMM dd, yyyy hh:mm a').format((data['assignedAt'] as Timestamp).toDate())}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                        if (_canAssignReportsByRole()) ...[
                                          const SizedBox(height: 12),
                                          OutlinedButton.icon(
                                            icon: const Icon(Icons.group_add),
                                            label: Text(
                                              data['assignedToUid'] != null
                                                  ? 'Reassign'
                                                  : 'Assign',
                                            ),
                                            onPressed: () => _showAssignReportDialog(
                                              reportDoc.id,
                                              data,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),
                              _buildDetailCard(
                                'Process Timeline',
                                Icons.timeline,
                                AppColors.primaryDark,
                                [
                                  StreamBuilder<QuerySnapshot>(
                                    stream: _firestore
                                        .collection('reports')
                                        .doc(reportDoc.id)
                                        .collection('process_logs')
                                        .orderBy('timestamp', descending: true)
                                        .limit(10)
                                        .snapshots(),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState ==
                                          ConnectionState.waiting) {
                                        return const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        );
                                      }

                                      if (!snapshot.hasData ||
                                          snapshot.data!.docs.isEmpty) {
                                        return Text(
                                          'No process history yet. Status updates and assignments will appear here.',
                                          style: TextStyle(
                                            color: Colors.grey[700],
                                            fontSize: 13,
                                          ),
                                        );
                                      }

                                      return Column(
                                        children: snapshot.data!.docs.map((doc) {
                                          final event =
                                              doc.data() as Map<String, dynamic>;
                                          final ts = event['timestamp'] as Timestamp?;
                                          final actorEmail =
                                              (event['actorEmail'] as String?) ??
                                                  'Unknown actor';
                                          final actorRole =
                                              (event['actorRole'] as String?) ??
                                                  'unknown';
                                          final action =
                                              (event['action'] as String?) ??
                                                  'updated';
                                          final stage =
                                              (event['stage'] as String?) ??
                                                  'unknown';

                                          return ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: const Icon(
                                              Icons.fiber_manual_record,
                                              size: 12,
                                              color: AppColors.primaryGreen,
                                            ),
                                            title: Text(
                                              '${_toTitle(action)} • ${_toTitle(stage)}',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            subtitle: Text(
                                              '$actorEmail (${actorRole.replaceAll('_', ' ')})'
                                              '${ts != null ? ' • ${DateFormat('MMM dd, yyyy hh:mm a').format(ts.toDate())}' : ''}',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildDetailCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenRow(String token) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              'Tracking Token',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.secondaryOrange.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.vpn_key,
                    size: 16,
                    color: AppColors.secondaryOrange,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: SelectableText(
                      token,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Safely extracts a List<String> from Firestore document data,
  /// handling null, wrong types, and dynamic lists.
  List<String> _getListFromData(Map<String, dynamic> data, String key) {
    final raw = data[key];
    if (raw == null) return [];
    if (raw is List) {
      return raw.whereType<String>().where((s) => s.isNotEmpty).toList();
    }
    return [];
  }

  void _showFullImage(BuildContext context, String url, int imageNum) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Image
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: Image.network(
                      url,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value:
                                progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                            color: AppColors.secondaryOrange,
                          ),
                        );
                      },
                      errorBuilder:
                          (context, error, stack) => Container(
                            padding: const EdgeInsets.all(40),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                    ),
                  ),
                ),
                // Top bar
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black54, Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Image $imageNum',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.open_in_new,
                            color: Colors.white,
                            size: 22,
                          ),
                          tooltip: 'Open in browser',
                          onPressed: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 24,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      builder:
          (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primaryGreen,
                onPrimary: Colors.white,
                secondary: AppColors.secondaryOrange,
              ),
            ),
            child: child!,
          ),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  void _clearFilters() {
    setState(() {
      _selectedStatus = 'all';
      _selectedFaculty = 'all';
      _selectedDepartment = 'all';
      _selectedRole = 'all';
      _selectedStudyLevel = 'all';
      _anonymousOnly = false;
      _dateRange = null;
      _searchController.clear();
      _searchQuery = '';
    });
  }

  Future<void> _showTrendAnalysis() async {
    final aiService = FirebaseAIReportService.instance;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) =>
              _TrendAnalysisDialog(aiService: aiService, firestore: _firestore),
    );
  }

  bool get _hasActiveFilters =>
      _selectedStatus != 'all' ||
      _selectedFaculty != 'all' ||
      _selectedDepartment != 'all' ||
      _selectedRole != 'all' ||
      _selectedStudyLevel != 'all' ||
      _anonymousOnly ||
      _dateRange != null ||
      _searchQuery.isNotEmpty;

  Widget _buildBody() {
    return Column(
      children: [
        // Filters Panel
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.background,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText:
                      'Search by ID, type, location, or tracking token...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged:
                    (value) =>
                        setState(() => _searchQuery = value.toLowerCase()),
              ),
              const SizedBox(height: 12),

              // Filter row 1 - Status, Faculty, Department
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Status dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            _selectedStatus != 'all'
                                ? AppColors.secondaryOrange.withOpacity(0.1)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              _selectedStatus != 'all'
                                  ? AppColors.secondaryOrange
                                  : Colors.grey[300]!,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                _selectedStatus != 'all'
                                    ? AppColors.primaryGreen
                                    : Colors.grey[700],
                            fontWeight:
                                _selectedStatus != 'all'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                          items:
                              _statusLabels.entries
                                  .map(
                                    (e) => DropdownMenuItem(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (val) => setState(
                                () => _selectedStatus = val ?? 'all',
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Faculty dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            _selectedFaculty != 'all'
                                ? AppColors.secondaryOrange.withOpacity(0.1)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              _selectedFaculty != 'all'
                                  ? AppColors.secondaryOrange
                                  : Colors.grey[300]!,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedFaculty,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                _selectedFaculty != 'all'
                                    ? AppColors.primaryGreen
                                    : Colors.grey[700],
                            fontWeight:
                                _selectedFaculty != 'all'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Faculties'),
                            ),
                            ..._faculties.map(
                              (f) => DropdownMenuItem(
                                value: f,
                                child: Text(f.replaceAll('Faculty of ', 'F. ')),
                              ),
                            ),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedFaculty = val ?? 'all';
                              _selectedDepartment =
                                  'all'; // Reset department when faculty changes
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Department dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            _selectedDepartment != 'all'
                                ? AppColors.secondaryOrange.withOpacity(0.1)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              _selectedDepartment != 'all'
                                  ? AppColors.secondaryOrange
                                  : Colors.grey[300]!,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedDepartment,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                _selectedDepartment != 'all'
                                    ? AppColors.primaryGreen
                                    : Colors.grey[700],
                            fontWeight:
                                _selectedDepartment != 'all'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Departments'),
                            ),
                            ..._availableDepartments.map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text(
                                  d.length > 20
                                      ? '${d.substring(0, 18)}...'
                                      : d,
                                ),
                              ),
                            ),
                          ],
                          onChanged:
                              (val) => setState(
                                () => _selectedDepartment = val ?? 'all',
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Role dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            _selectedRole != 'all'
                                ? AppColors.secondaryOrange.withOpacity(0.1)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              _selectedRole != 'all'
                                  ? AppColors.secondaryOrange
                                  : Colors.grey[300]!,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedRole,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                _selectedRole != 'all'
                                    ? AppColors.primaryGreen
                                    : Colors.grey[700],
                            fontWeight:
                                _selectedRole != 'all'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Roles'),
                            ),
                            ..._roles.map(
                              (r) => DropdownMenuItem(value: r, child: Text(r)),
                            ),
                          ],
                          onChanged:
                              (val) =>
                                  setState(() => _selectedRole = val ?? 'all'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Study Level dropdown (only show when Student is selected or all)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color:
                            _selectedStudyLevel != 'all'
                                ? AppColors.secondaryOrange.withOpacity(0.1)
                                : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              _selectedStudyLevel != 'all'
                                  ? AppColors.secondaryOrange
                                  : Colors.grey[300]!,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStudyLevel,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(
                            fontSize: 13,
                            color:
                                _selectedStudyLevel != 'all'
                                    ? AppColors.primaryGreen
                                    : Colors.grey[700],
                            fontWeight:
                                _selectedStudyLevel != 'all'
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'all',
                              child: Text('All Study Levels'),
                            ),
                            ..._studyLevels.map(
                              (l) => DropdownMenuItem(value: l, child: Text(l)),
                            ),
                          ],
                          onChanged:
                              (val) => setState(
                                () => _selectedStudyLevel = val ?? 'all',
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Filter row 2 - Date, Anonymous, AI, Clear
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Date range
                    InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _dateRange != null
                                  ? AppColors.secondaryOrange.withOpacity(0.1)
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                _dateRange != null
                                    ? AppColors.secondaryOrange
                                    : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 16,
                              color:
                                  _dateRange != null
                                      ? AppColors.primaryGreen
                                      : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _dateRange != null
                                  ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
                                  : 'Date Range',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    _dateRange != null
                                        ? AppColors.primaryGreen
                                        : Colors.grey[600],
                                fontWeight:
                                    _dateRange != null
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Anonymous toggle
                    InkWell(
                      onTap:
                          () =>
                              setState(() => _anonymousOnly = !_anonymousOnly),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              _anonymousOnly
                                  ? AppColors.secondaryOrange.withOpacity(0.1)
                                  : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color:
                                _anonymousOnly
                                    ? AppColors.secondaryOrange
                                    : Colors.grey[300]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.visibility_off,
                              size: 16,
                              color:
                                  _anonymousOnly
                                      ? AppColors.primaryGreen
                                      : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Anonymous',
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    _anonymousOnly
                                        ? AppColors.primaryGreen
                                        : Colors.grey[600],
                                fontWeight:
                                    _anonymousOnly
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // AI Trend Analysis
                    InkWell(
                      onTap: () => _showTrendAnalysis(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primaryGreen.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'AI Trends',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Clear all
                    if (_hasActiveFilters)
                      InkWell(
                        onTap: _clearFilters,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.clear_all,
                                size: 16,
                                color: Colors.red[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Clear All',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Reports List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream:
                _firestore
                    .collection('reports')
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError)
                return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                );
              }

              final reports =
                  snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    // Status filter
                    if (_selectedStatus != 'all' &&
                        data['status'] != _selectedStatus)
                      return false;

                    // Anonymous filter
                    if (_anonymousOnly && data['isAnonymous'] != true)
                      return false;

                    // Date range filter
                    if (_dateRange != null && data['createdAt'] != null) {
                      final createdAt =
                          (data['createdAt'] as Timestamp).toDate();
                      if (createdAt.isBefore(_dateRange!.start) ||
                          createdAt.isAfter(
                            _dateRange!.end.add(const Duration(days: 1)),
                          ))
                        return false;
                    }

                    // User-based filters (faculty, department, role, study level)
                    if (_selectedFaculty != 'all' ||
                        _selectedDepartment != 'all' ||
                        _selectedRole != 'all' ||
                        _selectedStudyLevel != 'all') {
                      final userId = data['userId'] as String?;
                      if (userId == null) {
                        // Anonymous reports without userId - can't filter by user attributes
                        if (_selectedFaculty != 'all' ||
                            _selectedDepartment != 'all' ||
                            _selectedRole != 'all' ||
                            _selectedStudyLevel != 'all') {
                          return false;
                        }
                      } else if (_usersCacheLoaded) {
                        final userData = _usersCache[userId];
                        if (userData == null) return false;

                        // Faculty filter
                        if (_selectedFaculty != 'all') {
                          final userFaculty = userData['department'] ?? '';
                          if (userFaculty != _selectedFaculty) return false;
                        }

                        // Department filter
                        if (_selectedDepartment != 'all') {
                          final userDept = userData['facultyDepartment'] ?? '';
                          if (userDept != _selectedDepartment) return false;
                        }

                        // Role filter
                        if (!UserRoleUtils.matchesRoleFilter(
                          userData,
                          _selectedRole,
                        )) {
                          return false;
                        }

                        // Study level filter
                        if (_selectedStudyLevel != 'all') {
                          final userStudyLevel = userData['studyLevel'] ?? '';
                          if (userStudyLevel != _selectedStudyLevel)
                            return false;
                        }
                      }
                    }

                    // Search (includes tracking token search)
                    if (_searchQuery.isNotEmpty) {
                      final category =
                          _getReportCategory(data).toLowerCase();
                      final location = (data['location'] ?? '').toLowerCase();
                      final reportId = doc.id.toLowerCase();
                      final token = (data['trackingToken'] ?? '').toLowerCase();

                      if (!category.contains(_searchQuery) &&
                          !location.contains(_searchQuery) &&
                          !reportId.contains(_searchQuery) &&
                          !token.contains(_searchQuery)) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

              if (reports.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text(
                        'No reports found',
                        style: TextStyle(color: Colors.grey[500], fontSize: 16),
                      ),
                      if (_hasActiveFilters) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear_all),
                          label: const Text('Clear Filters'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final reportDoc = reports[index];
                  final data = reportDoc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'submitted';
                  final statusColor = _statusColors[status] ?? Colors.grey;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: statusColor.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.report, color: statusColor),
                      ),
                      title: Text(
                        _getReportCategory(data),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Location: ${data['location'] ?? 'N/A'}'),
                          const SizedBox(height: 2),
                          Text(
                            data['createdAt'] != null
                                ? DateFormat('MMM dd, yyyy').format(
                                  (data['createdAt'] as Timestamp).toDate(),
                                )
                                : 'N/A',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (data['isAnonymous'] == true &&
                              data['trackingToken'] != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.vpn_key,
                                  size: 12,
                                  color: AppColors.secondaryOrange,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    data['trackingToken'],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.secondaryOrange,
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withOpacity(0.5),
                              ),
                            ),
                            child: Text(
                              _statusLabels[status] ?? status,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (data['isAnonymous'] == true)
                            Text(
                              'Anonymous',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                      onTap: () => _showReportDetails(reportDoc),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildBody();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Reports Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }
}

/// Dialog that shows AI-powered trend analysis across all reports
class _TrendAnalysisDialog extends StatefulWidget {
  final FirebaseAIReportService aiService;
  final FirebaseFirestore firestore;

  const _TrendAnalysisDialog({
    required this.aiService,
    required this.firestore,
  });

  @override
  State<_TrendAnalysisDialog> createState() => _TrendAnalysisDialogState();
}

class _TrendAnalysisDialogState extends State<_TrendAnalysisDialog> {
  String? _trendResult;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrends();
  }

  Future<void> _loadTrends() async {
    try {
      // Fetch recent reports for analysis
      final snapshot =
          await widget.firestore
              .collection('reports')
              .orderBy('createdAt', descending: true)
              .limit(50)
              .get();

      final reportsData =
          snapshot.docs.map((doc) {
            final data = doc.data();
            // Convert Timestamp to string for AI context
            if (data['createdAt'] != null) {
              data['createdAt'] =
                  (data['createdAt'] as Timestamp).toDate().toString();
            }
            return data;
          }).toList();

      if (reportsData.isEmpty) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'No reports available for trend analysis.';
          });
        }
        return;
      }

      final result = await widget.aiService.analyzeTrends(reportsData);
      if (mounted) setState(() => _trendResult = result);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _printTrendAsPdf() async {
    final trendText = _normalizeForPdf(_trendResult ?? '');
    if (trendText.isEmpty) return;

    try {
      final pdf = pw.Document();
      final generatedAt = DateFormat(
        'yyyy-MM-dd HH:mm:ss',
      ).format(DateTime.now());
      final sections =
          trendText
              .split(RegExp(r'\n\s*\n'))
              .map((section) => section.trim())
              .where((section) => section.isNotEmpty)
              .toList();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build:
              (context) => [
                pw.Text(
                  'AI Trend Analysis Report',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('Generated: $generatedAt'),
                pw.SizedBox(height: 16),
                ...sections.map(
                  (section) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 10),
                    child: pw.Text(
                      section,
                      style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.4),
                    ),
                  ),
                ),
              ],
        ),
      );

      final pdfBytes = await pdf.save();
      final blob = html.Blob([Uint8List.fromList(pdfBytes)], 'application/pdf');
      final url = html.Url.createObjectUrlFromBlob(blob);

      html.window.open(url, '_blank');

      Future.delayed(const Duration(seconds: 10), () {
        html.Url.revokeObjectUrl(url);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'AI trends exported to PDF. Use print in the opened PDF tab.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _cleanMarkdownLine(String line) {
    return line
        .replaceAll(RegExp(r'\*\*\*'), '')
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'__'), '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'^\>\s*'), '')
        .replaceAllMapped(
          RegExp(r'\[(.*?)\]\((.*?)\)'),
          (match) => match.group(1) ?? '',
        )
        .trim();
  }

  String _normalizeForPdf(String text) {
    final lines = text.split('\n');
    final normalized =
        lines.map((rawLine) {
          final line = rawLine.trim();
          if (line.isEmpty) return '';

          final numbered = RegExp(r'^(\d+)[\)\.\:-]\s+').firstMatch(line);
          final bullet = RegExp(r'^[-*•]\s+').hasMatch(line);
          final heading = RegExp(r'^#{1,6}\s+').hasMatch(line);

          if (numbered != null) {
            final index = numbered.group(1) ?? '';
            return '$index. ${_cleanMarkdownLine(line.substring(numbered.end))}';
          }
          if (bullet) {
            return '- ${_cleanMarkdownLine(line.replaceFirst(RegExp(r'^[-*•]\s+'), ''))}';
          }
          if (heading) {
            return _cleanMarkdownLine(
              line.replaceFirst(RegExp(r'^#{1,6}\s+'), ''),
            );
          }
          return _cleanMarkdownLine(line);
        }).toList();

    return normalized.join('\n').trim();
  }

  Widget _buildFormattedTrendText(String text) {
    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }

      final isHeading = RegExp(r'^#{1,6}\s+').hasMatch(line);
      final numbered = RegExp(r'^(\d+)[\)\.\:-]\s+').firstMatch(line);
      final bullet = RegExp(r'^[-*•]\s+').hasMatch(line);

      if (isHeading) {
        final body = _cleanMarkdownLine(
          line.replaceFirst(RegExp(r'^#{1,6}\s+'), ''),
        );
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              body,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
        );
        continue;
      }

      if (numbered != null) {
        final index = numbered.group(1) ?? '';
        final body = _cleanMarkdownLine(line.substring(numbered.end));
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$index. ',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryGreen,
                  ),
                ),
                Expanded(
                  child: Text(
                    body,
                    style: const TextStyle(fontSize: 14, height: 1.55),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      if (bullet) {
        final body = _cleanMarkdownLine(
          line.replaceFirst(RegExp(r'^[-*•]\s+'), ''),
        );
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Icon(
                    Icons.circle,
                    size: 7,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    body,
                    style: const TextStyle(fontSize: 14, height: 1.55),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      final cleaned = _cleanMarkdownLine(line);
      final looksLikeSection = cleaned.endsWith(':') && cleaned.length <= 70;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            cleaned,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              fontWeight: looksLikeSection ? FontWeight.w700 : FontWeight.w400,
              color: looksLikeSection ? AppColors.primaryGreen : Colors.black87,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75,
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: AppColors.secondaryOrange,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Trend Analysis',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Cross-report pattern recognition',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child:
                  _loading
                      ? const Padding(
                        padding: EdgeInsets.all(40),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.primaryGreen,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Analyzing report trends...',
                              style: TextStyle(color: Colors.grey),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'This may take a moment',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                      : _error != null
                      ? Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 40,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Analysis failed',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _error!,
                              style: const TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _loading = true;
                                  _error = null;
                                  _trendResult = null;
                                });
                                _loadTrends();
                              },
                              icon: const Icon(Icons.refresh, size: 18),
                              label: const Text('Retry'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                      : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: _buildFormattedTrendText(_trendResult ?? ''),
                      ),
            ),

            // Footer
            if (_trendResult != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _trendResult!));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Trend analysis copied to clipboard'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _printTrendAsPdf,
                      icon: const Icon(Icons.print, size: 16),
                      label: const Text('Print (PDF)'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
