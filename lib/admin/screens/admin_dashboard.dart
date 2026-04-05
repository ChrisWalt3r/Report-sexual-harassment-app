import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../constants/app_colors.dart';
import '../../models/admin_user.dart';
import '../../services/admin_auth_service.dart';
import 'users_management_screen.dart';
import 'reports_management_screen.dart';
import 'admin_login_screen.dart';
import 'analytics_screen.dart';
import 'admin_management_screen.dart';
import 'data_export_screen.dart';
import 'contacts_management_screen.dart';
import 'policy_management_screen.dart';
import 'chatbot_management_screen.dart';
import 'profile_management_screen.dart';
import 'admin_settings_screen.dart';

// ─── Sidebar navigation item model ───
class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final int index;
  final bool superAdminOnly;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.index,
    this.superAdminOnly = false,
  });
}

// ──────────────────────────────────────
//  AdminDashboard – sidebar shell
// ──────────────────────────────────────
class AdminDashboard extends StatefulWidget {
  final AdminUser admin;
  const AdminDashboard({super.key, required this.admin});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _adminAuthService = AdminAuthService();
  int _selectedIndex = 0;
  bool _sidebarCollapsed = false;
  double _sidebarExpandedWidth = 180;

  static const double _sidebarCollapsedWidth = 60;
  static const double _sidebarMinWidth = 180;
  static const double _sidebarMaxWidth = 360;

  late final List<_NavItem> _navItems;

  @override
  void initState() {
    super.initState();
    _navItems = [
      const _NavItem(
        label: 'Dashboard',
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        index: 0,
      ),
      const _NavItem(
        label: 'Reports',
        icon: Icons.assignment_outlined,
        activeIcon: Icons.assignment,
        index: 1,
      ),
      const _NavItem(
        label: 'Users',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
        index: 2,
      ),
      const _NavItem(
        label: 'Analytics',
        icon: Icons.analytics_outlined,
        activeIcon: Icons.analytics,
        index: 3,
      ),
      const _NavItem(
        label: 'Contacts',
        icon: Icons.contact_phone_outlined,
        activeIcon: Icons.contact_phone,
        index: 4,
      ),
      const _NavItem(
        label: 'Knowledge Base',
        icon: Icons.policy_outlined,
        activeIcon: Icons.policy,
        index: 5,
      ),
      const _NavItem(
        label: 'Admins',
        icon: Icons.admin_panel_settings_outlined,
        activeIcon: Icons.admin_panel_settings,
        index: 6,
        superAdminOnly: true,
      ),
      const _NavItem(
        label: 'Export',
        icon: Icons.download_outlined,
        activeIcon: Icons.download,
        index: 7,
      ),
      const _NavItem(
        label: 'Profile',
        icon: Icons.account_circle_outlined,
        activeIcon: Icons.account_circle,
        index: 8,
      ),
      const _NavItem(
        label: 'Settings & Logs',
        icon: Icons.settings,
        activeIcon: Icons.settings,
        index: 9,
      ),
      const _NavItem(
        label: 'Chatbot Mgmt',
        icon: Icons.smart_toy_outlined,
        activeIcon: Icons.smart_toy,
        index: 10,
      ),
    ];
  }

  List<_NavItem> get _visibleNavItems {
    return _navItems.where((item) {
      if (item.superAdminOnly && widget.admin.role != AdminRole.superAdmin)
        return false;
      return true;
    }).toList();
  }

  Widget _buildCurrentPage() {
    switch (_selectedIndex) {
      case 0:
        return _DashboardOverview(admin: widget.admin);
      case 1:
        return ReportsManagementScreen(admin: widget.admin, embedded: true);
      case 2:
        return UsersManagementScreen(admin: widget.admin, embedded: true);
      case 3:
        return const AnalyticsScreen(embedded: true);
      case 4:
        return const ContactsManagementScreen();
      case 5:
        return const PolicyManagementScreen(embedded: true);
      case 6:
        return const AdminManagementScreen(embedded: true);
      case 7:
        return const DataExportScreen(embedded: true);
      case 8:
        return ProfileManagementScreen(admin: widget.admin, embedded: true);
      case 9:
        return AdminSettingsScreen(admin: widget.admin, embedded: true);
      case 10:
        return ChatbotManagementScreen(admin: widget.admin, embedded: true);
      default:
        return _DashboardOverview(admin: widget.admin);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.logout, color: AppColors.secondaryOrange),
                const SizedBox(width: 8),
                const Text('Sign Out'),
              ],
            ),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Sign Out'),
              ),
            ],
          ),
    );
    if (confirm == true && mounted) {
      await _adminAuthService.signOut();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Mobile drawer
      drawer: isWide ? null : _buildDrawer(),
      body: Row(
        children: [
          // Desktop sidebar
          if (isWide) _buildSidebar(),
          // Main content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isWide),
                Expanded(child: _buildCurrentPage()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ──
  Widget _buildTopBar(bool isWide) {
    final currentItem = _visibleNavItems.firstWhere(
      (i) => i.index == _selectedIndex,
      orElse: () => _visibleNavItems.first,
    );
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder:
                  (ctx) => IconButton(
                    icon: const Icon(Icons.menu, color: Color(0xFF2E8B57)),
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
            ),
          if (!isWide) const SizedBox(width: 8),
          Text(
            currentItem.label,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2E8B57),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.secondaryOrange,
                  child: const Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.admin.fullName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E8B57),
                      ),
                    ),
                    Text(
                      widget.admin.role.displayName,
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: Color(0xFF2E8B57)),
            onPressed: _handleSignOut,
            tooltip: 'Sign Out',
          ),
        ],
      ),
    );
  }

  // ── Desktop sidebar ──
  Widget _buildSidebar() {
    final sidebarWidth =
        _sidebarCollapsed
            ? _sidebarCollapsedWidth
            : _sidebarExpandedWidth.clamp(_sidebarMinWidth, _sidebarMaxWidth)
                .toDouble();

    return SizedBox(
      width: sidebarWidth + (_sidebarCollapsed ? 0 : 8),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: sidebarWidth,
            decoration: const BoxDecoration(color: AppColors.primaryGreen),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: sidebarWidth,
                    height: constraints.maxHeight,
                    child: Column(
                      children: [
                    // Header with SHA Icon
                    Container(
                      height: 64,
                      padding: EdgeInsets.symmetric(
                        horizontal: _sidebarCollapsed ? 12 : 20,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.primaryGreen,
                                width: 2,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/icon/app_icon_circle.jpeg',
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.shield,
                                    size: 20,
                                    color: AppColors.primaryGreen,
                                  );
                                },
                              ),
                            ),
                          ),
                          if (!_sidebarCollapsed) ...[
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'MUST Admin',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    const SizedBox(height: 8),
                    // Nav items
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        children:
                            _visibleNavItems
                                .map((item) => _buildSidebarItem(item))
                                .toList(),
                      ),
                    ),
                    // Footer
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: _sidebarCollapsed ? 8 : 16,
                        vertical: 12,
                      ),
                      child:
                          _sidebarCollapsed
                              ? const Icon(
                                Icons.school,
                                color: Colors.white38,
                                size: 20,
                              )
                              : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.school,
                                        color: AppColors.primaryGreen,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'MUST',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'v1.0.0 · © 2026',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.4),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                    ),
                    // Collapse toggle
                    Divider(color: Colors.white.withOpacity(0.1), height: 1),
                    InkWell(
                      onTap:
                          () =>
                              setState(() => _sidebarCollapsed = !_sidebarCollapsed),
                      child: Container(
                        height: 48,
                        alignment: Alignment.center,
                        child: Icon(
                          _sidebarCollapsed
                              ? Icons.keyboard_double_arrow_right
                              : Icons.keyboard_double_arrow_left,
                          color: Colors.white54,
                          size: 20,
                        ),
                      ),
                    ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (!_sidebarCollapsed)
            MouseRegion(
              cursor: SystemMouseCursors.resizeLeftRight,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  setState(() {
                    _sidebarExpandedWidth = (_sidebarExpandedWidth + details.delta.dx)
                        .clamp(_sidebarMinWidth, _sidebarMaxWidth)
                        .toDouble();
                  });
                },
                child: Container(
                  width: 8,
                  color: Colors.black.withOpacity(0.08),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(_NavItem item) {
    final isActive = _selectedIndex == item.index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0.5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => setState(() => _selectedIndex = item.index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarCollapsed ? 10 : 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isActive ? Colors.white : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border:
                  isActive
                      ? Border.all(
                        color: AppColors.primaryGreen.withOpacity(0.7),
                        width: 1.5,
                      )
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? AppColors.primaryGreen : Colors.white60,
                  size: 20,
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? AppColors.primaryGreen : Colors.white70,
                        fontSize: 14,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mobile drawer ──
  Drawer _buildDrawer() {
    return Drawer(
      child: Container(
        decoration: const BoxDecoration(color: AppColors.primaryGreen),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryGreen, width: 2),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/icon/app_icon_circle.jpeg',
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.shield,
                              size: 24,
                              color: AppColors.primaryGreen,
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'MUST Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.1)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children:
                      _visibleNavItems.map((item) {
                        final isActive = _selectedIndex == item.index;
                        return ListTile(
                          leading: Icon(
                            isActive ? item.activeIcon : item.icon,
                            color:
                                isActive
                                    ? AppColors.primaryGreen
                                    : Colors.white60,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color:
                                  isActive
                                      ? AppColors.primaryGreen
                                      : Colors.white70,
                              fontWeight:
                                  isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                          selected: isActive,
                          selectedTileColor: AppColors.primaryGreen.withOpacity(
                            0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          onTap: () {
                            setState(() => _selectedIndex = item.index);
                            Navigator.pop(context);
                          },
                        );
                      }).toList(),
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.1)),
              // Footer
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.school,
                      color: AppColors.secondaryOrange,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'MUST',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'v1.0.0 · © 2026',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.1)),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white60),
                title: const Text(
                  'Sign Out',
                  style: TextStyle(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _handleSignOut();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────
//  Dashboard Overview (index 0 content)
// ──────────────────────────────────────
class _DashboardOverview extends StatefulWidget {
  final AdminUser admin;
  const _DashboardOverview({required this.admin});
  @override
  State<_DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<_DashboardOverview> {
  final _firestore = FirebaseFirestore.instance;

  // Raw data
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allReports = [];
  final Map<String, String> _userFacultyMap = {};
  final Map<String, String> _userDeptMap = {};
  final Map<String, String> _userGenderMap = {};
  final Map<String, String> _userRoleMap = {};

  // Filter state
  String _selectedFaculty = 'All Faculties';
  String _selectedDepartment = 'All Departments';
  String _selectedStatus = 'All Statuses';
  String _viewMode = 'reports'; // 'reports' or 'users'

  // Advanced insights local filters (independent from main dashboard filters)
  String _insightGender = 'All Genders';
  String _insightRole = 'All Roles';
  String _insightReportType = 'All Reports';

  bool _isLoading = true;

  final List<String> _faculties = [
    'School of Health Sciences',
    'School of Science',
    'School of Computing and Informatics',
    'School of Applied Sciences and Technology',
    'School of Business and Management Sciences',
    'School of Interdisciplinary Studies',
  ];

  final Map<String, List<String>> _facultyDepartments = {
    'School of Health Sciences': [
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
    'School of Science': ['Biology', 'Chemistry', 'Physics', 'Mathematics'],
    'School of Computing and Informatics': [
      'Computer Science',
      'Information Technology',
      'Software Engineering',
    ],
    'School of Applied Sciences and Technology': [
      'Biomedical Sciences & Engineering',
      'Civil Engineering',
      'Electrical & Electronics Engineering',
      'Mechanical Engineering',
      'Petroleum & Environmental Management',
    ],
    'School of Business and Management Sciences': [
      'Accounting & Finance',
      'Business Administration',
      'Economics',
      'Procurement & Supply Chain Management',
      'Marketing & Entrepreneurship',
    ],
    'School of Interdisciplinary Studies': [
      'Planning & Governance',
      'Human Development & Relational Sciences',
      'Environment & Livelihood Support Systems',
      'Community Engagement & Service Learning',
    ],
  };

  final List<String> _statuses = [
    'submitted',
    'pending',
    'under_review',
    'resolved',
    'dismissed',
  ];

  String _cleanLabel(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r'^[a-z]\.'), '')
        .replaceAll(RegExp(r'^(school|faculty)\s+of\s+'), '')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _canonicalFaculty(String rawFaculty) {
    final normalized = _cleanLabel(rawFaculty);
    if (normalized.isEmpty) return '';

    if (normalized.contains('computing') &&
        normalized.contains('informatics')) {
      return 'School of Computing and Informatics';
    }
    if (normalized.contains('health') && normalized.contains('science')) {
      return 'School of Health Sciences';
    }
    if (normalized == 'science' || normalized.contains('school science')) {
      return 'School of Science';
    }
    if (normalized.contains('applied') && normalized.contains('technology')) {
      return 'School of Applied Sciences and Technology';
    }
    if (normalized.contains('business') && normalized.contains('management')) {
      return 'School of Business and Management Sciences';
    }
    if (normalized.contains('interdisciplinary')) {
      return 'School of Interdisciplinary Studies';
    }

    for (final faculty in _faculties) {
      final full = _cleanLabel(faculty);
      final short = _cleanLabel(_shortFaculty(faculty));
      if (normalized == full || normalized == short) {
        return faculty;
      }
    }

    return rawFaculty.trim();
  }

  String _canonicalDepartment(String faculty, String rawDepartment) {
    final dept = rawDepartment.trim();
    if (dept.isEmpty) return '';

    final departments = _facultyDepartments[faculty] ?? const <String>[];
    final normalizedDept = _cleanLabel(dept);

    for (final knownDept in departments) {
      if (_cleanLabel(knownDept) == normalizedDept) {
        return knownDept;
      }
    }

    return dept;
  }

  String _normalizeGender(dynamic rawGender) {
    final normalized = _cleanLabel((rawGender ?? '').toString());
    if (normalized == 'male' || normalized == 'man') return 'Male';
    if (normalized == 'female' || normalized == 'woman') return 'Female';
    if (normalized.isEmpty) return 'Unspecified';
    return 'Other';
  }

  String _normalizeRole(dynamic rawRole, dynamic rawOtherRole) {
    final role = (rawRole ?? '').toString().trim();
    final otherRole = (rawOtherRole ?? '').toString().trim();
    if (role.isEmpty) return 'Unspecified';
    if (role.toLowerCase() == 'other') {
      return otherRole.isNotEmpty ? otherRole : 'Other';
    }
    return role;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      // Load users
      final usersSnapshot = await _firestore.collection('users').get();
      _allUsers =
          usersSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            return data;
          }).toList();

      // Build faculty/dept mapping
      for (final user in _allUsers) {
        final id = user['id'] as String;
        final facultyRaw =
            (user['department'] ?? user['faculty'] ?? '').toString();
        final faculty = _canonicalFaculty(facultyRaw);
        final deptRaw = (user['facultyDepartment'] ?? '').toString();
        final dept = _canonicalDepartment(faculty, deptRaw);
        final gender = _normalizeGender(user['gender']);
        final role = _normalizeRole(user['role'], user['otherRole']);

        _userFacultyMap[id] = faculty;
        _userDeptMap[id] = dept;
        _userGenderMap[id] = gender;
        _userRoleMap[id] = role;

        // Keep normalized values on user records for consistent filtering/stats.
        user['department'] = faculty;
        user['facultyDepartment'] = dept;
        user['gender'] = gender;
        user['role'] = role;
      }

      // Load reports
      final reportsSnapshot = await _firestore.collection('reports').get();
      _allReports =
          reportsSnapshot.docs.map((doc) {
            final data = doc.data();
            data['id'] = doc.id;
            // Attach user's faculty/dept to report
            final userId = data['userId'] as String?;
            if (userId != null) {
              data['userFaculty'] = _userFacultyMap[userId] ?? '';
              data['userDept'] = _userDeptMap[userId] ?? '';
              data['userGender'] = _userGenderMap[userId] ?? 'Unspecified';
              data['userRole'] = _userRoleMap[userId] ?? 'Unspecified';
            } else {
              data['userFaculty'] = '';
              data['userDept'] = '';
              data['userGender'] = 'Unspecified';
              data['userRole'] = 'Unspecified';
            }
            return data;
          }).toList();

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  // Get available departments based on selected faculty
  List<String> get _availableDepartments {
    if (_selectedFaculty == 'All Faculties') {
      // Return all departments
      return _facultyDepartments.values.expand((d) => d).toSet().toList()
        ..sort();
    }
    return _facultyDepartments[_selectedFaculty] ?? [];
  }

  // Filtered reports
  List<Map<String, dynamic>> get _filteredReports {
    return _allReports.where((r) {
      if (_selectedFaculty != 'All Faculties' &&
          r['userFaculty'] != _selectedFaculty)
        return false;
      if (_selectedDepartment != 'All Departments' &&
          r['userDept'] != _selectedDepartment)
        return false;
      if (_selectedStatus != 'All Statuses' && r['status'] != _selectedStatus)
        return false;
      return true;
    }).toList();
  }

  // Filtered users
  List<Map<String, dynamic>> get _filteredUsers {
    return _allUsers.where((u) {
      final faculty = u['department'] ?? '';
      final dept = u['facultyDepartment'] ?? '';
      if (_selectedFaculty != 'All Faculties' && faculty != _selectedFaculty)
        return false;
      if (_selectedDepartment != 'All Departments' &&
          dept != _selectedDepartment)
        return false;
      return true;
    }).toList();
  }

  // Stats for filtered data
  Map<String, int> get _filteredStats {
    final reports = _filteredReports;
    return {
      'total': reports.length,
      'pending':
          reports
              .where(
                (r) => r['status'] == 'pending' || r['status'] == 'submitted',
              )
              .length,
      'under_review':
          reports.where((r) => r['status'] == 'under_review').length,
      'resolved': reports.where((r) => r['status'] == 'resolved').length,
      'dismissed': reports.where((r) => r['status'] == 'dismissed').length,
      'anonymous': reports.where((r) => r['isAnonymous'] == true).length,
    };
  }

  List<String> get _availableInsightRoles {
    final roles =
        _filteredUsers
            .map((u) => _normalizeRole(u['role'], u['otherRole']))
            .toSet()
            .toList()
          ..sort();
    return roles;
  }

  List<Map<String, dynamic>> get _advancedFilteredUsers {
    return _filteredUsers.where((u) {
      final gender = _normalizeGender(u['gender']);
      final role = _normalizeRole(u['role'], u['otherRole']);

      if (_insightGender != 'All Genders' && gender != _insightGender) {
        return false;
      }
      if (_insightRole != 'All Roles' && role != _insightRole) {
        return false;
      }
      return true;
    }).toList();
  }

  List<Map<String, dynamic>> get _advancedFilteredReports {
    return _filteredReports.where((r) {
      final gender = _normalizeGender(r['userGender']);
      final role = _normalizeRole(r['userRole'], '');
      final isAnonymous = r['isAnonymous'] == true;

      if (_insightGender != 'All Genders' && gender != _insightGender) {
        return false;
      }
      if (_insightRole != 'All Roles' && role != _insightRole) {
        return false;
      }
      if (_insightReportType == 'Anonymous Only' && !isAnonymous) {
        return false;
      }
      if (_insightReportType == 'Identified Only' && isAnonymous) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, int> get _advancedUserGenderStats {
    final stats = <String, int>{
      'Male': 0,
      'Female': 0,
      'Other': 0,
      'Unspecified': 0,
    };
    for (final user in _advancedFilteredUsers) {
      final gender = _normalizeGender(user['gender']);
      stats[gender] = (stats[gender] ?? 0) + 1;
    }
    return stats;
  }

  Map<String, int> get _advancedReportGenderStats {
    final stats = <String, int>{
      'Male': 0,
      'Female': 0,
      'Other': 0,
      'Unspecified': 0,
    };
    for (final report in _advancedFilteredReports) {
      final gender = _normalizeGender(report['userGender']);
      stats[gender] = (stats[gender] ?? 0) + 1;
    }
    return stats;
  }

  Map<String, int> get _advancedRoleStats {
    final stats = <String, int>{};
    for (final user in _advancedFilteredUsers) {
      final role = _normalizeRole(user['role'], user['otherRole']);
      stats[role] = (stats[role] ?? 0) + 1;
    }
    return stats;
  }

  void _resetFilters() {
    setState(() {
      _selectedFaculty = 'All Faculties';
      _selectedDepartment = 'All Departments';
      _selectedStatus = 'All Statuses';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return Center(
        child: CircularProgressIndicator(color: AppColors.secondaryOrange),
      );

    return RefreshIndicator(
      color: AppColors.secondaryOrange,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 24),
            _buildFilterPanel(),
            const SizedBox(height: 20),
            _buildFilteredStatsCards(),
            const SizedBox(height: 24),
            _buildViewToggle(),
            const SizedBox(height: 16),
            _viewMode == 'reports'
                ? _buildReportsDataView()
                : _buildUsersDataView(),
            const SizedBox(height: 24),
            _buildBreakdownSection(),
            const SizedBox(height: 24),
            _buildAdvancedInsightsSection(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFF228B22), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${widget.admin.fullName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E8B57),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'MUST Sexual Harassment Report System',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMiniStat(
                      'Total Reports',
                      _allReports.length.toString(),
                      AppColors.primaryGreen,
                    ),
                    const SizedBox(width: 16),
                    _buildMiniStat(
                      'Total Users',
                      _allUsers.length.toString(),
                      AppColors.primaryGreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryGreen, width: 3),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/app_icon_circle.jpeg',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryOrange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield,
                      size: 40,
                      color: AppColors.secondaryDark,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: color)),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterPanel() {
    final isWide = MediaQuery.of(context).size.width > 800;
    final hasActiveFilters =
        _selectedFaculty != 'All Faculties' ||
        _selectedDepartment != 'All Departments' ||
        _selectedStatus != 'All Statuses';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasActiveFilters ? Color(0xFF2E8B57) : Colors.grey[200]!,
          width: hasActiveFilters ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.secondaryOrange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.filter_list,
                  color: AppColors.secondaryOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Filter Data',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E8B57),
                ),
              ),
              const Spacer(),
              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.clear_all, size: 18),
                  label: const Text('Reset'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          isWide
              ? Row(
                children: [
                  Expanded(child: _buildFacultyDropdown()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDepartmentDropdown()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildStatusDropdown()),
                ],
              )
              : Column(
                children: [
                  _buildFacultyDropdown(),
                  const SizedBox(height: 12),
                  _buildDepartmentDropdown(),
                  const SizedBox(height: 12),
                  _buildStatusDropdown(),
                ],
              ),
        ],
      ),
    );
  }

  Widget _buildFacultyDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Faculty',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  _selectedFaculty != 'All Faculties'
                      ? AppColors.secondaryOrange
                      : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedFaculty,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              items:
                  ['All Faculties', ..._faculties]
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            f == 'All Faculties' ? f : _shortFaculty(f),
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedFaculty = val!;
                  _selectedDepartment =
                      'All Departments'; // Reset department when faculty changes
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Department',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  _selectedDepartment != 'All Departments'
                      ? AppColors.secondaryOrange
                      : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDepartment,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              items:
                  ['All Departments', ..._availableDepartments]
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(
                            d,
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (val) => setState(() => _selectedDepartment = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Status',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color:
                  _selectedStatus != 'All Statuses'
                      ? AppColors.secondaryOrange
                      : Colors.grey[300]!,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus,
              isExpanded: true,
              icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
              items:
                  ['All Statuses', ..._statuses]
                      .map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              if (s != 'All Statuses') ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getStatusColor(s),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                _formatStatus(s),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
              onChanged: (val) => setState(() => _selectedStatus = val!),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilteredStatsCards() {
    final stats = _filteredStats;
    final isWide = MediaQuery.of(context).size.width > 920;
    final hasFilter =
        _selectedFaculty != 'All Faculties' ||
        _selectedDepartment != 'All Departments' ||
        _selectedStatus != 'All Statuses';

    final chartContent =
        isWide
            ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildStatusPieChart(stats)),
                const SizedBox(width: 12),
                Expanded(child: _buildVolumeBarChart(stats)),
              ],
            )
            : Column(
              children: [
                _buildStatusPieChart(stats),
                const SizedBox(height: 12),
                _buildVolumeBarChart(stats),
              ],
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasFilter)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondaryOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.filter_alt,
                    size: 16,
                    color: AppColors.secondaryOrange,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Showing filtered results: ${_filteredReports.length} reports, ${_filteredUsers.length} users',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        chartContent,
      ],
    );
  }

  Widget _buildStatusPieChart(Map<String, int> stats) {
    final metrics =
        [
          _ChartMetric('Pending', stats['pending'] ?? 0, Colors.orange),
          _ChartMetric(
            'Under Review',
            stats['under_review'] ?? 0,
            AppColors.royalBlue,
          ),
          _ChartMetric('Resolved', stats['resolved'] ?? 0, AppColors.primaryGreen),
          _ChartMetric('Dismissed', stats['dismissed'] ?? 0, Colors.grey),
        ].where((item) => item.value > 0).toList();
    final total = metrics.fold<int>(0, (sum, item) => sum + item.value);

    return _buildChartCardShell(
      title: 'Status Distribution',
      subtitle: 'Reports by workflow stage',
      child:
          total == 0
              ? _buildEmptyChartState('No report data in selected filter')
              : Column(
                children: [
                  SizedBox(
                    height: 190,
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 35,
                        sectionsSpace: 2,
                        sections:
                            metrics.map((metric) {
                              final percentage =
                                  (metric.value / total * 100).round();
                              return PieChartSectionData(
                                color: metric.color,
                                value: metric.value.toDouble(),
                                radius: 52,
                                title: '$percentage%',
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              );
                            }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: metrics.map(_buildMetricLegend).toList(),
                  ),
                ],
              ),
    );
  }

  Widget _buildVolumeBarChart(Map<String, int> stats) {
    final metrics = [
      _ChartMetric('Users', _filteredUsers.length, AppColors.primaryGreen),
      _ChartMetric('Reports', stats['total'] ?? 0, AppColors.secondaryOrange),
      _ChartMetric('Pending', stats['pending'] ?? 0, Colors.orange),
      _ChartMetric('Resolved', stats['resolved'] ?? 0, AppColors.primaryGreen),
      _ChartMetric('Anonymous', stats['anonymous'] ?? 0, Colors.grey[700]!),
    ];
    final maxValue = metrics.fold<int>(
      0,
      (current, item) => math.max(current, item.value),
    );
    final maxY = ((maxValue == 0 ? 1 : maxValue) * 1.3).toDouble();

    return _buildChartCardShell(
      title: 'Key Volumes',
      subtitle: 'Users and report totals',
      child: SizedBox(
        height: 270,
        child: BarChart(
          BarChartData(
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval:
                  maxValue <= 5 ? 1.0 : (maxValue / 5).ceilToDouble(),
              getDrawingHorizontalLine:
                  (value) => FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  ),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget:
                      (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= metrics.length)
                      return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        metrics[index].label,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            barGroups: List.generate(metrics.length, (index) {
              final metric = metrics[index];
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: metric.value.toDouble(),
                    width: 18,
                    color: metric.color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildChartCardShell({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMetricLegend(_ChartMetric metric) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: metric.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: metric.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${metric.label}: ${metric.value}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChartState(String message) {
    return SizedBox(
      height: 220,
      child: Center(
        child: Text(
          message,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.secondaryOrange.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.visibility,
            color: AppColors.secondaryOrange,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        const Text(
          'View Data',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2E8B57),
          ),
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(25),
          ),
          child: Row(
            children: [
              _buildToggleButton(
                'Reports',
                Icons.assignment,
                _viewMode == 'reports',
              ),
              _buildToggleButton('Users', Icons.people, _viewMode == 'users'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton(String label, IconData icon, bool isActive) {
    return GestureDetector(
      onTap: () => setState(() => _viewMode = label.toLowerCase()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsDataView() {
    final reports = _filteredReports;
    if (reports.isEmpty) {
      return _buildEmptyState(
        'No reports found',
        'Try adjusting your filters',
        Icons.assignment_outlined,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${reports.length} Reports',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const Spacer(),
                Text(
                  'Most recent first',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          ...reports.take(10).map((report) => _buildReportRow(report)),
          if (reports.length > 10)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '+ ${reports.length - 10} more reports',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportRow(Map<String, dynamic> report) {
    final status = report['status'] ?? 'unknown';
    final isAnonymous = report['isAnonymous'] == true;
    final createdAt = report['createdAt'];
    String dateStr = '';
    if (createdAt != null) {
      final date = (createdAt as Timestamp).toDate();
      dateStr = '${date.day}/${date.month}/${date.year}';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isAnonymous ? Icons.visibility_off : Icons.assignment,
              color: _getStatusColor(status),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report['userFaculty']?.isNotEmpty == true
                      ? _shortFaculty(report['userFaculty'])
                      : 'Unknown Faculty',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (report['userDept']?.isNotEmpty == true)
                  Text(
                    report['userDept'],
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildStatusChip(status),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersDataView() {
    final users = _filteredUsers;
    if (users.isEmpty) {
      return _buildEmptyState(
        'No users found',
        'Try adjusting your filters',
        Icons.people_outline,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Text(
                  '${users.length} Users',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                ),
                const Spacer(),
                Text(
                  'Alphabetically',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          ...users.take(10).map((user) => _buildUserRow(user)),
          if (users.length > 10)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '+ ${users.length - 10} more users',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user) {
    final name = user['fullName'] ?? user['displayName'] ?? 'Unknown';
    final email = user['email'] ?? '';
    final faculty = user['department'] ?? '';
    final dept = user['facultyDepartment'] ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  email,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (faculty.isNotEmpty)
                Text(
                  _shortFaculty(faculty),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryGreen,
                  ),
                ),
              if (dept.isNotEmpty)
                Text(
                  dept,
                  style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondaryOrange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.bar_chart,
                color: AppColors.secondaryOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Breakdown Summary',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        MediaQuery.of(context).size.width > 800
            ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildFacultyBreakdown()),
                const SizedBox(width: 16),
                Expanded(child: _buildDepartmentBreakdown()),
              ],
            )
            : Column(
              children: [
                _buildFacultyBreakdown(),
                const SizedBox(height: 16),
                _buildDepartmentBreakdown(),
              ],
            ),
      ],
    );
  }

  Widget _buildAdvancedInsightsSection() {
    final isWide = MediaQuery.of(context).size.width > 900;
    final hasInsightFilter =
        _insightGender != 'All Genders' ||
        _insightRole != 'All Roles' ||
        _insightReportType != 'All Reports';

    final roleOptions = _availableInsightRoles;
    final selectedRoleValue =
        (_insightRole == 'All Roles' || roleOptions.contains(_insightRole))
            ? _insightRole
            : 'All Roles';

    if (selectedRoleValue != _insightRole) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _insightRole = selectedRoleValue);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondaryOrange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.insights,
                color: AppColors.secondaryOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Advanced Insights',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  hasInsightFilter
                      ? AppColors.secondaryOrange
                      : Colors.grey[200]!,
            ),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _buildAdvancedDropdown(
                label: 'Gender',
                value: _insightGender,
                items: const ['All Genders', 'Male', 'Female', 'Other', 'Unspecified'],
                onChanged: (v) => setState(() => _insightGender = v),
              ),
              _buildAdvancedDropdown(
                label: 'Role',
                value: selectedRoleValue,
                items: ['All Roles', ...roleOptions],
                onChanged: (v) => setState(() => _insightRole = v),
              ),
              _buildAdvancedDropdown(
                label: 'Report Type',
                value: _insightReportType,
                items: const ['All Reports', 'Anonymous Only', 'Identified Only'],
                onChanged: (v) => setState(() => _insightReportType = v),
              ),
              if (hasInsightFilter)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _insightGender = 'All Genders';
                      _insightRole = 'All Roles';
                      _insightReportType = 'All Reports';
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Reset Insights'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        isWide
            ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildGenderDistributionCard()),
                const SizedBox(width: 16),
                Expanded(child: _buildProfessionalKpiCard()),
              ],
            )
            : Column(
              children: [
                _buildGenderDistributionCard(),
                const SizedBox(height: 16),
                _buildProfessionalKpiCard(),
              ],
            ),
      ],
    );
  }

  Widget _buildAdvancedDropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180, maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey[600]),
          items:
              items
                  .map(
                    (item) => DropdownMenuItem<String>(
                      value: item,
                      child: Text(
                        '$label: $item',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _buildGenderDistributionCard() {
    final userGender = _advancedUserGenderStats;
    final reportGender = _advancedReportGenderStats;
    final categories = ['Male', 'Female', 'Other', 'Unspecified'];

    final maxValue = [
      ...categories.map((g) => userGender[g] ?? 0),
      ...categories.map((g) => reportGender[g] ?? 0),
    ].fold<int>(0, (current, item) => math.max(current, item));

    final maxY = ((maxValue == 0 ? 1 : maxValue) * 1.3).toDouble();

    return _buildChartCardShell(
      title: 'Gender Analytics',
      subtitle: 'Users and reports by gender (filtered)',
      child: Column(
        children: [
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                groupsSpace: 16,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval:
                      maxValue <= 5 ? 1.0 : (maxValue / 5).ceilToDouble(),
                  getDrawingHorizontalLine:
                      (value) => FlLine(
                        color: Colors.grey.withOpacity(0.15),
                        strokeWidth: 1,
                      ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget:
                          (value, meta) => Text(
                            value.toInt().toString(),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= categories.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            categories[index],
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(categories.length, (index) {
                  final gender = categories[index];
                  return BarChartGroupData(
                    x: index,
                    barsSpace: 6,
                    barRods: [
                      BarChartRodData(
                        toY: (userGender[gender] ?? 0).toDouble(),
                        width: 12,
                        color: AppColors.primaryGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      BarChartRodData(
                        toY: (reportGender[gender] ?? 0).toDouble(),
                        width: 12,
                        color: AppColors.secondaryOrange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildMetricLegend(
                _ChartMetric('Users', _advancedFilteredUsers.length, AppColors.primaryGreen),
              ),
              _buildMetricLegend(
                _ChartMetric(
                  'Reports',
                  _advancedFilteredReports.length,
                  AppColors.secondaryOrange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalKpiCard() {
    final reportsData = _advancedFilteredReports;
    final usersData = _advancedFilteredUsers;
    final reports = reportsData.length;
    final resolved = reportsData.where((r) => r['status'] == 'resolved').length;
    final underReview =
        reportsData.where((r) => r['status'] == 'under_review').length;
    final anonymous = reportsData.where((r) => r['isAnonymous'] == true).length;
    final roles = _advancedRoleStats.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final resolutionRate = reports == 0 ? 0 : ((resolved / reports) * 100).round();
    final anonymousRate = reports == 0 ? 0 : ((anonymous / reports) * 100).round();
    final reviewRate = reports == 0 ? 0 : ((underReview / reports) * 100).round();

    return _buildChartCardShell(
      title: 'Operational KPI Snapshot',
      subtitle: 'Resolution, anonymity, workflow pressure, and user roles',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  'Resolution Rate',
                  '$resolutionRate%',
                  Icons.verified,
                  AppColors.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiTile(
                  'Anonymous Rate',
                  '$anonymousRate%',
                  Icons.visibility_off,
                  Colors.grey[700]!,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  'Under Review',
                  '$reviewRate%',
                  Icons.hourglass_top,
                  AppColors.royalBlue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiTile(
                  'Active Filters Users',
                  '${usersData.length}',
                  Icons.people,
                  AppColors.secondaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Top User Roles',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (roles.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'No role data in current filter',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  roles
                      .take(6)
                      .map(
                        (entry) => Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${entry.key}: ${entry.value}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildKpiTile(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 10, color: Colors.grey[700]),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyBreakdown() {
    // Build counts per faculty
    Map<String, int> reportsByFaculty = {};
    Map<String, int> usersByFaculty = {};

    for (final report in _allReports) {
      final f = report['userFaculty'] ?? '';
      if (f.isNotEmpty) reportsByFaculty[f] = (reportsByFaculty[f] ?? 0) + 1;
    }

    for (final user in _allUsers) {
      final f = user['department'] ?? '';
      if (f.isNotEmpty) usersByFaculty[f] = (usersByFaculty[f] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Icon(Icons.school, size: 18, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              const Text(
                'By Faculty',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._faculties.map((faculty) {
            final reports = reportsByFaculty[faculty] ?? 0;
            final users = usersByFaculty[faculty] ?? 0;
            final isSelected = _selectedFaculty == faculty;
            return GestureDetector(
              onTap:
                  () => setState(() {
                    _selectedFaculty = isSelected ? 'All Faculties' : faculty;
                    _selectedDepartment = 'All Departments';
                  }),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? AppColors.secondaryOrange.withOpacity(0.1)
                          : Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border:
                      isSelected
                          ? Border.all(color: AppColors.secondaryOrange)
                          : null,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shortFaculty(faculty),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color:
                              isSelected
                                  ? AppColors.primaryGreen
                                  : Colors.grey[700],
                        ),
                      ),
                    ),
                    _miniCount(
                      reports,
                      Icons.assignment,
                      AppColors.secondaryOrange,
                    ),
                    const SizedBox(width: 8),
                    _miniCount(users, Icons.people, AppColors.primaryGreen),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDepartmentBreakdown() {
    // Get departments data based on current faculty selection
    Map<String, int> reportsByDept = {};
    Map<String, int> usersByDept = {};

    for (final report in _allReports) {
      if (_selectedFaculty != 'All Faculties' &&
          report['userFaculty'] != _selectedFaculty)
        continue;
      final d = report['userDept'] ?? '';
      if (d.isNotEmpty) reportsByDept[d] = (reportsByDept[d] ?? 0) + 1;
    }

    for (final user in _allUsers) {
      if (_selectedFaculty != 'All Faculties' &&
          user['department'] != _selectedFaculty)
        continue;
      final d = user['facultyDepartment'] ?? '';
      if (d.isNotEmpty) usersByDept[d] = (usersByDept[d] ?? 0) + 1;
    }

    final allDepts =
        {...reportsByDept.keys, ...usersByDept.keys}.toList()..sort();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
              const Icon(
                Icons.account_tree,
                size: 18,
                color: AppColors.primaryGreen,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedFaculty != 'All Faculties'
                      ? 'Departments in ${_shortFaculty(_selectedFaculty)}'
                      : 'By Department (All)',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (allDepts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  'No department data',
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ),
            )
          else
            ...allDepts.take(8).map((dept) {
              final reports = reportsByDept[dept] ?? 0;
              final users = usersByDept[dept] ?? 0;
              final isSelected = _selectedDepartment == dept;
              return GestureDetector(
                onTap:
                    () => setState(
                      () =>
                          _selectedDepartment =
                              isSelected ? 'All Departments' : dept,
                    ),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? AppColors.secondaryOrange.withOpacity(0.1)
                            : Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border:
                        isSelected
                            ? Border.all(color: AppColors.secondaryOrange)
                            : null,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dept,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color:
                                isSelected
                                    ? AppColors.primaryGreen
                                    : Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _miniCount(
                        reports,
                        Icons.assignment,
                        AppColors.secondaryOrange,
                      ),
                      const SizedBox(width: 8),
                      _miniCount(users, Icons.people, AppColors.primaryGreen),
                    ],
                  ),
                ),
              );
            }),
          if (allDepts.length > 8)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '+ ${allDepts.length - 8} more departments',
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _miniCount(int count, IconData icon, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        _formatStatus(status),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: _getStatusColor(status),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'submitted':
        return AppColors.primaryGreen;
      case 'under_review':
        return AppColors.royalBlue;
      case 'resolved':
        return AppColors.primaryGreen;
      case 'dismissed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    if (status == 'All Statuses') return status;
    return status
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : w)
        .join(' ');
  }

  String _shortFaculty(String s) => s.replaceAll('School of ', '');
}

class _ChartMetric {
  final String label;
  final int value;
  final Color color;

  const _ChartMetric(this.label, this.value, this.color);
}
