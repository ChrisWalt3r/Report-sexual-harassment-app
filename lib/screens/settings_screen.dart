import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/settings_tile.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  int _currentNavIndex = 3;
  final _authService = AuthService();

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: Text(
          'Settings',
          style: AppStyles.heading2,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.textDark,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.success,
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.person,
                  color: AppColors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // User Profile Card
            _buildUserProfileCard(),
            const SizedBox(height: 16),
            // GENERAL Section
            _buildSectionHeader('GENERAL'),
            _buildGeneralSection(),
            const SizedBox(height: 16),
            // INFORMATION Section
            _buildSectionHeader('INFORMATION'),
            _buildInformationSection(),
            const SizedBox(height: 16),
            // Log Out Button
            _buildLogOutButton(),
            const SizedBox(height: 16),
            // Footer
            _buildFooter(),
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 0) {
            // Navigate to Home
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
          } else {
            setState(() {
              _currentNavIndex = index;
            });
          }
        },
      ),
    );
  }

  Widget _buildUserProfileCard() {
    return GestureDetector(
      onTap: _navigateToProfile,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.avatarOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      color: AppColors.avatarOrange.withRed(200),
                      size: 32,
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.onlineGreen,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jane Doe',
                    style: AppStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Student • Bachelors of IT',
                    style: AppStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: AppStyles.sectionHeader,
      ),
    );
  }

  Widget _buildGeneralSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SettingsTileWithSwitch(
              icon: Icons.notifications,
              iconBackgroundColor: AppColors.iconBlueBg,
              iconColor: AppColors.primaryBlue,
              title: 'Notifications',
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
            SettingsTileWithChevron(
              icon: Icons.lock,
              iconBackgroundColor: AppColors.iconGreenBg,
              iconColor: AppColors.success,
              title: 'Change Password',
              onTap: _showChangePasswordDialog,
            ),
            SettingsTileWithValue(
              icon: Icons.language,
              iconBackgroundColor: AppColors.iconBlueBg,
              iconColor: AppColors.primaryBlue,
              title: 'Language',
              value: 'English',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInformationSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            SettingsTileWithChevron(
              icon: Icons.help_outline,
              iconBackgroundColor: AppColors.iconRedBg,
              iconColor: AppColors.danger,
              title: 'Help & Support',
              onTap: () {},
            ),
            SettingsTileWithChevron(
              icon: Icons.shield_outlined,
              iconBackgroundColor: AppColors.iconBlueBg,
              iconColor: AppColors.primaryBlue,
              title: 'Privacy Policy',
              onTap: () {},
            ),
            SettingsTileWithChevron(
              icon: Icons.description_outlined,
              iconBackgroundColor: AppColors.iconGrayBg,
              iconColor: AppColors.textGray,
              title: 'Terms of Service',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogOutButton() {
    return Column(
      children: [
        // Delete Account Button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showDeleteAccountDialog,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Delete Account',
                    style: AppStyles.dangerButtonText.copyWith(
                      color: Colors.red[700],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Log Out Button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                // Show confirmation dialog
                final shouldLogout = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Logout'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text(
                            'Logout',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    );
                  },
                );

                // If user confirmed, logout
                if (shouldLogout == true && mounted) {
                  try {
                    await _authService.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error logging out: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Log Out',
                    style: AppStyles.dangerButtonText,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Report Safely for MUST',
        style: AppStyles.bodySmall.copyWith(
          color: AppColors.textLight,
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    helperText: 'At least 6 characters',
                    helperMaxLines: 2,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPassword = currentPasswordController.text;
                final newPassword = newPasswordController.text;
                final confirmPassword = confirmPasswordController.text;

                if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all fields'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (newPassword.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                if (newPassword != confirmPassword) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('New passwords do not match'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }

                currentPasswordController.dispose();
                newPasswordController.dispose();
                confirmPasswordController.dispose();
                Navigator.pop(dialogContext);

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );

                try {
                  await _authService.changePassword(
                    currentPassword: currentPassword,
                    newPassword: newPassword,
                  );

                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password changed successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context); // Close loading
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Error'),
                        content: Text(e.toString()),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red[600], size: 28),
              const SizedBox(width: 12),
              const Text('Delete Account'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This action cannot be undone!',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Deleting your account will permanently remove:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Your profile information\n'
                  '• All your reports\n'
                  '• Your chat history\n'
                  '• All associated data',
                  style: TextStyle(fontSize: 13, height: 1.6),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enter your password to confirm:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      ),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordController.dispose();
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (passwordController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your password'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final password = passwordController.text;
      passwordController.dispose();

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PopScope(
          canPop: false,
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );

      try {
        await _authService.deleteAccount(password);

        if (mounted) {
          Navigator.pop(context); // Close loading
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (route) => false,
          );
          
          // Show success message on login screen
          Future.delayed(const Duration(milliseconds: 500), () {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Account deleted successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          });
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Close loading
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 28),
                  SizedBox(width: 12),
                  Text('Error'),
                ],
              ),
              content: Text(e.toString()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } else {
      passwordController.dispose();
    }
  }
}
