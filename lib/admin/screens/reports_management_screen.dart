import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';
import '../../models/admin_user.dart';

class ReportsManagementScreen extends StatefulWidget {
  final AdminUser admin;

  const ReportsManagementScreen({super.key, required this.admin});

  @override
  State<ReportsManagementScreen> createState() =>
      _ReportsManagementScreenState();
}

class _ReportsManagementScreenState extends State<ReportsManagementScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedStatus = 'all';

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
    'pending': Colors.yellow,
    'submitted': Colors.blue,
    'under_review': Colors.orange,
    'investigating': Colors.purple,
    'resolved': Colors.green,
    'closed': Colors.grey,
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateReportStatus(String reportId, String newStatus, {String? resolutionMessage}) async {
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
      };

      // Add resolution details if provided
      if (resolutionMessage != null && resolutionMessage.isNotEmpty) {
        updateData['resolutionMessage'] = resolutionMessage;
        updateData['resolvedAt'] = FieldValue.serverTimestamp();
        updateData['resolvedBy'] = widget.admin.uid;
      }

      // Update report status
      await _firestore.collection('reports').doc(reportId).update(updateData);

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
            notificationBody = resolutionMessage != null && resolutionMessage.isNotEmpty
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

  Future<void> _showResolutionDialog(String reportId) async {
    final resolutionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.check_circle_outline, color: Colors.green, size: 24),
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
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.4),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: resolutionController,
                  maxLines: 5,
                  maxLength: 1000,
                  decoration: InputDecoration(
                    hintText: 'e.g., The incident has been investigated and appropriate disciplinary action has been taken...',
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
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );

    resolutionController.dispose();

    if (result != null) {
      await _updateReportStatus(reportId, 'resolved', resolutionMessage: result);
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

              return Dialog(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Report Details',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),

                      // Content
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDetailSection('Report Information', [
                                _buildDetailRow('Report ID', reportDoc.id),
                                _buildDetailRow('Type', data['type'] ?? 'N/A'),
                                _buildDetailRow(
                                  'Status',
                                  _statusLabels[data['status']] ??
                                      data['status'] ??
                                      'N/A',
                                ),
                                _buildDetailRow(
                                  'Submitted Date',
                                  data['createdAt'] != null
                                      ? DateFormat(
                                        'MMM dd, yyyy hh:mm a',
                                      ).format(
                                        (data['createdAt'] as Timestamp)
                                            .toDate(),
                                      )
                                      : 'N/A',
                                ),
                                _buildDetailRow(
                                  'Anonymous Report',
                                  (data['isAnonymous'] == true) ? 'Yes' : 'No',
                                ),
                              ]),
                              const SizedBox(height: 20),

                              if (data['isAnonymous'] != true) ...[
                                _buildDetailSection('Reporter Information', [
                                  _buildDetailRow(
                                    'Full Name',
                                    userData?['fullName'] ??
                                        data['reporterName'] ??
                                        'N/A',
                                  ),
                                  _buildDetailRow(
                                    'Email Address',
                                    userData?['email'] ??
                                        data['reporterEmail'] ??
                                        'N/A',
                                  ),
                                  _buildDetailRow(
                                    'Phone Number',
                                    userData?['phoneNumber'] ??
                                        data['reporterPhone'] ??
                                        'N/A',
                                  ),
                                  if (userData?['studentId'] != null ||
                                      data['studentId'] != null)
                                    _buildDetailRow(
                                      'Student ID',
                                      userData?['studentId'] ??
                                          data['studentId'] ??
                                          'N/A',
                                    ),
                                  if (userData?['faculty'] != null ||
                                      data['faculty'] != null)
                                    _buildDetailRow(
                                      'Faculty',
                                      userData?['faculty'] ??
                                          data['faculty'] ??
                                          'N/A',
                                    ),
                                ]),
                                const SizedBox(height: 20),
                              ],

                              _buildDetailSection('Incident Details', [
                                _buildDetailRow(
                                  'Incident Location',
                                  data['location'] ?? 'N/A',
                                ),
                                _buildDetailRow(
                                  'Date of Incident',
                                  data['incidentDate'] != null
                                      ? DateFormat('MMM dd, yyyy').format(
                                        (data['incidentDate'] as Timestamp)
                                            .toDate(),
                                      )
                                      : (data['incidentDateString'] ?? 'N/A'),
                                ),
                                _buildDetailRow(
                                  'Time of Incident',
                                  data['incidentTime'] ?? 'N/A',
                                ),
                                if (data['witnessName'] != null &&
                                    data['witnessName'].toString().isNotEmpty)
                                  _buildDetailRow(
                                    'Witness Name',
                                    data['witnessName'] ?? 'N/A',
                                  ),
                                if (data['witnessContact'] != null &&
                                    data['witnessContact']
                                        .toString()
                                        .isNotEmpty)
                                  _buildDetailRow(
                                    'Witness Contact',
                                    data['witnessContact'] ?? 'N/A',
                                  ),
                              ]),
                              const SizedBox(height: 20),

                              _buildDetailSection('Incident Description', [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Text(
                                    data['description'] ??
                                        'No description provided',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 20),

                              if (data['evidenceUrls'] != null &&
                                  (data['evidenceUrls'] as List)
                                      .isNotEmpty) ...[
                                _buildDetailSection('Evidence', [
                                  Text(
                                    '${(data['evidenceUrls'] as List).length} file(s) attached',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ]),
                                const SizedBox(height: 20),
                              ],

                              // Resolution Message (if resolved)
                              if (data['resolutionMessage'] != null &&
                                  (data['resolutionMessage'] as String).isNotEmpty) ...[
                                _buildDetailSection('Resolution', [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green[200]!,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(Icons.task_alt_rounded,
                                                color: Colors.green[700], size: 18),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Resolution Message',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.green[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          data['resolutionMessage'],
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                          ),
                                        ),
                                        if (data['resolvedAt'] != null) ...[
                                          const SizedBox(height: 8),
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
                                ]),
                                const SizedBox(height: 20),
                              ],

                              // Status Update Section
                              if (widget.admin.canManageReports()) ...[
                                const Divider(),
                                const SizedBox(height: 16),
                                const Text(
                                  'Update Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children:
                                      _statusLabels.entries
                                          .where((e) => e.key != 'all')
                                          .map((entry) {
                                            final isCurrentStatus =
                                                data['status'] == entry.key;
                                            return ElevatedButton(
                                              onPressed:
                                                  isCurrentStatus
                                                      ? null
                                                      : () {
                                                        if (entry.key == 'resolved') {
                                                          Navigator.pop(context);
                                                          _showResolutionDialog(
                                                            reportDoc.id,
                                                          );
                                                        } else {
                                                          _updateReportStatus(
                                                            reportDoc.id,
                                                            entry.key,
                                                          );
                                                          Navigator.pop(context);
                                                        }
                                                      },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    _statusColors[entry.key],
                                                foregroundColor: Colors.white,
                                                disabledBackgroundColor:
                                                    Colors.grey[300],
                                              ),
                                              child: Text(entry.value),
                                            );
                                          })
                                          .toList(),
                                ),
                              ],
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

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports Management'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by report ID, type, or location...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Status Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children:
                        _statusLabels.entries.map((entry) {
                          final isSelected = _selectedStatus == entry.key;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(entry.value),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedStatus = entry.key;
                                });
                              },
                              backgroundColor: Colors.grey[200],
                              selectedColor: AppColors.primaryBlue.withOpacity(
                                0.2,
                              ),
                              checkmarkColor: AppColors.primaryBlue,
                              labelStyle: TextStyle(
                                color:
                                    isSelected
                                        ? AppColors.primaryBlue
                                        : Colors.black87,
                                fontWeight:
                                    isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                              ),
                            ),
                          );
                        }).toList(),
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
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final reports =
                    snapshot.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      // Filter by status
                      if (_selectedStatus != 'all' &&
                          data['status'] != _selectedStatus) {
                        return false;
                      }

                      // Filter by search query
                      if (_searchQuery.isNotEmpty) {
                        final type = (data['type'] ?? '').toLowerCase();
                        final location = (data['location'] ?? '').toLowerCase();
                        final reportId = doc.id.toLowerCase();

                        if (!type.contains(_searchQuery) &&
                            !location.contains(_searchQuery) &&
                            !reportId.contains(_searchQuery)) {
                          return false;
                        }
                      }

                      return true;
                    }).toList();

                if (reports.isEmpty) {
                  return const Center(child: Text('No reports found'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final reportDoc = reports[index];
                    final data = reportDoc.data() as Map<String, dynamic>;
                    final status = data['status'] ?? 'submitted';
                    final statusColor = _statusColors[status] ?? Colors.grey;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: statusColor.withOpacity(0.3),
                          width: 2,
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
                          data['type'] ?? 'Report',
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
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
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
                            const SizedBox(height: 4),
                            if (data['isAnonymous'] == true)
                              Text(
                                'Anonymous',
                                style: TextStyle(
                                  fontSize: 11,
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
      ),
    );
  }
}
