import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:html' as html;
import 'dart:convert';
import '../../constants/app_colors.dart';

class DataExportScreen extends StatefulWidget {
  final bool embedded;
  const DataExportScreen({super.key, this.embedded = false});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isExporting = false;
  String _exportStatus = '';

  Future<void> _exportReports({required String format}) async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'Fetching reports...';
    });

    try {
      final reports = await _firestore.collection('reports').get();
      setState(
        () => _exportStatus = 'Processing ${reports.docs.length} reports...',
      );

      if (format == 'csv') {
        // Create CSV content
        final csvRows = <String>[];
        // Header
        csvRows.add(
          'Report ID,Type,Status,Location,Date,Time,Anonymous,Reporter Name,Reporter Email,Description,Created At,Updated At',
        );
        // Data rows
        for (var doc in reports.docs) {
          final data = doc.data();
          final row = [
            doc.id,
            data['type'] ?? '',
            data['status'] ?? '',
            data['location'] ?? '',
            data['incidentDate'] ?? '',
            data['incidentTime'] ?? '',
            (data['isAnonymous'] ?? false).toString(),
            data['isAnonymous'] == true
                ? 'Anonymous'
                : (data['reporterName'] ?? ''),
            data['isAnonymous'] == true ? '' : (data['reporterEmail'] ?? ''),
            _cleanCSVField(data['description'] ?? ''),
            _formatTimestamp(data['createdAt']),
            _formatTimestamp(data['updatedAt']),
          ];
          csvRows.add(
            row
                .map((field) => '"${field.toString().replaceAll('"', '""')}"')
                .join(','),
          );
        }
        final csvContent = csvRows.join('\n');
        setState(() => _exportStatus = 'Preparing download...');
        // Create and download file
        final bytes = utf8.encode(csvContent);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'reports_${DateTime.now().millisecondsSinceEpoch}.csv',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        setState(() {
          _isExporting = false;
          _exportStatus =
              'Successfully exported ${reports.docs.length} reports!';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ${reports.docs.length} reports')),
          );
        }
      } else if (format == 'json') {
        setState(() => _exportStatus = 'Generating JSON...');
        final reportsJson =
            reports.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'createdAt': _formatTimestamp(data['createdAt']),
                'updatedAt': _formatTimestamp(data['updatedAt']),
              };
            }).toList();
        final payload = {
          'generated_at': DateTime.now().toIso8601String(),
          'total_reports': reports.docs.length,
          'reports': reportsJson,
        };
        final jsonContent = JsonEncoder.withIndent('  ').convert(payload);
        final bytes = utf8.encode(jsonContent);
        final blob = html.Blob([bytes], 'application/json');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'reports_${DateTime.now().millisecondsSinceEpoch}.json',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        setState(() {
          _isExporting = false;
          _exportStatus =
              'Successfully exported ${reports.docs.length} reports as JSON!';
        });
      } else if (format == 'pdf' || format == 'pdf_summary') {
        final isSummary = format == 'pdf_summary';
        setState(
          () =>
              _exportStatus =
                  isSummary
                      ? 'Generating summary PDF...'
                      : 'Generating detailed PDF...',
        );
        final pdf = pw.Document();
        final statusSummary = _groupBy(reports.docs, 'status');

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (pw.Context context) {
              if (isSummary) {
                final recentReports = reports.docs.take(20).toList();
                return [
                  pw.Text(
                    'Reports Summary Export',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                  ),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    'Total Reports: ${reports.docs.length}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    'Reports by Status',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  ...statusSummary.entries.map(
                    (entry) => pw.Bullet(text: '${entry.key}: ${entry.value}'),
                  ),
                  pw.SizedBox(height: 14),
                  pw.Text(
                    'Most Recent Reports (up to 20)',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  ...recentReports.map((doc) {
                    final data = doc.data();
                    return pw.Container(
                      margin: const pw.EdgeInsets.only(bottom: 8),
                      padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(color: PdfColors.grey400),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${data['type'] ?? 'Unknown'} (${data['status'] ?? 'submitted'})',
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                          pw.SizedBox(height: 4),
                          pw.Text('Location: ${data['location'] ?? 'N/A'}'),
                          pw.Text(
                            'Date: ${data['incidentDate'] ?? 'N/A'} ${data['incidentTime'] ?? ''}',
                          ),
                          pw.Text(
                            'Anonymous: ${(data['isAnonymous'] ?? false) ? 'Yes' : 'No'}',
                          ),
                        ],
                      ),
                    );
                  }),
                ];
              }

              return [
                pw.Text(
                  'Reports Export',
                  style: pw.TextStyle(
                    fontSize: 22,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Table.fromTextArray(
                  headers: [
                    'Report ID',
                    'Type',
                    'Status',
                    'Location',
                    'Date',
                    'Time',
                    'Anonymous',
                    'Reporter Name',
                    'Reporter Email',
                    'Description',
                    'Created At',
                    'Updated At',
                  ],
                  data:
                      reports.docs.map((doc) {
                        final data = doc.data();
                        return [
                          doc.id,
                          data['type'] ?? '',
                          data['status'] ?? '',
                          data['location'] ?? '',
                          data['incidentDate'] ?? '',
                          data['incidentTime'] ?? '',
                          (data['isAnonymous'] ?? false).toString(),
                          data['isAnonymous'] == true
                              ? 'Anonymous'
                              : (data['reporterName'] ?? ''),
                          data['isAnonymous'] == true
                              ? ''
                              : (data['reporterEmail'] ?? ''),
                          (data['description'] ?? '')
                              .toString()
                              .replaceAll('\n', ' ')
                              .replaceAll('\r', ' '),
                          _formatTimestamp(data['createdAt']),
                          _formatTimestamp(data['updatedAt']),
                        ];
                      }).toList(),
                  cellStyle: pw.TextStyle(fontSize: 8),
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 9,
                  ),
                  headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
              ];
            },
          ),
        );

        final pdfBytes = await pdf.save();
        final blob = html.Blob([
          Uint8List.fromList(pdfBytes),
        ], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            isSummary
                ? 'reports_summary_${DateTime.now().millisecondsSinceEpoch}.pdf'
                : 'reports_${DateTime.now().millisecondsSinceEpoch}.pdf',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        setState(() {
          _isExporting = false;
          _exportStatus =
              isSummary
                  ? 'Successfully exported summary PDF for ${reports.docs.length} reports!'
                  : 'Successfully exported detailed PDF with ${reports.docs.length} reports!';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isSummary
                    ? 'Exported summary PDF for ${reports.docs.length} reports'
                    : 'Exported detailed PDF for ${reports.docs.length} reports',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportStatus = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportUsers({required String format}) async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'Fetching users...';
    });

    try {
      final users = await _firestore.collection('users').get();
      setState(
        () => _exportStatus = 'Processing ${users.docs.length} users...',
      );

      if (format == 'csv') {
        // Create CSV content
        final csvRows = <String>[];
        // Header
        csvRows.add(
          'User ID,Full Name,Email,Student ID,Faculty,Phone,Is Active,Created At',
        );
        // Data rows
        for (var doc in users.docs) {
          final data = doc.data();
          final row = [
            doc.id,
            data['fullName'] ?? '',
            data['email'] ?? '',
            data['studentId'] ?? '',
            data['faculty'] ?? '',
            data['phoneNumber'] ?? '',
            (data['isActive'] ?? true).toString(),
            _formatTimestamp(data['createdAt']),
          ];
          csvRows.add(
            row
                .map((field) => '"${field.toString().replaceAll('"', '""')}"')
                .join(','),
          );
        }
        final csvContent = csvRows.join('\n');
        setState(() => _exportStatus = 'Preparing download...');
        // Create and download file
        final bytes = utf8.encode(csvContent);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'users_${DateTime.now().millisecondsSinceEpoch}.csv',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        setState(() {
          _isExporting = false;
          _exportStatus = 'Successfully exported ${users.docs.length} users!';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exported ${users.docs.length} users')),
          );
        }
      } else if (format == 'json') {
        setState(() => _exportStatus = 'Generating users JSON...');
        final usersJson =
            users.docs.map((doc) {
              final data = doc.data();
              return {
                'id': doc.id,
                ...data,
                'createdAt': _formatTimestamp(data['createdAt']),
              };
            }).toList();
        final payload = {
          'generated_at': DateTime.now().toIso8601String(),
          'total_users': users.docs.length,
          'users': usersJson,
        };
        final jsonContent = JsonEncoder.withIndent('  ').convert(payload);
        final bytes = utf8.encode(jsonContent);
        final blob = html.Blob([bytes], 'application/json');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'users_${DateTime.now().millisecondsSinceEpoch}.json',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        setState(() {
          _isExporting = false;
          _exportStatus =
              'Successfully exported ${users.docs.length} users as JSON!';
        });
      } else if (format == 'pdf') {
        setState(() => _exportStatus = 'Generating users PDF...');
        final pdf = pw.Document();
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build:
                (context) => [
                  pw.Text(
                    'Users Export',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
                  ),
                  pw.SizedBox(height: 14),
                  pw.Table.fromTextArray(
                    headers: const [
                      'User ID',
                      'Full Name',
                      'Email',
                      'Student ID',
                      'Faculty',
                      'Phone',
                      'Is Active',
                      'Created At',
                    ],
                    data:
                        users.docs.map((doc) {
                          final data = doc.data();
                          return [
                            doc.id,
                            data['fullName'] ?? '',
                            data['email'] ?? '',
                            data['studentId'] ?? '',
                            data['faculty'] ?? '',
                            data['phoneNumber'] ?? '',
                            (data['isActive'] ?? true) ? 'Yes' : 'No',
                            _formatTimestamp(data['createdAt']),
                          ];
                        }).toList(),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                    headerDecoration: pw.BoxDecoration(
                      color: PdfColors.grey300,
                    ),
                    cellAlignment: pw.Alignment.centerLeft,
                  ),
                ],
          ),
        );
        final pdfBytes = await pdf.save();
        final blob = html.Blob([
          Uint8List.fromList(pdfBytes),
        ], 'application/pdf');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute(
            'download',
            'users_${DateTime.now().millisecondsSinceEpoch}.pdf',
          )
          ..click();
        html.Url.revokeObjectUrl(url);
        setState(() {
          _isExporting = false;
          _exportStatus =
              'Successfully exported ${users.docs.length} users as PDF!';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Exported ${users.docs.length} users as PDF'),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportStatus = 'Error: $e';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportAnalyticsToJSON() async {
    setState(() {
      _isExporting = true;
      _exportStatus = 'Generating analytics...';
    });

    try {
      final reports = await _firestore.collection('reports').get();
      final users = await _firestore.collection('users').get();
      final admins = await _firestore.collection('admins').get();

      // Generate analytics data
      final analytics = {
        'generated_at': DateTime.now().toIso8601String(),
        'summary': {
          'total_reports': reports.docs.length,
          'total_users': users.docs.length,
          'total_admins': admins.docs.length,
        },
        'reports_by_type': _groupBy(reports.docs, 'type'),
        'reports_by_status': _groupBy(reports.docs, 'status'),
        'users_by_faculty': _groupBy(users.docs, 'faculty'),
      };

      setState(() => _exportStatus = 'Preparing download...');

      // Create and download file
      final jsonContent = JsonEncoder.withIndent('  ').convert(analytics);
      final bytes = utf8.encode(jsonContent);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute(
          'download',
          'analytics_${DateTime.now().millisecondsSinceEpoch}.json',
        )
        ..click();
      html.Url.revokeObjectUrl(url);

      setState(() {
        _isExporting = false;
        _exportStatus = 'Successfully exported analytics!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exported analytics data')),
        );
      }
    } catch (e) {
      setState(() {
        _isExporting = false;
        _exportStatus = 'Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Map<String, int> _groupBy(List<QueryDocumentSnapshot> docs, String field) {
    final groups = <String, int>{};
    for (var doc in docs) {
      final value = doc.data() as Map<String, dynamic>;
      final key = value[field]?.toString() ?? 'Unknown';
      groups[key] = (groups[key] ?? 0) + 1;
    }
    return groups;
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toDate());
    }
    return '';
  }

  String _cleanCSVField(String field) {
    return field.replaceAll('\n', ' ').replaceAll('\r', ' ');
  }

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_exportStatus.isNotEmpty) ...[
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.borderLight),
              ),
              color:
                  _isExporting
                      ? AppColors.primaryGreen.withOpacity(0.08)
                      : AppColors.primaryGreen.withOpacity(0.08),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (_isExporting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryGreen,
                        ),
                      )
                    else
                      Icon(Icons.check_circle, color: AppColors.primaryGreen),
                    const SizedBox(width: 16),
                    Expanded(child: Text(_exportStatus)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          Text(
            'Export Data',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Download data in various formats for analysis and record-keeping.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Export Reports
          _buildExportCard(
            title: 'Export Reports',
            description:
                'Download reports as detailed/summary PDF, CSV, or JSON',
            icon: Icons.description,
            color: AppColors.primaryGreen,
            onPressed:
                _isExporting
                    ? null
                    : () async {
                      final format = await showDialog<String>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Select Export Format'),
                              content: const Text(
                                'Choose the format you want to export reports in:',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, 'pdf'),
                                  child: const Text('PDF (Detailed)'),
                                ),
                                TextButton(
                                  onPressed:
                                      () =>
                                          Navigator.pop(context, 'pdf_summary'),
                                  child: const Text('PDF (Summary)'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, 'csv'),
                                  child: const Text('CSV'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, 'json'),
                                  child: const Text('JSON'),
                                ),
                              ],
                            ),
                      );
                      if (format != null) {
                        await _exportReports(format: format);
                      }
                    },
          ),
          const SizedBox(height: 16),

          // Export Users
          _buildExportCard(
            title: 'Export Users',
            description: 'Download all user data as PDF, CSV, or JSON',
            icon: Icons.people,
            color: AppColors.primaryGreen,
            onPressed:
                _isExporting
                    ? null
                    : () async {
                      final format = await showDialog<String>(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: const Text('Select Export Format'),
                              content: const Text(
                                'Choose the format you want to export users in:',
                              ),
                              actions: [
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, 'pdf'),
                                  child: const Text('PDF'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, 'csv'),
                                  child: const Text('CSV'),
                                ),
                                TextButton(
                                  onPressed:
                                      () => Navigator.pop(context, 'json'),
                                  child: const Text('JSON'),
                                ),
                              ],
                            ),
                      );
                      if (format != null) {
                        await _exportUsers(format: format);
                      }
                    },
          ),
          const SizedBox(height: 16),

          // Export Analytics
          _buildExportCard(
            title: 'Export Analytics',
            description: 'Download analytics summary as JSON file',
            icon: Icons.analytics,
            color: AppColors.secondaryOrange,
            onPressed: _isExporting ? null : _exportAnalyticsToJSON,
          ),
          const SizedBox(height: 32),

          Text(
            'Database Statistics',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          _buildDatabaseStats(),
          const SizedBox(height: 32),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.borderLight),
            ),
            color: AppColors.secondaryOrange.withOpacity(0.08),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.secondaryOrange,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Important Notes',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Exported files contain sensitive information. Handle with care.\n'
                    '• CSV files can be opened in Excel, Google Sheets, etc.\n'
                    '• JSON files are suitable for data analysis tools.\n'
                    '• Anonymous reports do not include reporter details.',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
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

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _buildBody();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Data Export & Management',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildExportCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.download,
                color: onPressed == null ? Colors.grey : color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDatabaseStats() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('reports').snapshots(),
      builder: (context, reportsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').snapshots(),
          builder: (context, usersSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('admins').snapshots(),
              builder: (context, adminsSnapshot) {
                final reportsCount = reportsSnapshot.data?.docs.length ?? 0;
                final usersCount = usersSnapshot.data?.docs.length ?? 0;
                final adminsCount = adminsSnapshot.data?.docs.length ?? 0;

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppColors.borderLight),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _buildStatRow(
                          'Total Reports',
                          reportsCount.toString(),
                          Icons.description,
                        ),
                        const Divider(),
                        _buildStatRow(
                          'Total Users',
                          usersCount.toString(),
                          Icons.people,
                        ),
                        const Divider(),
                        _buildStatRow(
                          'Total Admins',
                          adminsCount.toString(),
                          Icons.admin_panel_settings,
                        ),
                        const Divider(),
                        _buildStatRow(
                          'Total Records',
                          (reportsCount + usersCount + adminsCount).toString(),
                          Icons.storage,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryGreen, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryOrange,
            ),
          ),
        ],
      ),
    );
  }
}
