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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarCollapsed ? 60 : 180,
      decoration: const BoxDecoration(color: AppColors.admingreen),
      child: Column(
        children: [
          // Header
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
                    color: AppColors.admingreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.shield,
                    size: 20,
                    color: Colors.white,
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
                    ? const Icon(Icons.school, color: Colors.white38, size: 20)
                    : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.school,
                              color: AppColors.admingreen,
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
            onTap: () => setState(() => _sidebarCollapsed = !_sidebarCollapsed),
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
                        color: AppColors.admingreen.withOpacity(0.7),
                        width: 1.5,
                      )
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? item.activeIcon : item.icon,
                  color: isActive ? AppColors.admingreen : Colors.white60,
                  size: 20,
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? AppColors.admingreen : Colors.white70,
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
                        color: AppColors.secondaryOrange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shield,
                        size: 24,
                        color: Colors.white,
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
                                    ? AppColors.admingreen
                                    : Colors.white60,
                          ),
                          title: Text(
                            item.label,
                            style: TextStyle(
                              color:
                                  isActive
                                      ? AppColors.admingreen
                                      : Colors.white70,
                              fontWeight:
                                  isActive
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                            ),
                          ),
                          selected: isActive,
                          selectedTileColor: AppColors.admingreen.withOpacity(
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

  // Filter state
  String _selectedFaculty = 'All Faculties';
  String _selectedDepartment = 'All Departments';
  String _selectedStatus = 'All Statuses';
  String _viewMode = 'reports'; // 'reports' or 'users'

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
        _userFacultyMap[id] = (user['department'] ?? '') as String;
        _userDeptMap[id] = (user['facultyDepartment'] ?? '') as String;
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
            } else {
              data['userFaculty'] = '';
              data['userDept'] = '';
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
            color: AppColors.admingreen.withOpacity(0.10),
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
                    color: AppColors.admingreen,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildMiniStat(
                      'Total Reports',
                      _allReports.length.toString(),
                      AppColors.admingreen,
                    ),
                    const SizedBox(width: 16),
                    _buildMiniStat(
                      'Total Users',
                      _allUsers.length.toString(),
                      AppColors.admingreen,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.secondaryOrange.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shield,
              size: 40,
              color: AppColors.secondaryDark,
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
            AppColors.primaryDark,
          ),
          _ChartMetric('Resolved', stats['resolved'] ?? 0, AppColors.mustGreen),
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
      _ChartMetric('Resolved', stats['resolved'] ?? 0, AppColors.mustGreen),
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
        return AppColors.primaryDark;
      case 'resolved':
        return AppColors.mustGreen;
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
