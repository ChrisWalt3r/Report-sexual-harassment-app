import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentNavIndex = 3;

  final TextEditingController _nameController = TextEditingController(
    text: 'John Doe',
  );

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chevron_left,
                color: AppColors.primaryBlue,
                size: 24,
              ),
              Text(
                'Settings',
                style: AppStyles.bodyMedium.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 110,
        title: Text('Profile', style: AppStyles.heading3),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              // Handle save
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Profile saved')));
            },
            child: Text(
              'Save',
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            _buildProfileHeader(),
            // Personal Details Section
            _buildSectionDivider('PERSONAL DETAILS'),
            _buildPersonalDetailsSection(),
            // Security Section
            _buildSectionDivider('SECURITY'),
            _buildSecuritySection(),
            // Account Section
            _buildSectionDivider('ACCOUNT'),
            _buildAccountSection(),
            const SizedBox(height: 24),
            // Quick Exit Button
            _buildQuickExitButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 0) {
            _navigateToHome();
          } else if (index == 3) {
            Navigator.pop(context);
          } else {
            setState(() {
              _currentNavIndex = index;
            });
          }
        },
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      color: AppColors.white,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // MUST Badge - centered
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.borderLight, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 14,
                  color: AppColors.textGray,
                ),
                const SizedBox(width: 4),
                Text(
                  'MUST',
                  style: AppStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Avatar with edit indicator - centered
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.avatarOrange,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    Icons.person,
                    color: AppColors.avatarOrange.withValues(alpha: 0.6),
                    size: 50,
                  ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: AppColors.white,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name - centered
          Text(
            'John Doe',
            style: AppStyles.heading3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // Role - centered
          Text(
            'Student',
            style: AppStyles.bodySmall.copyWith(color: AppColors.textGray),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionDivider(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.background,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF3B5998),
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPersonalDetailsSection() {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full Name
          Text(
            'Full Name',
            style: AppStyles.label.copyWith(
              color: AppColors.textGray,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              'John Doe',
              style: AppStyles.bodyMedium.copyWith(color: AppColors.textDark),
            ),
          ),
          const SizedBox(height: 20),
          // University ID
          Text(
            'University ID',
            style: AppStyles.label.copyWith(
              color: AppColors.textGray,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '2023/MUST/001',
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.textGray,
                    ),
                  ),
                ),
                Icon(Icons.lock_outline, size: 18, color: AppColors.textLight),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Contact administration to correct this ID.',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          const SizedBox(height: 20),
          // Email Address
          Text(
            'Email Address',
            style: AppStyles.label.copyWith(
              color: AppColors.textGray,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Text(
              'j.doe@student.must.ac.ug',
              style: AppStyles.bodyMedium.copyWith(color: AppColors.textDark),
            ),
          ),
          const SizedBox(height: 20),
          // Department/Faculty
          Text(
            'Department/Faculty',
            style: AppStyles.label.copyWith(
              color: AppColors.textGray,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Faculty of Computing',
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  size: 22,
                  color: AppColors.textLight,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      color: AppColors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle change password
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(
                  Icons.vpn_key_outlined,
                  color: AppColors.textDark,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Change Password',
                    style: AppStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textLight,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return Container(
      color: AppColors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Handle delete account
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              'Delete Account',
              style: AppStyles.bodyMedium.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickExitButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton(
        onPressed: () {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Quick Exit'),
                  content: const Text(
                    'This will close the app immediately. Are you sure?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Exit Now'),
                    ),
                  ],
                ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textDark,
          side: const BorderSide(color: AppColors.borderMedium, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, size: 18),
            const SizedBox(width: 8),
            Text(
              'Quick Exit App',
              style: AppStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
