import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../constants/app_colors.dart';
import '../widgets/bottom_nav_bar.dart';
import '../features/support_services/screens/support_home_screen.dart';
import '../services/notification_service.dart';
import 'ai_powered_chat_screen.dart';
import 'emergency_screen.dart';
import 'settings_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_screen.dart';
import 'report_form_screen.dart';

class HomeScreen extends StatefulWidget {
  final Map<String, dynamic>? anonymousInfo;
  final String? userId;
  final bool showShowcase;
  
  const HomeScreen({
    super.key, 
    this.anonymousInfo, 
    this.userId,
    this.showShowcase = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentNavIndex = 0;
  final List<int> _tabHistory = [0];
  Map<String, dynamic>? _userData;
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize notification service for the logged-in user
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final notificationService = Provider.of<NotificationService>(context, listen: false);
      notificationService.initialize(user.uid);
      _setupUserDataListener();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userDataSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh user data when app comes back to foreground
      _loadUserData();
    }
  }

  void _setupUserDataListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userDataSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists && mounted) {
          final data = doc.data();
          print('Home Screen: User data updated - photoUrl: ${data?['photoUrl']}');
          setState(() {
            _userData = data;
          });
        }
      });
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _userData = doc.data();
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
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
    return true; // Allow exiting
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: _tabHistory.length <= 1,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        appBar: _currentNavIndex == 0 ? _buildHomeAppBar() : null,
        body: _buildBody(),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Three full-width colored lines stacked on top of each other
            Container(
              child: Column(
                children: [
                  // Blue line - full width (original blue)
                  Container(
                    height: 2, // Increased from 1 to 2
                    width: double.infinity,
                    color: AppColors.royalBlue, // Original blue
                  ),
                  // Orange line - full width
                  Container(
                    height: 2, // Increased from 1 to 2
                    width: double.infinity,
                    color: AppColors.secondaryOrange, // Bright orange
                  ),
                  // Green line - full width
                  Container(
                    height: 2, // Increased from 1 to 2
                    width: double.infinity,
                    color: AppColors.primaryGreen, // MUST green
                  ),
                ],
              ),
            ),
            // Bottom navigation bar
            BottomNavBar(
              currentIndex: _currentNavIndex,
              onTap: (index) {
                setState(() {
                  if (_currentNavIndex != index) {
                    _tabHistory.add(index);
                  }
                  _currentNavIndex = index;
                  
                  // Refresh user data when navigating to home tab
                  if (index == 0) {
                    _loadUserData();
                  }
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildBody() {
    switch (_currentNavIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const MyReportsScreen();
      case 2:
        return const SupportHomeScreen();
      case 3:
        return const SettingsScreen();
      default:
        return _buildDashboard();
    }
  }

  // Clean app bar without colored lines
  PreferredSizeWidget _buildHomeAppBar() {
    return AppBar(
      automaticallyImplyLeading: false, // Remove back arrow
      backgroundColor: AppColors.primaryGreen,
      elevation: 0,
      title: Row(
        children: [
          // App icon with frame back - increased size even more
          Container(
            width: 52, // Increased from 44 to 52
            height: 52, // Increased from 44 to 52
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primaryGreen, width: 2),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icon/app_icon_circle.jpeg',
                width: 48, // Increased from 40 to 48
                height: 48, // Increased from 40 to 48
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 18), // Increased spacing slightly more
          const Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SafeReport',
                  style: TextStyle(
                    fontSize: 20, // Increased from 16 to 20
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'MUST Campus',
                  style: TextStyle(
                    fontSize: 12, // Slightly increased from 11 to 12
                    color: Colors.white70,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
                          color: AppColors.secondaryOrange,
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
          icon: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.royalBlue,
            child: ClipOval(
              child: Builder(
                builder: (context) {
                  final photoUrl = _userData?['photoUrl']?.toString();
                  print('Home Screen AppBar: photoUrl = $photoUrl');
                  
                  if (photoUrl != null && photoUrl.isNotEmpty) {
                    return Image.network(
                      photoUrl,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        print('Home Screen AppBar: Error loading image - $error');
                        return const Icon(Icons.person, color: Colors.white, size: 16);
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) {
                          print('Home Screen AppBar: Image loaded successfully');
                          return child;
                        }
                        return const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        );
                      },
                    );
                  } else {
                    print('Home Screen AppBar: No photoUrl, showing default icon');
                    return const Icon(Icons.person, color: Colors.white, size: 16);
                  }
                },
              ),
            ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20), // Increased padding for better spacing
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner - Improved design
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.royalBlue,
                  AppColors.royalBlue.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.royalBlue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.security,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Your safety is our priority',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Speak up confidentially. Every report matters and helps create a safer campus for everyone.',
                  style: TextStyle(
                    fontSize: 14, 
                    color: Colors.white70,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ReportFormScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_outline, size: 24, color: Colors.white),
                        SizedBox(width: 12),
                        Text(
                          'Report Incident',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: Colors.white, // Explicit white color
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Quick Actions Section
          Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Services Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2, // Increased to reduce height
            children: [
              _buildMyReportsCard(context),
              _buildServiceCard(
                context,
                'Support Services',
                'Counseling & Medical',
                Icons.health_and_safety,
                AppColors.primaryGreen,
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
                AppColors.error,
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
                AppColors.royalBlue,
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

          // Info Card - Enhanced design
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryGreen.withOpacity(0.1),
                  AppColors.primaryGreen.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryGreen.withOpacity(0.3), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Anonymous Reporting',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your identity remains completely confidential. Reports help create a safer campus environment for everyone.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20), // Bottom padding
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
        AppColors.royalBlue,
        badge: null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MyReportsScreen()),
          );
        },
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
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
          AppColors.royalBlue,
          badge: reportCount.toString(),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12), // Reduced padding
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Icon without frame
                Container(
                  width: 40, // Reduced size
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20), // Reduced icon size
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badge == 'Live' ? AppColors.primaryGreen : AppColors.secondaryOrange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8), // Reduced spacing
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13, // Reduced font size
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11, // Reduced font size
                        color: isDark ? Colors.white70 : AppColors.textSecondary,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
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