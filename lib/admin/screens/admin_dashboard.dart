import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      const _NavItem(label: 'Dashboard', icon: Icons.dashboard_outlined, activeIcon: Icons.dashboard, index: 0),
      const _NavItem(label: 'Reports', icon: Icons.assignment_outlined, activeIcon: Icons.assignment, index: 1),
      const _NavItem(label: 'Users', icon: Icons.people_outline, activeIcon: Icons.people, index: 2),
      const _NavItem(label: 'Analytics', icon: Icons.analytics_outlined, activeIcon: Icons.analytics, index: 3),
      const _NavItem(label: 'Contacts', icon: Icons.contact_phone_outlined, activeIcon: Icons.contact_phone, index: 4),
      const _NavItem(label: 'Policy RAG', icon: Icons.policy_outlined, activeIcon: Icons.policy, index: 5),
      const _NavItem(label: 'Admins', icon: Icons.admin_panel_settings_outlined, activeIcon: Icons.admin_panel_settings, index: 6, superAdminOnly: true),
      const _NavItem(label: 'Export', icon: Icons.download_outlined, activeIcon: Icons.download, index: 7),
      const _NavItem(label: 'Profile', icon: Icons.account_circle_outlined, activeIcon: Icons.account_circle, index: 8),
    ];
  }

  List<_NavItem> get _visibleNavItems {
    return _navItems.where((item) {
      if (item.superAdminOnly && widget.admin.role != AdminRole.superAdmin) return false;
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
      default:
        return _DashboardOverview(admin: widget.admin);
    }
  }

  Future<void> _handleSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.logout, color: AppColors.mustGold),
          const SizedBox(width: 8),
          const Text('Sign Out'),
        ]),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.mustBlue, foregroundColor: Colors.white),
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
      backgroundColor: const Color(0xFFF5F6FA),
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
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          if (!isWide)
            Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu, color: AppColors.mustBlue),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          if (!isWide) const SizedBox(width: 8),
          Text(
            currentItem.label,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.mustBlue),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.mustBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                CircleAvatar(radius: 14, backgroundColor: AppColors.mustGold, child: Icon(Icons.person, size: 16, color: AppColors.mustBlue)),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.admin.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mustBlue)),
                    Text(widget.admin.role.displayName, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.mustBlue),
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
      width: _sidebarCollapsed ? 72 : 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.mustBlue, Color(0xFF0D2137)],
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 20),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.mustGold, AppColors.mustGoldLight]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.shield, size: 20, color: AppColors.mustBlue),
                ),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'MUST Admin',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
              children: _visibleNavItems.map((item) => _buildSidebarItem(item)).toList(),
            ),
          ),
          // Footer
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _sidebarCollapsed ? 8 : 16,
              vertical: 12,
            ),
            child: _sidebarCollapsed
                ? const Icon(Icons.school, color: Colors.white38, size: 20)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.school, color: AppColors.mustGold, size: 16),
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
                _sidebarCollapsed ? Icons.keyboard_double_arrow_right : Icons.keyboard_double_arrow_left,
                color: Colors.white54, size: 20,
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _selectedIndex = item.index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(horizontal: _sidebarCollapsed ? 12 : 16, vertical: 12),
            decoration: BoxDecoration(
              color: isActive ? AppColors.mustGold.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isActive ? Border.all(color: AppColors.mustGold.withOpacity(0.3), width: 1) : null,
            ),
            child: Row(
              children: [
                Icon(isActive ? item.activeIcon : item.icon, color: isActive ? AppColors.mustGold : Colors.white60, size: 22),
                if (!_sidebarCollapsed) ...[
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        color: isActive ? AppColors.mustGoldLight : Colors.white70,
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.mustBlue, Color(0xFF0D2137)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.mustGold, AppColors.mustGoldLight]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shield, size: 24, color: AppColors.mustBlue),
                    ),
                    const SizedBox(width: 12),
                    const Text('MUST Admin', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.1)),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: _visibleNavItems.map((item) {
                    final isActive = _selectedIndex == item.index;
                    return ListTile(
                      leading: Icon(isActive ? item.activeIcon : item.icon, color: isActive ? AppColors.mustGold : Colors.white60),
                      title: Text(item.label, style: TextStyle(color: isActive ? AppColors.mustGoldLight : Colors.white70, fontWeight: isActive ? FontWeight.w600 : FontWeight.normal)),
                      selected: isActive,
                      selectedTileColor: AppColors.mustGold.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  children: [
                    const Icon(Icons.school, color: AppColors.mustGold, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'MUST',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Text(
                      'v1.0.0 · © 2026',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                    ),
                  ],
                ),
              ),
              Divider(color: Colors.white.withOpacity(0.1)),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.white60),
                title: const Text('Sign Out', style: TextStyle(color: Colors.white70)),
                onTap: () { Navigator.pop(context); _handleSignOut(); },
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

  int _totalUsers = 0, _totalReports = 0, _pendingReports = 0;
  int _resolvedReports = 0, _underReviewReports = 0, _anonymousReports = 0;
  Map<String, int> _reportsByFaculty = {};
  Map<String, int> _usersByFaculty = {};
  Map<String, Map<String, int>> _reportsByDepartment = {};
  Map<String, Map<String, int>> _statusByFaculty = {};
  bool _isLoading = true;
  String _selectedFacultyFilter = 'All';

  final List<String> _faculties = [
    'Faculty of Medicine',
    'Faculty of Science',
    'Faculty of Computing and Informatics',
    'Faculty of Applied Sciences and Technology',
    'Faculty of Business and Management Sciences',
    'Faculty of Interdisciplinary Studies',
  ];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() => _isLoading = true);
    try {
      final usersSnapshot = await _firestore.collection('users').get();
      _totalUsers = usersSnapshot.docs.length;

      Map<String, String> userFacultyMap = {};
      Map<String, String> userDeptMap = {};
      Map<String, int> usersByFaculty = {};

      for (final doc in usersSnapshot.docs) {
        final data = doc.data();
        final faculty = (data['department'] ?? '') as String;
        final dept = (data['facultyDepartment'] ?? '') as String;
        userFacultyMap[doc.id] = faculty;
        userDeptMap[doc.id] = dept;
        if (faculty.isNotEmpty) usersByFaculty[faculty] = (usersByFaculty[faculty] ?? 0) + 1;
      }

      final reportsSnapshot = await _firestore.collection('reports').get();
      _totalReports = reportsSnapshot.docs.length;

      int pending = 0, resolved = 0, underReview = 0, anonymous = 0;
      Map<String, int> reportsByFaculty = {};
      Map<String, Map<String, int>> reportsByDepartment = {};
      Map<String, Map<String, int>> statusByFaculty = {};

      for (final doc in reportsSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '') as String;
        final userId = data['userId'] as String?;
        final isAnonymous = data['isAnonymous'] == true;

        if (status == 'pending' || status == 'submitted') pending++;
        if (status == 'resolved') resolved++;
        if (status == 'under_review') underReview++;
        if (isAnonymous) anonymous++;

        String faculty = '', dept = '';
        if (userId != null && userFacultyMap.containsKey(userId)) {
          faculty = userFacultyMap[userId]!;
          dept = userDeptMap[userId] ?? '';
        }
        if (faculty.isNotEmpty) {
          reportsByFaculty[faculty] = (reportsByFaculty[faculty] ?? 0) + 1;
          statusByFaculty.putIfAbsent(faculty, () => {});
          statusByFaculty[faculty]![status] = (statusByFaculty[faculty]![status] ?? 0) + 1;
          if (dept.isNotEmpty) {
            reportsByDepartment.putIfAbsent(faculty, () => {});
            reportsByDepartment[faculty]![dept] = (reportsByDepartment[faculty]![dept] ?? 0) + 1;
          }
        }
      }

      setState(() {
        _pendingReports = pending;
        _resolvedReports = resolved;
        _underReviewReports = underReview;
        _anonymousReports = anonymous;
        _reportsByFaculty = reportsByFaculty;
        _usersByFaculty = usersByFaculty;
        _reportsByDepartment = reportsByDepartment;
        _statusByFaculty = statusByFaculty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Center(child: CircularProgressIndicator(color: AppColors.mustGold));

    return RefreshIndicator(
      color: AppColors.mustGold,
      onRefresh: _loadStatistics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeBanner(),
            const SizedBox(height: 24),
            _buildSectionHeader('System Overview', Icons.dashboard),
            const SizedBox(height: 12),
            _buildOverviewStats(),
            const SizedBox(height: 28),
            _buildSectionHeader('Reports by Faculty', Icons.school),
            const SizedBox(height: 12),
            _buildFacultyReportsSection(),
            const SizedBox(height: 28),
            _buildSectionHeader('Users by Faculty', Icons.people),
            const SizedBox(height: 12),
            _buildUsersByFacultySection(),
            const SizedBox(height: 28),
            _buildSectionHeader('Department Breakdown', Icons.account_tree),
            const SizedBox(height: 12),
            _buildDepartmentBreakdown(),
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
        gradient: const LinearGradient(colors: [AppColors.mustBlue, AppColors.mustBlueMedium]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: AppColors.mustBlue.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome back, ${widget.admin.fullName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 4),
              Text('MUST Sexual Harassment Report System', style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8))),
              const SizedBox(height: 12),
              Row(children: [
                _buildMiniStat('Total Reports', _totalReports.toString(), AppColors.mustGoldLight),
                const SizedBox(width: 16),
                _buildMiniStat('Pending', _pendingReports.toString(), Colors.orange[200]!),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppColors.mustGold.withOpacity(0.2), shape: BoxShape.circle),
            child: const Icon(Icons.shield, size: 40, color: AppColors.mustGoldLight),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.7))),
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: AppColors.mustGold.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AppColors.mustGold, size: 20),
      ),
      const SizedBox(width: 12),
      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.mustBlue)),
    ]);
  }

  Widget _buildOverviewStats() {
    final wide = MediaQuery.of(context).size.width > 800;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: wide ? 6 : 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: wide ? 1.1 : 0.95,
      children: [
        _buildStatCard('Total Users', _totalUsers.toString(), Icons.people, AppColors.mustBlue),
        _buildStatCard('Total Reports', _totalReports.toString(), Icons.description, AppColors.mustGold),
        _buildStatCard('Pending', _pendingReports.toString(), Icons.pending_actions, Colors.orange),
        _buildStatCard('Under Review', _underReviewReports.toString(), Icons.search, AppColors.mustBlueMedium),
        _buildStatCard('Resolved', _resolvedReports.toString(), Icons.check_circle, AppColors.mustGreen),
        _buildStatCard('Anonymous', _anonymousReports.toString(), Icons.visibility_off, Colors.grey[700]!),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 20)),
        const SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500), textAlign: TextAlign.center),
      ]),
    );
  }

  Widget _buildFacultyReportsSection() {
    final sortedFaculties = List<String>.from(_faculties)..sort((a, b) => (_reportsByFaculty[b] ?? 0).compareTo(_reportsByFaculty[a] ?? 0));
    final maxReports = _reportsByFaculty.values.isEmpty ? 1 : _reportsByFaculty.values.reduce((a, b) => a > b ? a : b).clamp(1, double.maxFinite.toInt());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        children: sortedFaculties.map((faculty) {
          final count = _reportsByFaculty[faculty] ?? 0;
          final statusMap = _statusByFaculty[faculty] ?? {};
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Expanded(child: Text(_shortFaculty(faculty), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.mustBlue))),
                Row(children: [
                  if ((statusMap['pending'] ?? 0) + (statusMap['submitted'] ?? 0) > 0)
                    _chip('${(statusMap['pending'] ?? 0) + (statusMap['submitted'] ?? 0)} pending', Colors.orange),
                  if (statusMap['resolved'] != null)
                    Padding(padding: const EdgeInsets.only(left: 4), child: _chip('${statusMap['resolved']} resolved', AppColors.mustGreen)),
                  const SizedBox(width: 8),
                  Text('$count', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.mustGold)),
                ]),
              ]),
              const SizedBox(height: 6),
              ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: maxReports > 0 ? count / maxReports : 0, backgroundColor: Colors.grey[100], valueColor: AlwaysStoppedAnimation(count > 0 ? AppColors.mustGold : Colors.grey[300]!), minHeight: 8)),
              if (faculty != sortedFaculties.last) Divider(color: Colors.grey[100], height: 16),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _chip(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: Text(text, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
  );

  Widget _buildUsersByFacultySection() {
    final maxUsers = _usersByFaculty.values.isEmpty ? 1 : _usersByFaculty.values.reduce((a, b) => a > b ? a : b).clamp(1, double.maxFinite.toInt());
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
      child: Column(
        children: _faculties.map((faculty) {
          final count = _usersByFaculty[faculty] ?? 0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Container(width: 32, height: 32, decoration: BoxDecoration(color: AppColors.mustBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text('$count', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.mustBlue)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_shortFaculty(faculty), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: maxUsers > 0 ? count / maxUsers : 0, backgroundColor: Colors.grey[100], valueColor: const AlwaysStoppedAnimation(AppColors.mustBlue), minHeight: 6)),
              ])),
            ]),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDepartmentBreakdown() {
    return Column(children: [
      SizedBox(
        height: 40,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          _buildFilterChip('All', _selectedFacultyFilter == 'All'),
          ..._faculties.map((f) => _buildFilterChip(_shortFaculty(f), _selectedFacultyFilter == f, fullName: f)),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))]),
        child: _buildDepartmentList(),
      ),
    ]);
  }

  Widget _buildFilterChip(String label, bool isSelected, {String? fullName}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFacultyFilter = fullName ?? label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: isSelected ? AppColors.mustGold : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? AppColors.mustGold : Colors.grey[300]!)),
          child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? AppColors.mustBlue : Colors.grey[600])),
        ),
      ),
    );
  }

  Widget _buildDepartmentList() {
    Map<String, int> deptData = {};
    if (_selectedFacultyFilter == 'All') {
      for (final entry in _reportsByDepartment.entries) {
        for (final d in entry.value.entries) {
          deptData[d.key] = (deptData[d.key] ?? 0) + d.value;
        }
      }
    } else {
      deptData = _reportsByDepartment[_selectedFacultyFilter] ?? {};
    }

    if (deptData.isEmpty) {
      return Padding(padding: const EdgeInsets.all(24), child: Column(children: [
        Icon(Icons.info_outline, size: 40, color: Colors.grey[300]),
        const SizedBox(height: 8),
        Text('No department data available', style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      ]));
    }

    final sorted = deptData.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final maxVal = sorted.first.value.clamp(1, double.maxFinite.toInt());

    return Column(
      children: sorted.map((entry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(width: 36, height: 36, decoration: BoxDecoration(gradient: const LinearGradient(colors: [AppColors.mustGold, AppColors.mustGoldLight]), borderRadius: BorderRadius.circular(8)),
            child: Center(child: Text('${entry.value}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.mustBlue)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(entry.key, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: entry.value / maxVal, backgroundColor: Colors.grey[100], valueColor: const AlwaysStoppedAnimation(AppColors.mustGreenLight), minHeight: 6)),
          ])),
        ]),
      )).toList(),
    );
  }

  String _shortFaculty(String s) => s.replaceAll('Faculty of ', 'F. ');
}
