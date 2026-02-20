import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/app_colors.dart';
import '../services/auth_service.dart';
import 'report_form_screen.dart';
import 'login_screen.dart';
import 'report_details_screen.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _selectedStatus = 'All';
  String _sortBy = 'Date (Newest)';
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  bool _isLookingUp = false;

  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Investigating',
    'Resolved',
    'Closed',
  ];
  final List<String> _sortOptions = [
    'Date (Newest)',
    'Date (Oldest)',
    'Status',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'My Reports',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppColors.mustBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.mustBlue),
              ),
            );
          }

          final user = authSnapshot.data;

          if (user == null) {
            return _buildNotLoggedInView(context);
          }

          return _buildUserReportsView(context, user.uid);
        },
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.mustGold, AppColors.mustGoldLight],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.mustGold.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ReportFormScreen()),
            );
          },
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.mustBlue,
          elevation: 0,
          child: const Icon(Icons.add_rounded, size: 28),
        ),
      ),
    );
  }

  Widget _buildUserReportsView(BuildContext context, String userId) {
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search Box
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search reports...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.mustBlue,
                    ),
                    suffixIcon:
                        _searchQuery.isNotEmpty
                            ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[400]),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                              },
                            )
                            : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Filter and Sort Options
              Row(
                children: [
                  Expanded(
                    child: _buildFilterDropdown(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSortDropdown(),
                  ),
                ],
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
                    .where('userId', isEqualTo: userId)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.mustBlue),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _buildErrorState(snapshot.error.toString());
              }

              var reports = snapshot.data?.docs ?? [];

              // Apply filters and search
              reports = _filterAndSortReports(reports);

              if (reports.isEmpty) {
                return _buildEmptyState(context);
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final reportData =
                      reports[index].data() as Map<String, dynamic>;
                  final reportId = reports[index].id;

                  return _buildReportCard(context, reportId, reportData);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _selectedStatus != 'All' 
            ? _getStatusColor(_selectedStatus).withOpacity(0.1) 
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _selectedStatus != 'All' 
              ? _getStatusColor(_selectedStatus).withOpacity(0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: DropdownButton<String>(
        value: _selectedStatus,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(
          Icons.arrow_drop_down_rounded,
          color: _selectedStatus != 'All' 
              ? _getStatusColor(_selectedStatus) 
              : Colors.grey[600],
        ),
        items: _statusOptions.map((status) {
          return DropdownMenuItem(
            value: status,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: status == 'All' ? Colors.grey : _getStatusColor(status),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _selectedStatus == status ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedStatus = value ?? 'All';
          });
        },
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButton<String>(
        value: _sortBy,
        isExpanded: true,
        underline: const SizedBox(),
        icon: Icon(Icons.arrow_drop_down_rounded, color: Colors.grey[600]),
        items: _sortOptions.map((sort) {
          return DropdownMenuItem(
            value: sort,
            child: Row(
              children: [
                Icon(
                  Icons.sort_rounded,
                  size: 16,
                  color: AppColors.mustBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sort,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _sortBy = value ?? 'Date (Newest)';
          });
        },
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
            ),
            const SizedBox(height: 20),
            const Text(
              'Something went wrong',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterAndSortReports(
    List<QueryDocumentSnapshot> reports,
  ) {
    var filtered =
        reports.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final description =
              (data['description'] ?? '').toString().toLowerCase();
          final category = (data['category'] ?? '').toString().toLowerCase();
          final status = (data['status'] ?? 'pending').toString().toLowerCase();

          // Apply search filter
          final matchesSearch =
              _searchQuery.isEmpty ||
              description.contains(_searchQuery) ||
              category.contains(_searchQuery);

          // Apply status filter (case-insensitive comparison)
          final matchesStatus =
              _selectedStatus == 'All' || status == _selectedStatus.toLowerCase();

          return matchesSearch && matchesStatus;
        }).toList();

    // Apply sorting
    if (_sortBy == 'Date (Oldest)') {
      filtered.sort((a, b) {
        final dateA =
            (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        final dateB =
            (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
        return (dateA?.toDate() ?? DateTime.now()).compareTo(
          dateB?.toDate() ?? DateTime.now(),
        );
      });
    } else if (_sortBy == 'Status') {
      filtered.sort((a, b) {
        final statusA =
            ((a.data() as Map<String, dynamic>)['status'] ?? 'Pending')
                .toString();
        final statusB =
            ((b.data() as Map<String, dynamic>)['status'] ?? 'Pending')
                .toString();
        return statusA.compareTo(statusB);
      });
    }

    return filtered;
  }

  Widget _buildEmptyState(BuildContext context) {
    final bool hasFilters = _selectedStatus != 'All' || _searchQuery.isNotEmpty;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.mustBlue.withOpacity(0.1),
                      AppColors.mustBlue.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasFilters ? Icons.search_off_rounded : Icons.description_outlined,
                  size: 64,
                  color: AppColors.mustBlue,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                hasFilters ? 'No Matching Reports' : 'No Reports Yet',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                hasFilters
                    ? 'Try adjusting your search or filters to find what you\'re looking for.'
                    : 'You haven\'t submitted any reports yet.\nTap the button below to create your first report.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              if (hasFilters) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedStatus = 'All';
                      _searchQuery = '';
                      _searchController.clear();
                    });
                  },
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Clear Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mustBlue,
                    side: BorderSide(color: AppColors.mustBlue),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.mustBlue, AppColors.mustBlue.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mustBlue.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReportFormScreen()),
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Create New Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportCard(
    BuildContext context,
    String reportId,
    Map<String, dynamic> reportData,
  ) {
    final status = reportData['status'] ?? 'pending';
    final category = reportData['category'] ?? 'Report';
    final description = reportData['description'] ?? '';
    final date = reportData['date'];
    final List<String> imageUrls = List<String>.from(reportData['imageUrls'] ?? []);
    final List<String> videoUrls = List<String>.from(reportData['videoUrls'] ?? []);
    final bool hasAttachments = imageUrls.isNotEmpty || videoUrls.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportDetailsScreen(
                  reportId: reportId,
                  reportData: reportData,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getCategoryIcon(category),
                        color: _getStatusColor(status),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 12,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatDate(date),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(status),
                  ],
                ),
                
                const SizedBox(height: 14),
                
                // Description
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                ),
                
                // Attachments indicator and View button
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Attachments indicator
                    if (hasAttachments)
                      Row(
                        children: [
                          if (imageUrls.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo, size: 14, color: Colors.blue),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${imageUrls.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (videoUrls.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.videocam, size: 14, color: Colors.purple),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${videoUrls.length}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.purple,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      )
                    else
                      const SizedBox(),
                    
                    // View Details Button
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.mustBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ReportDetailsScreen(
                                  reportId: reportId,
                                  reportData: reportData,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'View Details',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.mustBlue,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                  color: AppColors.mustBlue,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _getStatusColor(status).withOpacity(0.3),
        ),
      ),
      child: Text(
        status.substring(0, 1).toUpperCase() + status.substring(1).toLowerCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: _getStatusColor(status),
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'verbal harassment':
        return Icons.record_voice_over_rounded;
      case 'physical harassment':
        return Icons.front_hand_rounded;
      case 'online harassment':
        return Icons.computer_rounded;
      case 'stalking':
        return Icons.visibility_rounded;
      default:
        return Icons.report_rounded;
    }
  }

  Widget _buildNotLoggedInView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.red.shade100.withOpacity(0.5),
                      Colors.red.shade50.withOpacity(0.3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 64,
                  color: Colors.red.shade400,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Login Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sign in to view and manage your submitted reports.\nYour reports are securely stored and only visible to you.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14, 
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.mustBlue, AppColors.mustBlue.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.mustBlue.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  ),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign In'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: TextStyle(color: Colors.grey[500], fontSize: 14),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ReportFormScreen()),
                  ),
                  icon: const Icon(Icons.shield_outlined),
                  label: const Text('Submit Anonymous Report'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.mustBlue,
                    side: BorderSide(color: AppColors.mustBlue.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),

              // ── Track Anonymous Report Section ──
              const SizedBox(height: 36),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Track Anonymous Report',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.vpn_key_rounded,
                      size: 36,
                      color: AppColors.mustBlue.withOpacity(0.7),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Have a tracking token?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Enter the token you received when you submitted your anonymous report to check its status.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: TextField(
                        controller: _tokenController,
                        textCapitalization: TextCapitalization.characters,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          hintText: 'XXXX-XXXX-XXXX',
                          hintStyle: TextStyle(
                            color: Colors.grey[350],
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: AppColors.mustBlue,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLookingUp ? null : _lookupAnonymousReport,
                        icon: _isLookingUp
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.track_changes_rounded),
                        label: Text(_isLookingUp ? 'Looking up...' : 'Track Report'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mustBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    if (date is Timestamp) {
      final dateTime = date.toDate();
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
    return 'N/A';
  }

  String _formatDateString(dynamic date) {
    if (date == null) return 'N/A';
    if (date is String) {
      try {
        final dt = DateTime.parse(date);
        return '${dt.day}/${dt.month}/${dt.year}';
      } catch (_) {
        return date;
      }
    }
    return date.toString();
  }

  /// Look up an anonymous report by tracking token
  Future<void> _lookupAnonymousReport() async {
    final token = _tokenController.text.trim().toUpperCase();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a tracking token'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLookingUp = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('reports')
          .where('trackingToken', isEqualTo: token)
          .limit(1)
          .get();

      if (!mounted) return;

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.search_off, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('No report found with that tracking token'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        final doc = querySnapshot.docs.first;
        final reportData = doc.data();
        _showAnonymousReportStatus(reportData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error looking up report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLookingUp = false;
        });
      }
    }
  }

  /// Show anonymous report status in a bottom sheet
  void _showAnonymousReportStatus(Map<String, dynamic> reportData) {
    final status = (reportData['status'] ?? 'pending').toString();
    final category = reportData['category'] ?? reportData['incidentType'] ?? 'Report';
    final description = reportData['description'] ?? '';
    final date = reportData['date'];
    final createdAt = reportData['createdAt'];
    final resolutionMessage = reportData['resolutionMessage'];
    final resolvedAt = reportData['resolvedAt'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                const Center(
                  child: Text(
                    'Anonymous Report Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Status card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getStatusColor(status).withOpacity(0.1),
                        _getStatusColor(status).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _getStatusColor(status).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getStatusIcon(status),
                          color: _getStatusColor(status),
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        status.substring(0, 1).toUpperCase() + status.substring(1).toLowerCase(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: _getStatusColor(status),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getStatusDescription(status),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Report details
                _buildDetailRow(Icons.category_rounded, 'Type', category.toString()),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.calendar_today_rounded,
                  'Incident Date',
                  date != null ? _formatDateString(date) : 'N/A',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.access_time_rounded,
                  'Submitted',
                  createdAt != null ? _formatDate(createdAt) : 'N/A',
                ),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.description_rounded,
                  'Description',
                  description.toString(),
                  isMultiLine: true,
                ),

                // Resolution message (shown when report is resolved/closed)
                if (resolutionMessage != null &&
                    resolutionMessage is String &&
                    resolutionMessage.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildResolutionCard(resolutionMessage, resolvedAt),
                ],

                const SizedBox(height: 24),

                // Close button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mustBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, {bool isMultiLine = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.mustBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'investigating':
        return Icons.search_rounded;
      case 'resolved':
        return Icons.check_circle_rounded;
      case 'closed':
        return Icons.archive_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  String _getStatusDescription(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Your report has been received and is awaiting review.';
      case 'investigating':
        return 'Your report is currently being investigated.';
      case 'resolved':
        return 'Your report has been resolved. Thank you for reporting.';
      case 'closed':
        return 'This report has been closed.';
      default:
        return 'Your report is being processed.';
    }
  }

  Widget _buildResolutionCard(String resolutionMessage, dynamic resolvedAt) {
    String resolvedDate = '';
    if (resolvedAt != null && resolvedAt is Timestamp) {
      final dt = resolvedAt.toDate();
      resolvedDate = '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.08),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resolution',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (resolvedDate.isNotEmpty)
                        Text(
                          'Resolved on $resolvedDate',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              resolutionMessage,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[800],
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.amber;
      case 'investigating':
        return Colors.blue;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.amber;
    }
  }
}
