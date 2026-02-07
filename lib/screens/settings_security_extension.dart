// Extension methods for settings screen security section
// Add these methods to the _SettingsScreenState class

/*
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
                  iconBackgroundColor: AppColors.iconRedBg,
                  iconColor: AppColors.danger,
                  title: 'PIN Protection',
                  value: securityService.isPinEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Setup PIN
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PinSetupScreen(),
                        ),
                      );
                    } else {
                      // Disable PIN with confirmation
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
                    iconBackgroundColor: AppColors.iconBlueBg,
                    iconColor: AppColors.primaryBlue,
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
                  iconBackgroundColor: AppColors.iconGreenBg,
                  iconColor: AppColors.success,
                  title: 'Auto Logout',
                  subtitle: securityService.isAutoLogoutEnabled
                      ? 'After ${securityService.autoLogoutMinutes} minutes'
                      : null,
                  value: securityService.isAutoLogoutEnabled,
                  onChanged: (value) async {
                    if (value) {
                      // Show dialog to set timeout
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

  // In the build method, add this after _buildGeneralSection():
  const SizedBox(height: 16),
  _buildSectionHeader('SECURITY'),
  _buildSecuritySection(),
*/
