import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
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
  final Map<String, dynamic>? anonymousInfo;
  const HomeScreen({super.key, this.anonymousInfo});

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
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: _currentNavIndex == 0 ? _buildHomeAppBar() : null,
      body: _buildBody(),
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
      backgroundColor: AppColors.mustBlue,
      elevation: 0,
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.mustGold, width: 1.5),
            ),
            child: const Icon(Icons.shield_outlined, color: AppColors.mustBlue, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SafeReport',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'MUST Campus',
                style: TextStyle(fontSize: 11, color: Colors.white70),
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
                  const Icon(Icons.notifications_outlined, color: Colors.white),
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
            backgroundColor: AppColors.mustGold,
            child: Icon(Icons.person, color: AppColors.mustBlue, size: 16),
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
          // Prominent Report Incident Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyReportsScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mustGold,
                foregroundColor: AppColors.mustBlue,
                elevation: 3,
                shadowColor: AppColors.mustGold.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_moderator, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'Report Incident',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Hero Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.mustBlue.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your safety is our priority.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Speak Up. We are here to listen. All reports are confidential.',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 14),
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
                    backgroundColor: Colors.white.withOpacity(0.2),
                    foregroundColor: Colors.white,
                    elevation: 0,
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
                AppColors.mustGreen,
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
                AppColors.mustBlueMedium,
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
              color: AppColors.mustBlue.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.mustBlue.withOpacity(0.15)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.mustBlue),
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
                          color: AppColors.mustBlue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'You can submit reports anonymously. Your identity will remain hidden unless you choose to reveal it.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.mustBlueMedium,
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
        AppColors.mustBlue,
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
          AppColors.mustBlue,
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
