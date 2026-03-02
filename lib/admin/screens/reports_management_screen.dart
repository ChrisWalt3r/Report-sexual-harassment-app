import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../models/admin_user.dart';
import '../../services/firebase_ai_report_service.dart';
import '../widgets/ai_insights_panel.dart';

class ReportsManagementScreen extends StatefulWidget {
  final AdminUser admin;
  final bool embedded;

  const ReportsManagementScreen({super.key, required this.admin, this.embedded = false});

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
  bool _anonymousOnly = false;
  DateTimeRange? _dateRange;

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
    'submitted': AppColors.mustBlue,
    'under_review': AppColors.mustGold,
    'investigating': AppColors.mustBlueMedium,
    'resolved': AppColors.mustGreen,
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
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
                          ),
                          borderRadius: BorderRadius.only(
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
                                if (data['isAnonymous'] == true && data['trackingToken'] != null)
                                  _buildTokenRow(data['trackingToken']),
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
                                      : (data['incidentDateString'] ?? data['date'] ?? 'N/A'),
                                ),
                                _buildDetailRow(
                                  'Time of Incident',
                                  data['incidentTime'] ?? data['time'] ?? 'N/A',
                                ),
                                if (data['perpetratorInfo'] != null &&
                                    data['perpetratorInfo'].toString().isNotEmpty)
                                  _buildDetailRow(
                                    'Person(s) Involved',
                                    data['perpetratorInfo'] ?? 'N/A',
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
                                if (data['witnesses'] != null &&
                                    data['witnesses'].toString().isNotEmpty)
                                  _buildDetailRow(
                                    'Witnesses',
                                    data['witnesses'] ?? 'N/A',
                                  ),
                              ]),
                              const SizedBox(height: 20),

                              // Complainant Response section (per MUST Policy Section 8.4)
                              if (data['complainantResponse'] != null &&
                                  data['complainantResponse'].toString().isNotEmpty) ...[
                                _buildDetailSection('Complainant Response', [
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue[200]!,
                                      ),
                                    ),
                                    child: Text(
                                      data['complainantResponse'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 20),
                              ],

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

                              // Evidence section - always show
                              Builder(builder: (context) {
                                final imageUrls = _getListFromData(data, 'imageUrls');
                                final videoUrls = _getListFromData(data, 'videoUrls');
                                final hasEvidence = imageUrls.isNotEmpty || videoUrls.isNotEmpty;

                                if (!hasEvidence) {
                                  return _buildDetailSection('Evidence', [
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.grey[200]!),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(Icons.folder_off, color: Colors.grey[400], size: 24),
                                          const SizedBox(width: 12),
                                          Text('No evidence files were submitted with this report',
                                              style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                                        ],
                                      ),
                                    ),
                                  ]);
                                }

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Photo Evidence
                                    if (imageUrls.isNotEmpty) ...[
                                      _buildDetailSection('Photo Evidence (${imageUrls.length})', [
                                        SizedBox(
                                          height: 180,
                                          child: ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: imageUrls.length,
                                            itemBuilder: (context, imgIndex) {
                                              final url = imageUrls[imgIndex];
                                              return Padding(
                                                padding: const EdgeInsets.only(right: 10),
                                                child: GestureDetector(
                                                  onTap: () => _showFullImage(context, url, imgIndex + 1),
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(10),
                                                    child: Stack(
                                                      children: [
                                                        Image.network(
                                                          url,
                                                          width: 160,
                                                          height: 180,
                                                          fit: BoxFit.cover,
                                                          loadingBuilder: (context, child, progress) {
                                                            if (progress == null) return child;
                                                            return Container(
                                                              width: 160, height: 180,
                                                              color: Colors.grey[100],
                                                              child: Center(
                                                                child: CircularProgressIndicator(
                                                                  value: progress.expectedTotalBytes != null
                                                                      ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                                                      : null,
                                                                  strokeWidth: 2,
                                                                  color: AppColors.mustGold,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                          errorBuilder: (context, error, stack) => Container(
                                                            width: 160, height: 180,
                                                            color: Colors.grey[200],
                                                            child: Column(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Icon(Icons.broken_image, color: Colors.grey[400], size: 36),
                                                                const SizedBox(height: 4),
                                                                Text('Load failed', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                                                                const SizedBox(height: 4),
                                                                InkWell(
                                                                  onTap: () async {
                                                                    final uri = Uri.parse(url);
                                                                    if (await canLaunchUrl(uri)) {
                                                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                                    }
                                                                  },
                                                                  child: Text('Open link', style: TextStyle(fontSize: 11, color: AppColors.mustBlue, decoration: TextDecoration.underline)),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                        Positioned(
                                                          bottom: 0, left: 0, right: 0,
                                                          child: Container(
                                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                                            decoration: const BoxDecoration(
                                                              gradient: LinearGradient(
                                                                begin: Alignment.bottomCenter,
                                                                end: Alignment.topCenter,
                                                                colors: [Colors.black54, Colors.transparent],
                                                              ),
                                                            ),
                                                            child: Row(
                                                              mainAxisAlignment: MainAxisAlignment.center,
                                                              children: [
                                                                Icon(Icons.zoom_in, size: 14, color: Colors.white70),
                                                                const SizedBox(width: 4),
                                                                Text('Tap to view', style: TextStyle(fontSize: 10, color: Colors.white70)),
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
                                      ]),
                                      const SizedBox(height: 20),
                                    ],

                                    // Video Evidence
                                    if (videoUrls.isNotEmpty) ...[
                                      _buildDetailSection('Video Evidence (${videoUrls.length})', [
                                        ...videoUrls.asMap().entries.map((entry) {
                                          final videoUrl = entry.value;
                                          final videoNum = entry.key + 1;
                                          return Padding(
                                            padding: const EdgeInsets.only(bottom: 8),
                                            child: InkWell(
                                              onTap: () async {
                                                final uri = Uri.parse(videoUrl);
                                                if (await canLaunchUrl(uri)) {
                                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                                }
                                              },
                                              borderRadius: BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                decoration: BoxDecoration(
                                                  color: AppColors.mustBlue.withOpacity(0.05),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: AppColors.mustBlue.withOpacity(0.2)),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.mustBlue.withOpacity(0.1),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Icon(Icons.videocam, color: AppColors.mustBlue, size: 22),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('Video $videoNum', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                                          const SizedBox(height: 2),
                                                          Text('Tap to open in browser', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                                        ],
                                                      ),
                                                    ),
                                                    Icon(Icons.open_in_new, color: AppColors.mustBlue.withOpacity(0.6), size: 20),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                      ]),
                                      const SizedBox(height: 20),
                                    ],
                                  ],
                                );
                              }),

                              // AI Insights Panel
                              if (widget.admin.canManageReports()) ...[                                AIInsightsPanel(
                                  reportData: data,
                                  reportId: reportDoc.id,
                                  currentStatus: data['status'] ?? 'submitted',
                                ),
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

  Widget _buildTokenRow(String token) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              'Tracking Token:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.mustGold.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.mustGold.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.vpn_key, size: 16, color: AppColors.mustGold),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      token,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: AppColors.mustBlue,
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
      builder: (context) => Dialog(
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
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                            : null,
                        color: AppColors.mustGold,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stack) => Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        Text('Failed to load image', style: TextStyle(color: Colors.grey[600])),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black54, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Text('Image $imageNum', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.open_in_new, color: Colors.white, size: 22),
                      tooltip: 'Open in browser',
                      onPressed: () async {
                        final uri = Uri.parse(url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 24),
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
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.mustBlue,
            onPrimary: Colors.white,
            secondary: AppColors.mustGold,
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
      builder: (context) => _TrendAnalysisDialog(aiService: aiService, firestore: _firestore),
    );
  }

  bool get _hasActiveFilters =>
      _selectedStatus != 'all' ||
      _selectedFaculty != 'all' ||
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
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
          ),
          child: Column(
            children: [
              // Search bar
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by ID, type, location, or tracking token...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: () { _searchController.clear(); setState(() => _searchQuery = ''); })
                      : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.mustBlue, width: 2)),
                  filled: true,
                  fillColor: Colors.grey[50],
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              ),
              const SizedBox(height: 12),

              // Filter row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Status dropdown
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _selectedStatus != 'all' ? AppColors.mustGold.withOpacity(0.1) : Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _selectedStatus != 'all' ? AppColors.mustGold : Colors.grey[300]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          isDense: true,
                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                          style: TextStyle(fontSize: 13, color: _selectedStatus != 'all' ? AppColors.mustBlue : Colors.grey[700], fontWeight: _selectedStatus != 'all' ? FontWeight.w600 : FontWeight.normal),
                          items: _statusLabels.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                          onChanged: (val) => setState(() => _selectedStatus = val ?? 'all'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Date range
                    InkWell(
                      onTap: _pickDateRange,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _dateRange != null ? AppColors.mustGold.withOpacity(0.1) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _dateRange != null ? AppColors.mustGold : Colors.grey[300]!),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_today, size: 16, color: _dateRange != null ? AppColors.mustBlue : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                            _dateRange != null
                                ? '${DateFormat('MMM d').format(_dateRange!.start)} - ${DateFormat('MMM d').format(_dateRange!.end)}'
                                : 'Date Range',
                            style: TextStyle(fontSize: 13, color: _dateRange != null ? AppColors.mustBlue : Colors.grey[600], fontWeight: _dateRange != null ? FontWeight.w600 : FontWeight.normal),
                          ),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Anonymous toggle
                    InkWell(
                      onTap: () => setState(() => _anonymousOnly = !_anonymousOnly),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _anonymousOnly ? AppColors.mustGold.withOpacity(0.1) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _anonymousOnly ? AppColors.mustGold : Colors.grey[300]!),
                        ),
                        child: Row(children: [
                          Icon(Icons.visibility_off, size: 16, color: _anonymousOnly ? AppColors.mustBlue : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text('Anonymous', style: TextStyle(fontSize: 13, color: _anonymousOnly ? AppColors.mustBlue : Colors.grey[600], fontWeight: _anonymousOnly ? FontWeight.w600 : FontWeight.normal)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // AI Trend Analysis
                    InkWell(
                      onTap: () => _showTrendAnalysis(),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.mustBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.mustBlue.withOpacity(0.3)),
                        ),
                        child: Row(children: [
                          Icon(Icons.auto_awesome, size: 16, color: AppColors.mustBlue),
                          const SizedBox(width: 6),
                          Text('AI Trends', style: TextStyle(fontSize: 13, color: AppColors.mustBlue, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Clear all
                    if (_hasActiveFilters)
                      InkWell(
                        onTap: _clearFilters,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red[200]!)),
                          child: Row(children: [
                            Icon(Icons.clear_all, size: 16, color: Colors.red[700]),
                            const SizedBox(width: 4),
                            Text('Clear All', style: TextStyle(fontSize: 13, color: Colors.red[700], fontWeight: FontWeight.w600)),
                          ]),
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
            stream: _firestore.collection('reports').orderBy('createdAt', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

              final reports = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;

                // Status filter
                if (_selectedStatus != 'all' && data['status'] != _selectedStatus) return false;

                // Anonymous filter
                if (_anonymousOnly && data['isAnonymous'] != true) return false;

                // Date range filter
                if (_dateRange != null && data['createdAt'] != null) {
                  final createdAt = (data['createdAt'] as Timestamp).toDate();
                  if (createdAt.isBefore(_dateRange!.start) || createdAt.isAfter(_dateRange!.end.add(const Duration(days: 1)))) return false;
                }

                // Search (includes tracking token search)
                if (_searchQuery.isNotEmpty) {
                  final type = (data['type'] ?? '').toLowerCase();
                  final location = (data['location'] ?? '').toLowerCase();
                  final reportId = doc.id.toLowerCase();
                  final token = (data['trackingToken'] ?? '').toLowerCase();

                  if (!type.contains(_searchQuery) &&
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
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.search_off, size: 56, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('No reports found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                    if (_hasActiveFilters) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _clearFilters,
                        icon: const Icon(Icons.clear_all),
                        label: const Text('Clear Filters'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.mustBlue),
                      ),
                    ],
                  ]),
                );
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
                      side: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.report, color: statusColor),
                      ),
                      title: Text(data['type'] ?? 'Report', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text('Location: ${data['location'] ?? 'N/A'}'),
                          const SizedBox(height: 2),
                          Text(
                            data['createdAt'] != null
                                ? DateFormat('MMM dd, yyyy').format((data['createdAt'] as Timestamp).toDate())
                                : 'N/A',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          if (data['isAnonymous'] == true && data['trackingToken'] != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.vpn_key, size: 12, color: AppColors.mustGold),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  data['trackingToken'],
                                  style: TextStyle(fontSize: 11, color: AppColors.mustGold, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ]),
                          ],
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withOpacity(0.5)),
                            ),
                            child: Text(_statusLabels[status] ?? status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                          ),
                          const SizedBox(height: 4),
                          if (data['isAnonymous'] == true)
                            Text('Anonymous', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic)),
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
        title: const Text('Reports Management', style: TextStyle(fontWeight: FontWeight.bold)),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.mustBlue, AppColors.mustBlueMedium]),
          ),
        ),
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

  const _TrendAnalysisDialog({required this.aiService, required this.firestore});

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
      final snapshot = await widget.firestore
          .collection('reports')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final reportsData = snapshot.docs.map((doc) {
        final data = doc.data();
        // Convert Timestamp to string for AI context
        if (data['createdAt'] != null) {
          data['createdAt'] = (data['createdAt'] as Timestamp).toDate().toString();
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
                gradient: LinearGradient(
                  colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.mustGold, size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('AI Trend Analysis',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('Cross-report pattern recognition powered by Gemini',
                            style: TextStyle(fontSize: 12, color: Colors.white70)),
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
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppColors.mustBlue),
                          SizedBox(height: 16),
                          Text('Analyzing report trends...', style: TextStyle(color: Colors.grey)),
                          SizedBox(height: 4),
                          Text('This may take a moment', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 40, color: Colors.red[300]),
                              const SizedBox(height: 12),
                              Text('Analysis failed', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red[700])),
                              const SizedBox(height: 6),
                              Text(_error!, style: const TextStyle(color: Colors.grey, fontSize: 12), textAlign: TextAlign.center),
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
                                  backgroundColor: AppColors.mustBlue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: SelectableText(
                            _trendResult ?? '',
                            style: const TextStyle(fontSize: 14, height: 1.6),
                          ),
                        ),
            ),

            // Footer
            if (_trendResult != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                            const SnackBar(content: Text('Trend analysis copied to clipboard')));
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.mustBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
