import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:showcaseview/showcaseview.dart';

import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../services/auth_service.dart';
import '../services/security_service.dart';
import '../services/theme_service.dart';
import '../widgets/settings_tile.dart';
import 'login_screen.dart';
import 'pin_setup_screen.dart';
import 'profile_screen.dart';
import 'welcome_screen.dart';
import 'home_screen.dart';
import 'faq_screen.dart';
import 'privacy_screen.dart';
import 'terms_of_service_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  final _authService = AuthService();
  final ImagePicker _imagePicker = ImagePicker();

  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final data = await _authService.getUserData(user.uid);
      if (!mounted) return;
      setState(() {
        _userData = data;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        toolbarHeight: 65,
        elevation: 0,
        title: Text('Settings', style: AppStyles.heading2.copyWith(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildUserProfileCard(),
            const SizedBox(height: 16),
            _buildSectionHeader('GENERAL'),
            _buildGeneralSection(),
            const SizedBox(height: 16),
            _buildSectionHeader('APPEARANCE'),
            _buildAppearanceSection(),
            const SizedBox(height: 16),
            _buildSectionHeader('SECURITY'),
            _buildSecuritySection(),
            const SizedBox(height: 16),
            _buildSectionHeader('INFORMATION'),
            _buildInformationSection(),
            const SizedBox(height: 16),
            _buildLogOutButton(),
            const SizedBox(height: 16),
            _buildFooter(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfileCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final photoUrl =
        _userData?['photoUrl'] ?? _authService.currentUser?.photoURL;

    return GestureDetector(
      onTap: _navigateToProfile,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
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
                    color: AppColors.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child:
                        (photoUrl == null || photoUrl.toString().isEmpty)
                            ? const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 32,
                              ),
                            )
                            : Image.network(
                              photoUrl.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                );
                              },
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
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _showProfilePhotoActions,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.royalBlue,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: AppColors.white,
                        size: 10,
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
                    _isLoading
                        ? 'Loading...'
                        : (_userData?['fullName'] ?? 'User'),
                    style: AppStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isLoading
                        ? 'Loading...'
                        : '${_userData?['role'] ?? 'Student'} • ${_userData?['department'] ?? 'Not specified'}',
                    style: AppStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textLight),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(title, style: AppStyles.sectionHeader),
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
              iconBackgroundColor: AppColors.primaryGreen.withOpacity(0.1),
              iconColor: AppColors.primaryGreen,
              title: 'Notifications',
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() => _notificationsEnabled = value);
              },
            ),
            SettingsTileWithChevron(
              icon: Icons.lock,
              iconBackgroundColor: AppColors.royalBlue.withOpacity(0.1),
              iconColor: AppColors.royalBlue,
              title: 'Change Password',
              onTap: _showChangePasswordDialog,
            ),
            SettingsTileWithValue(
              icon: Icons.language,
              iconBackgroundColor: AppColors.secondaryOrange.withOpacity(0.1),
              iconColor: AppColors.secondaryOrange,
              title: 'Language',
              value: 'English',
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppearanceSection() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
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
                SettingsTileWithValue(
                  icon: themeService.themeModeIcon,
                  iconBackgroundColor: AppColors.secondaryOrange.withOpacity(0.1),
                  iconColor: AppColors.secondaryOrange,
                  title: 'Theme',
                  value: themeService.themeModeLabel,
                  onTap: () => _showThemeSelectionDialog(themeService),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showThemeSelectionDialog(ThemeService themeService) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        title: Text(
          'Choose Theme',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.textDark,
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.brightness_auto, 
                size: 20,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
              title: Text(
                'System Default', 
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              subtitle: Text(
                'Follows device settings', 
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              trailing: Radio<ThemeMode>(
                value: ThemeMode.system,
                groupValue: themeService.themeMode,
                activeColor: AppColors.primaryGreen,
                onChanged: (value) {
                  if (value != null) {
                    themeService.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              onTap: () {
                themeService.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.light_mode, 
                size: 20,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
              title: Text(
                'Light', 
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              subtitle: Text(
                'Always use light theme', 
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              trailing: Radio<ThemeMode>(
                value: ThemeMode.light,
                groupValue: themeService.themeMode,
                activeColor: AppColors.primaryGreen,
                onChanged: (value) {
                  if (value != null) {
                    themeService.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              onTap: () {
                themeService.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.dark_mode, 
                size: 20,
                color: isDark ? Colors.white : AppColors.textDark,
              ),
              title: Text(
                'Dark', 
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppColors.textDark,
                ),
              ),
              subtitle: Text(
                'Always use dark theme', 
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              trailing: Radio<ThemeMode>(
                value: ThemeMode.dark,
                groupValue: themeService.themeMode,
                activeColor: AppColors.primaryGreen,
                onChanged: (value) {
                  if (value != null) {
                    themeService.setThemeMode(value);
                    Navigator.pop(context);
                  }
                },
              ),
              onTap: () {
                themeService.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryGreen,
            ),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Consumer<SecurityService>(
      builder: (context, securityService, child) {
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
                  icon: Icons.pin,
                  iconBackgroundColor: AppColors.secondaryOrange.withOpacity(0.1),
                  iconColor: AppColors.secondaryOrange,
                  title: 'PIN Protection',
                  value: securityService.isPinEnabled,
                  onChanged: (value) async {
                    if (value) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PinSetupScreen(),
                        ),
                      );
                    } else {
                      final shouldDisable = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Disable PIN?'),
                          content: const Text(
                            'Are you sure you want to disable PIN protection?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text(
                                'Disable',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                      
                      if (shouldDisable == true) {
                        await securityService.disablePin();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('PIN protection disabled'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
                if (securityService.isPinEnabled)
                  SettingsTileWithChevron(
                    icon: Icons.edit,
                    iconBackgroundColor: AppColors.royalBlue.withOpacity(0.1),
                    iconColor: AppColors.royalBlue,
                    title: 'Change PIN',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PinSetupScreen(isChanging: true),
                        ),
                      );
                    },
                  ),
                SettingsTileWithSwitch(
                  icon: Icons.timer,
                  iconBackgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                  iconColor: AppColors.primaryGreen,
                  title: 'Auto Logout',
                  subtitle: securityService.isAutoLogoutEnabled
                      ? 'After ${securityService.autoLogoutMinutes} minutes'
                      : null,
                  value: securityService.isAutoLogoutEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final minutes = await showDialog<int>(
                        context: context,
                        builder: (context) => _buildAutoLogoutDialog(
                          securityService.autoLogoutMinutes,
                        ),
                      );
                      
                      if (minutes != null) {
                        await securityService.setAutoLogout(true, minutes: minutes);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Auto logout enabled ($minutes minutes)',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      }
                    } else {
                      await securityService.setAutoLogout(false);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Auto logout disabled'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAutoLogoutDialog(int currentMinutes) {
    int selectedMinutes = currentMinutes;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('Auto Logout Timeout'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select inactivity timeout:'),
              const SizedBox(height: 16),
              RadioListTile<int>(
                title: const Text('5 minutes'),
                value: 5,
                groupValue: selectedMinutes,
                onChanged: (value) => setState(() => selectedMinutes = value!),
              ),
              RadioListTile<int>(
                title: const Text('15 minutes'),
                value: 15,
                groupValue: selectedMinutes,
                onChanged: (value) => setState(() => selectedMinutes = value!),
              ),
              RadioListTile<int>(
                title: const Text('30 minutes'),
                value: 30,
                groupValue: selectedMinutes,
                onChanged: (value) => setState(() => selectedMinutes = value!),
              ),
              RadioListTile<int>(
                title: const Text('60 minutes'),
                value: 60,
                groupValue: selectedMinutes,
                onChanged: (value) => setState(() => selectedMinutes = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, selectedMinutes),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
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
              icon: Icons.play_circle_outline,
              iconBackgroundColor: AppColors.primaryGreen.withOpacity(0.1),
              iconColor: AppColors.primaryGreen,
              title: 'App Guide',
              onTap: _showAppGuideOptions,
            ),
            SettingsTileWithChevron(
              icon: Icons.quiz_outlined,
              iconBackgroundColor: AppColors.royalBlue.withOpacity(0.1),
              iconColor: AppColors.royalBlue,
              title: 'FAQs',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FAQScreen()),
              ),
            ),
            SettingsTileWithChevron(
              icon: Icons.shield_outlined,
              iconBackgroundColor: AppColors.royalBlue.withOpacity(0.1),
              iconColor: AppColors.royalBlue,
              title: 'Privacy Policy',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyScreen()),
              ),
            ),
            SettingsTileWithChevron(
              icon: Icons.description_outlined,
              iconBackgroundColor: AppColors.primaryGreen.withOpacity(0.1),
              iconColor: AppColors.primaryGreen,
              title: 'Terms of Service',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TermsOfServiceScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _showAppGuideOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.school, color: AppColors.primaryGreen, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'App Guide',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Learn how to use the app',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.royalBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.slideshow, color: AppColors.royalBlue, size: 22),
              ),
              title: const Text('Watch Introduction', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Full onboarding tutorial', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _replayOnboarding();
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.secondaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.touch_app, color: AppColors.secondaryOrange, size: 22),
              ),
              title: const Text('Feature Highlights', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Quick tour of main features', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                _replayShowcase();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  void _replayOnboarding() {
    final user = _authService.currentUser;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const WelcomeScreen(),
      ),
    );
  }
  
  void _replayShowcase() {
    // Navigate to home and trigger showcase
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => ShowCaseWidget(
          builder: (context) => const HomeScreen(showShowcase: true),
        ),
      ),
      (route) => false,
    );
  }

  Widget _buildLogOutButton() {
    return Column(
      children: [
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
              onTap: _logout,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('Log Out', style: AppStyles.dangerButtonText),
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
        style: AppStyles.bodySmall.copyWith(color: AppColors.textLight),
      ),
    );
  }

  Future<void> _logout() async {
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
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true || !mounted) return;

    try {
      await _authService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No user is currently signed in'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final hasPasswordProvider = user.providerData.any(
      (p) => p.providerId == 'password',
    );
    if (!hasPasswordProvider) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.royalBlue, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'No Password',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: const Text(
                'This account uses a provider like Google sign-in. It does not have a password you can change here.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showPasswordResetDialog();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalBlue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Reset Password'),
                ),
              ],
            ),
      );
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;

    final didChange = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: AppColors.royalBlue,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Change Password',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enter your current password and choose a new one.',
                        style: TextStyle(fontSize: 14, height: 1.5),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed:
                                isSubmitting
                                    ? null
                                    : () => setDialogState(
                                      () => obscureCurrent = !obscureCurrent,
                                    ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        decoration: InputDecoration(
                          labelText: 'New Password',
                          prefixIcon: const Icon(Icons.lock_reset),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed:
                                isSubmitting
                                    ? null
                                    : () => setDialogState(
                                      () => obscureNew = !obscureNew,
                                    ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        decoration: InputDecoration(
                          labelText: 'Confirm New Password',
                          prefixIcon: const Icon(Icons.lock_reset),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed:
                                isSubmitting
                                    ? null
                                    : () => setDialogState(
                                      () => obscureConfirm = !obscureConfirm,
                                    ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () {
                                    Navigator.pop(dialogContext, false);
                                    _showPasswordResetDialog();
                                  },
                          child: const Text('Forgot password? Reset'),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed:
                        isSubmitting
                            ? null
                            : () => Navigator.pop(dialogContext, false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        isSubmitting
                            ? null
                            : () async {
                              final currentPassword =
                                  currentPasswordController.text.trim();
                              final newPassword =
                                  newPasswordController.text.trim();
                              final confirmPassword =
                                  confirmPasswordController.text.trim();

                              if (currentPassword.isEmpty ||
                                  newPassword.isEmpty ||
                                  confirmPassword.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please fill in all password fields',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              if (newPassword.length < 6) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'New password is too short (min 6 characters)',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }
                              if (newPassword != confirmPassword) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Passwords do not match'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() => isSubmitting = true);
                              try {
                                await _authService.changePassword(
                                  currentPassword: currentPassword,
                                  newPassword: newPassword,
                                );
                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext, true);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(e.toString()),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                setDialogState(() => isSubmitting = false);
                              }
                            },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.royalBlue,
                      foregroundColor: Colors.white,
                    ),
                    child:
                        isSubmitting
                            ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Update'),
                  ),
                ],
              );
            },
          ),
    );

    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();

    if (didChange == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _showPasswordResetDialog() async {
    final emailController = TextEditingController();

    final knownEmail = _userData?['email'] ?? _authService.currentUser?.email;
    if (knownEmail != null) {
      emailController.text = knownEmail.toString();
    }

    final email = await showDialog<String?>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.lock_reset, color: AppColors.royalBlue, size: 28),
                const SizedBox(width: 12),
                const Text('Reset Password'),
              ],
            ),
            content: TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final value = emailController.text.trim();
                  if (value.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your email address'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, value);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.royalBlue,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Send Reset Link'),
              ),
            ],
          ),
    );

    emailController.dispose();
    if (email == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: const Center(child: CircularProgressIndicator()),
          ),
    );

    try {
      await _authService.resetPassword(email);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset email sent'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showProfilePhotoActions() async {
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Profile Picture',
                  style: AppStyles.heading3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadProfilePhoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadProfilePhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remove photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removeProfilePhoto();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUploadProfilePhoto(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
      );
      if (picked == null) return;
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => PopScope(
              canPop: false,
              child: const Center(child: CircularProgressIndicator()),
            ),
      );

      await _authService.updateProfilePhoto(imageFile: picked);
      await _loadUserData();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    try {
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => PopScope(
              canPop: false,
              child: const Center(child: CircularProgressIndicator()),
            ),
      );

      await _authService.removeProfilePhoto();
      await _loadUserData();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture removed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showDeleteAccountDialog() async {
    final passwordController = TextEditingController();
    final user = _authService.currentUser;

    final isGoogleSignIn =
        user?.providerData.any((p) => p.providerId == 'google.com') ?? false;
    bool obscurePassword = true;

    final result = await showDialog<String?>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red[600],
                      size: 28,
                    ),
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
                      if (!isGoogleSignIn) ...[
                        const Text(
                          'Enter your password to confirm:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
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
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed:
                                  () => setDialogState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'You will be asked to sign in with Google to confirm deletion.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, null),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (!isGoogleSignIn && passwordController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter your password'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }
                      Navigator.pop(
                        dialogContext,
                        isGoogleSignIn ? 'google' : passwordController.text,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete Account'),
                  ),
                ],
              );
            },
          ),
    );

    passwordController.dispose();
    if (result == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => PopScope(
            canPop: false,
            child: const Center(child: CircularProgressIndicator()),
          ),
    );

    try {
      await _authService.deleteAccount(result);
      if (!mounted) return;
      Navigator.pop(context);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
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
}
