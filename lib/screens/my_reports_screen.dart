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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        centerTitle: true,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = authSnapshot.data;

          if (user == null) {
            return _buildNotLoggedInView(context);
          }

          return _buildUserReportsView(context, user.uid);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportFormScreen()),
          );
        },
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildUserReportsView(BuildContext context, String userId) {
    return Column(
      children: [
        // Search and Filter Bar
        Container(
          color: AppColors.primaryBlue.withOpacity(0.05),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Search Box
              TextField(
                controller: _searchController,
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search reports...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.primaryBlue,
                  ),
                  suffixIcon:
                      _searchQuery.isNotEmpty
                          ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                          : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              // Filter and Sort Options
              Row(
                children: [
                  Expanded(
                    child: DropdownButton<String>(
                      value: _selectedStatus,
                      isExpanded: true,
                      underline: Container(),
                      items:
                          _statusOptions.map((status) {
                            return DropdownMenuItem(
                              value: status,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.filter_list,
                                      size: 16,
                                      color:
                                          status == 'All'
                                              ? AppColors.primaryBlue
                                              : _getStatusColor(status),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Status: $status',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedStatus = value ?? 'All';
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButton<String>(
                      value: _sortBy,
                      isExpanded: true,
                      underline: Container(),
                      items:
                          _sortOptions.map((sort) {
                            return DropdownMenuItem(
                              value: sort,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.sort,
                                      size: 16,
                                      color: AppColors.primaryBlue,
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
                              ),
                            );
                          }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _sortBy = value ?? 'Date (Newest)';
                        });
                      },
                    ),
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
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
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

  List<QueryDocumentSnapshot> _filterAndSortReports(
    List<QueryDocumentSnapshot> reports,
  ) {
    var filtered =
        reports.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final description =
              (data['description'] ?? '').toString().toLowerCase();
          final category = (data['category'] ?? '').toString().toLowerCase();
          final status = data['status'] ?? 'Pending';

          // Apply search filter
          final matchesSearch =
              _searchQuery.isEmpty ||
              description.contains(_searchQuery) ||
              category.contains(_searchQuery);

          // Apply status filter
          final matchesStatus =
              _selectedStatus == 'All' || status == _selectedStatus;

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
    final bool hasReports = _selectedStatus != 'All' || _searchQuery.isNotEmpty;

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  hasReports ? Icons.search_off : Icons.note_outlined,
                  size: 64,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                hasReports ? 'No Matching Reports' : 'No Reports Yet',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                hasReports
                    ? 'Try adjusting your search or filters.'
                    : 'You haven\'t submitted any reports yet.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed:
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReportFormScreen(),
                      ),
                    ),
                icon: const Icon(Icons.add),
                label: const Text('Create New Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
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
    final status = reportData['status'] ?? 'Pending';
    final category = reportData['category'] ?? 'Report';
    final description = reportData['description'] ?? '';
    final date = reportData['date'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => ReportDetailsScreen(
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getStatusColor(status).withOpacity(0.5),
                      ),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Date: ${_formatDate(date)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ReportDetailsScreen(
                              reportId: reportId,
                              reportData: reportData,
                            ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotLoggedInView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outlined,
                size: 64,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Login Required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Sign in to view your submitted reports.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('Sign In'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed:
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReportFormScreen(),
                    ),
                  ),
              child: const Text('Submit Anonymous Report Instead'),
            ),
          ],
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
