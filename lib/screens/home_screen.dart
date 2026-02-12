import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../widgets/bottom_nav_bar.dart';
import '../features/support_services/support_services.dart';
import '../features/support_services/screens/support_home_screen.dart';
import '../services/notification_service.dart';
import 'ai_powered_chat_screen.dart';
import 'emergency_screen.dart';
import 'settings_screen.dart';
import 'privacy_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentNavIndex = 0;
  final List<int> _tabHistory = [0];

  @override
  void initState() {
    super.initState();
    // Initialize notification service for the logged-in user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      notificationService.initialize(user.uid);
    }
  }

  bool _handleBackPress() {
    if (_tabHistory.length > 1) {
      _tabHistory.removeLast();
      setState(() {
        _currentNavIndex = _tabHistory.last;
      });
      return false; // Don't pop the route
    }
    return true; // Allow exiting (will be handled by SecurityWrapper)
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tabHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: _currentNavIndex == 0 ? _buildHomeAppBar() : null,
      body: _buildBody(),
      floatingActionButton:
          _currentNavIndex == 0
              ? FloatingActionButton.extended(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MyReportsScreen(),
                    ),
                  );
                },
                backgroundColor: const Color(0xFF2f3293),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add_moderator),
                label: const Text('Report Incident'),
              )
              : null,
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            if (_currentNavIndex != index) {
              _tabHistory.add(index);
            }
            _currentNavIndex = index;
          });
        },
      ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentNavIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        // Using MyReportsScreen as placeholder for "My Reports"
        return const MyReportsScreen();
      case 2:
        return const SupportHomeScreen();
      case 3:
        return const SettingsScreen();
      default:
        return _buildDashboard();
    }
  }

  PreferredSizeWidget? _buildAppBar() {
    // Only show Home AppBar on the Dashboard tab.
    // Other tabs (Report, Support, Settings) handle their own AppBars or lack thereof.
    if (_currentNavIndex == 0) {
      return _buildHomeAppBar();
    }
    return null;
  }

  // Helper method to keep build method clean, replacing the conditional in build()
  PreferredSizeWidget _buildHomeAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 1,
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: const Icon(Icons.school, color: Color(0xFF2f3293), size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Safely',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2f3293),
                ),
              ),
              Text(
                'MUST Campus',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Consumer<NotificationService>(
          builder: (context, notificationService, child) {
            return IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.notifications, color: Colors.black54),
                  if (notificationService.unreadCount > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          notificationService.unreadCount > 9
                              ? '9+'
                              : notificationService.unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            );
          },
        ),
        IconButton(
          icon: const CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blue,
            child: Icon(Icons.person, color: Colors.white, size: 16),
          ),
          onPressed: () {
            setState(() {
              _currentNavIndex = 3;
            });
          },
        ),
      ],
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2f3293), Color(0xFF4c5ed9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your safety is our priority.',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Speak Up. We are here to listen. All reports are confidential.',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const PrivacyScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Learn about Privacy'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Services Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
            children: [
              _buildMyReportsCard(context),
              _buildServiceCard(
                context,
                'Support Services',
                'Counseling & Medical',
                Icons.health_and_safety,
                Colors.green,
                onTap: () {
                  setState(() {
                    _currentNavIndex = 2;
                  });
                },
              ),
              _buildServiceCard(
                context,
                'Emergency',
                'Quick dial security',
                Icons.emergency,
                Colors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EmergencyScreen(),
                    ),
                  );
                },
              ),
              _buildServiceCard(
                context,
                'Chat Support',
                'Talk to an agent',
                Icons.chat,
                Colors.purple,
                badge: 'Live',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AIPoweredChatScreen(),
                    ),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Info Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: Colors.blue.shade600),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Did you know?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can submit reports anonymously. Your identity will remain hidden unless you choose to reveal it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyReportsCard(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return _buildServiceCard(
        context,
        'My Reports',
        'Track status of submitted cases',
        Icons.folder_open,
        Colors.blue,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyReportsScreen()),
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('reports')
              .where('userId', isEqualTo: user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        final reportCount = snapshot.data?.docs.length ?? 0;

        return _buildServiceCard(
          context,
          'My Reports',
          'Track status of submitted cases',
          Icons.folder_open,
          Colors.blue,
          badge: reportCount > 0 ? reportCount.toString() : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyReportsScreen()),
            );
          },
        );
      },
    );
  }

  Widget _buildServiceCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color, {
    String? badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badge == 'Live' ? Colors.green : color,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
