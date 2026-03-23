import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../models/admin_user.dart';
import '../../services/admin_auth_service.dart';

/// Admin profile management screen
/// Allows admins to update their name, email, and password
class ProfileManagementScreen extends StatefulWidget {
  final AdminUser admin;
  final bool embedded;
  
  const ProfileManagementScreen({
    super.key,
    required this.admin,
    this.embedded = false,
  });

  @override
  State<ProfileManagementScreen> createState() => _ProfileManagementScreenState();
}

class _ProfileManagementScreenState extends State<ProfileManagementScreen> {
  final _adminAuthService = AdminAuthService();
  late AdminUser _admin;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _admin = widget.admin;
    _refreshAdmin();
  }

  Future<void> _refreshAdmin() async {
    final admin = await _adminAuthService.getCurrentAdmin();
    if (admin != null && mounted) {
      setState(() => _admin = admin);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  Future<void> _updateName() async {
    final controller = TextEditingController(text: _admin.fullName);
    
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Full Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryOrange),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != _admin.fullName) {
      setState(() => _isLoading = true);
      try {
        await _adminAuthService.updateProfile(fullName: newName);
        await _refreshAdmin();
        _showMessage('Name updated successfully');
      } catch (e) {
        _showMessage('Error: $e', isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Change Password'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    helperText: 'At least 6 characters',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirm,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (newPasswordController.text != confirmPasswordController.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Passwords do not match'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                if (newPasswordController.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password must be at least 6 characters'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryOrange),
              child: const Text('Change Password'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      setState(() => _isLoading = true);
      try {
        await _adminAuthService.changePassword(
          currentPassword: currentPasswordController.text,
          newPassword: newPasswordController.text,
        );
        _showMessage('Password changed successfully');
      } catch (e) {
        _showMessage('Error: $e', isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateEmail() async {
    final emailController = TextEditingController(text: _admin.email);
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Email'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'New Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm with Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'A verification email will be sent to the new address.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondaryOrange),
              child: const Text('Update Email'),
            ),
          ],
        ),
      ),
    );

    if (result == true && emailController.text.trim() != _admin.email) {
      setState(() => _isLoading = true);
      try {
        await _adminAuthService.updateEmail(
          newEmail: emailController.text.trim(),
          password: passwordController.text,
        );
        _showMessage('Verification email sent. Check your new email to confirm.');
      } catch (e) {
        _showMessage('Error: $e', isError: true);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.person, size: 32, color: AppColors.secondaryOrange),
              const SizedBox(width: 12),
              const Text(
                'Profile Settings',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (_isLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primaryGreen,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Manage your account information and security',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          // Profile Card
          _buildSectionCard(
            title: 'Profile Information',
            icon: Icons.badge,
            children: [
              _buildInfoTile(
                label: 'Full Name',
                value: _admin.fullName,
                icon: Icons.person_outline,
                onEdit: _updateName,
              ),
              const Divider(),
              _buildInfoTile(
                label: 'Email Address',
                value: _admin.email,
                icon: Icons.email_outlined,
                onEdit: _updateEmail,
              ),
              const Divider(),
              _buildInfoTile(
                label: 'Role',
                value: _admin.role.displayName,
                icon: Icons.admin_panel_settings_outlined,
                editable: false,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Security Card
          _buildSectionCard(
            title: 'Security',
            icon: Icons.security,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondaryOrange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_outline, color: AppColors.secondaryOrange),
                ),
                title: const Text('Password'),
                subtitle: const Text('Change your account password'),
                trailing: ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondaryOrange,
                  ),
                  child: const Text('Change'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Account Info Card
          _buildSectionCard(
            title: 'Account Information',
            icon: Icons.info_outline,
            children: [
              _buildReadOnlyTile(
                label: 'Account Status',
                value: _admin.isActive ? 'Active' : 'Inactive',
                valueColor: _admin.isActive ? Colors.green : Colors.red,
              ),
              const Divider(),
              _buildReadOnlyTile(
                label: 'Account Created',
                value: _formatDate(_admin.createdAt),
              ),
              const Divider(),
              _buildReadOnlyTile(
                label: 'Last Login',
                value: _admin.lastLoginAt != null 
                    ? _formatDate(_admin.lastLoginAt!)
                    : 'N/A',
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile Settings'),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: content,
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.secondaryOrange),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required String label,
    required String value,
    required IconData icon,
    VoidCallback? onEdit,
    bool editable = true,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppColors.primaryGreen),
      ),
      title: Text(
        label,
        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      ),
      trailing: editable && onEdit != null
          ? IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: _isLoading ? null : onEdit,
              color: AppColors.secondaryOrange,
            )
          : null,
    );
  }

  Widget _buildReadOnlyTile({
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
