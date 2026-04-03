import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../constants/app_colors.dart';

class AnalyticsScreen extends StatefulWidget {
  final bool embedded;
  const AnalyticsScreen({super.key, this.embedded = false});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  final _firestore = FirebaseFirestore.instance;
  
  // Analytics data
  Map<String, int> _reportsByType = {};
  Map<String, int> _reportsByStatus = {};
  List<MapEntry<String, int>> _reportsOverTime = [];
  int _totalUsers = 0;
  int _totalReports = 0;
  int _totalAdmins = 0;
  int _activeUsers = 0;
  double _avgResponseTime = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);
    
    try {
      // Load all analytics data
      await Future.wait([
        _loadReportsByType(),
        _loadReportsByStatus(),
        _loadReportsOverTime(),
        _loadUserStats(),
        _loadResponseTime(),
      ]);
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _loadReportsByType() async {
    final reports = await _firestore.collection('reports').get();
    final typeCount = <String, int>{};
    
    for (var doc in reports.docs) {
      final type = doc.data()['type'] as String? ?? 'Unknown';
      typeCount[type] = (typeCount[type] ?? 0) + 1;
    }
    
    setState(() {
      _reportsByType = typeCount;
      _totalReports = reports.docs.length;
    });
  }

  Future<void> _loadReportsByStatus() async {
    final reports = await _firestore.collection('reports').get();
    final statusCount = <String, int>{};
    
    for (var doc in reports.docs) {
      final status = doc.data()['status'] as String? ?? 'submitted';
      statusCount[status] = (statusCount[status] ?? 0) + 1;
    }
    
    setState(() => _reportsByStatus = statusCount);
  }

  Future<void> _loadReportsOverTime() async {
    final reports = await _firestore
        .collection('reports')
        .orderBy('createdAt', descending: false)
        .get();
    
    final monthCount = <String, int>{};
    
    for (var doc in reports.docs) {
      final timestamp = doc.data()['createdAt'] as Timestamp?;
      if (timestamp != null) {
        final date = timestamp.toDate();
        final monthKey = DateFormat('MMM yyyy').format(date);
        monthCount[monthKey] = (monthCount[monthKey] ?? 0) + 1;
      }
    }
    
    setState(() {
      _reportsOverTime = monthCount.entries.toList();
    });
  }

  Future<void> _loadUserStats() async {
    final users = await _firestore.collection('users').get();
    final admins = await _firestore.collection('admins').get();
    
    int activeCount = 0;
    for (var doc in users.docs) {
      final isActive = doc.data()['isActive'] as bool? ?? true;
      if (isActive) activeCount++;
    }
    
    setState(() {
      _totalUsers = users.docs.length;
      _totalAdmins = admins.docs.length;
      _activeUsers = activeCount;
    });
  }

  Future<void> _loadResponseTime() async {
    final reports = await _firestore
        .collection('reports')
        .where('status', whereIn: ['resolved', 'closed'])
        .get();
    
    if (reports.docs.isEmpty) {
      setState(() => _avgResponseTime = 0);
      return;
    }
    
    double totalHours = 0;
    int count = 0;
    
    for (var doc in reports.docs) {
      final createdAt = doc.data()['createdAt'] as Timestamp?;
      final updatedAt = doc.data()['updatedAt'] as Timestamp?;
      
      if (createdAt != null && updatedAt != null) {
        final diff = updatedAt.toDate().difference(createdAt.toDate());
        totalHours += diff.inHours;
        count++;
      }
    }
    
    setState(() {
      _avgResponseTime = count > 0 ? totalHours / count : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? const Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryGreen,
            ),
          )
        : RefreshIndicator(
              onRefresh: _loadAnalytics,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    
                    // Charts Section
                    Text(
                      'Detailed Analytics',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Reports by Type
                    _buildReportsByTypeChart(),
                    const SizedBox(height: 24),
                    
                    // Reports by Status
                    _buildReportsByStatusChart(),
                    const SizedBox(height: 24),
                    
                    // Reports Over Time
                    _buildReportsOverTimeChart(),
                    const SizedBox(height: 24),
                    
                    // Additional Metrics
                    _buildAdditionalMetrics(),
                  ],
                ),
              ),
            );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Analytics Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildSummaryCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: cardCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              'Total Reports',
              _totalReports.toString(),
              Icons.report,
              AppColors.primaryGreen,
            ),
            _buildMetricCard(
              'Total Users',
              _totalUsers.toString(),
              Icons.people,
              AppColors.mustGreen,
            ),
            _buildMetricCard(
              'Active Users',
              _activeUsers.toString(),
              Icons.verified_user,
              AppColors.secondaryOrange,
            ),
            _buildMetricCard(
              'Avg Response Time',
              '${_avgResponseTime.toStringAsFixed(1)}h',
              Icons.timer,
              AppColors.primaryDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsByTypeChart() {
    if (_reportsByType.isEmpty) {
      return _buildEmptyChart('No report type data available');
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports by Type',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: PieChart(
                      PieChartData(
                        sections: _reportsByType.entries.map((entry) {
                          final index = _reportsByType.keys.toList().indexOf(entry.key);
                          return PieChartSectionData(
                            value: entry.value.toDouble(),
                            title: '${entry.value}',
                            color: _getChartColor(index),
                            radius: 100,
                            titleStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildLegend(_reportsByType),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsByStatusChart() {
    if (_reportsByStatus.isEmpty) {
      return _buildEmptyChart('No status data available');
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports by Status',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: _reportsByStatus.values.reduce((a, b) => a > b ? a : b).toDouble() * 1.2,
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final statuses = _reportsByStatus.keys.toList();
                          if (value.toInt() >= 0 && value.toInt() < statuses.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _formatStatus(statuses[value.toInt()]),
                                style: const TextStyle(fontSize: 10),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: _reportsByStatus.entries.toList().asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.value.toDouble(),
                          color: _getStatusColor(entry.value.key),
                          width: 30,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsOverTimeChart() {
    if (_reportsOverTime.isEmpty) {
      return _buildEmptyChart('No time-series data available');
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reports Over Time',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: _reportsOverTime.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.value.toDouble());
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primaryGreen,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primaryGreen.withOpacity(0.2),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < _reportsOverTime.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                _reportsOverTime[value.toInt()].key,
                                style: const TextStyle(fontSize: 9),
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  gridData: const FlGridData(show: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdditionalMetrics() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildMetricRow('Total Administrators', _totalAdmins.toString()),
            const Divider(),
            _buildMetricRow('Active Users', '$_activeUsers / $_totalUsers'),
            const Divider(),
            _buildMetricRow('Inactive Users', '${_totalUsers - _activeUsers}'),
            const Divider(),
            _buildMetricRow(
              'User Activation Rate',
              '${(_totalUsers > 0 ? (_activeUsers / _totalUsers * 100) : 0).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Map<String, int> data) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: data.entries.toList().asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _getChartColor(index),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.key,
                  style: const TextStyle(fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyChart(String message) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: Container(
        height: 200,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics_outlined, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Color _getChartColor(int index) {
    final colors = [
      AppColors.primaryGreen,
      AppColors.secondaryOrange,
      AppColors.mustGreen,
      AppColors.primaryDark,
      AppColors.mustGreenLight,
      AppColors.secondaryDark,
      Colors.pink,
      Colors.amber,
    ];
    return colors[index % colors.length];
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return AppColors.primaryGreen;
      case 'under_review':
        return AppColors.secondaryOrange;
      case 'investigating':
        return AppColors.primaryDark;
      case 'resolved':
        return AppColors.mustGreen;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatStatus(String status) {
    return status.split('_').map((word) => 
      word[0].toUpperCase() + word.substring(1)
    ).join(' ');
  }
}
