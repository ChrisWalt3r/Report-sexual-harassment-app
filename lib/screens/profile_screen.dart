import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/app_colors.dart';
import '../constants/app_styles.dart';
import '../widgets/bottom_nav_bar.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import '../utils/user_role_utils.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _currentNavIndex = 3;
  final AuthService _authService = AuthService();

  // User data
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Edit controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _otherRoleController = TextEditingController();

  // Dropdown selections (edit mode)
  String? _selectedRole;
  String? _selectedStudyLevel;
  String? _selectedFaculty;
  String? _selectedDepartment;

  // Options matching register screen
  final List<String> _roles = UserRoleUtils.selectableRoles;
  final List<String> _studyLevels = ['Undergraduate', 'Postgraduate'];
  final List<String> _faculties = [
    'School of Health Sciences',
    'School of Science',
    'School of Computing and Informatics',
    'School of Applied Sciences and Technology',
    'School of Business and Management Sciences',
    'School of Interdisciplinary Studies',
  ];

  final Map<String, List<String>> _facultyDepartments = {
    'School of Health Sciences': [
      'Anatomy',
      'Biochemistry',
      'Internal Medicine',
      'Surgery',
      'Pediatrics',
      'Obstetrics & Gynecology',
      'Family Medicine',
      'Medical Laboratory Sciences',
      'Pharmacy',
      'Microbiology',
      'Pathology',
      'Radiology',
      'Physiology',
      'Psychiatry',
      'Community Health',
      'Nursing/Midwifery',
    ],
    'School of Science': ['Biology', 'Chemistry', 'Physics', 'Mathematics'],
    'School of Computing and Informatics': [
      'Computer Science',
      'Information Technology',
      'Software Engineering',
    ],
    'School of Applied Sciences and Technology': [
      'Biomedical Sciences & Engineering',
      'Civil Engineering',
      'Electrical & Electronics Engineering',
      'Mechanical Engineering',
      'Petroleum & Environmental Management',
    ],
    'School of Business and Management Sciences': [
      'Accounting & Finance',
      'Business Administration',
      'Economics',
      'Procurement & Supply Chain Management',
      'Marketing & Entrepreneurship',
    ],
    'School of Interdisciplinary Studies': [
      'Planning & Governance',
      'Human Development & Relational Sciences',
      'Environment & Livelihood Support Systems',
      'Community Engagement & Service Learning',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw 'No user is currently signed in';
      }

      final data = await _authService.getUserData(user.uid);
      setState(() {
        _userData = data;
        _isLoading = false;
        _populateEditFields();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
      }
    }
  }

  void _populateEditFields() {
    if (_userData == null) return;
    _fullNameController.text = _userData?['fullName'] ?? '';
    _phoneController.text = _userData?['phoneNumber'] ?? '';
    _emailController.text = _userData?['email'] ?? '';
    final storedRole = (_userData?['role'] ?? '').toString().trim();
    final storedOtherRole = (_userData?['otherRole'] ?? '').toString().trim();
    if (storedRole.isEmpty) {
      _selectedRole = null;
      _otherRoleController.clear();
    } else if (_roles.contains(storedRole)) {
      _selectedRole = storedRole;
      _otherRoleController.text =
          storedRole == UserRoleUtils.otherRoleValue ? storedOtherRole : '';
    } else {
      _selectedRole = UserRoleUtils.otherRoleValue;
      _otherRoleController.text = storedRole;
    }
    _selectedStudyLevel = _userData?['studyLevel'];
    if (_selectedStudyLevel != null &&
        !_studyLevels.contains(_selectedStudyLevel)) {
      _selectedStudyLevel = null;
    }
    _selectedFaculty = _userData?['department'];
    if (_selectedFaculty != null && !_faculties.contains(_selectedFaculty)) {
      _selectedFaculty = null;
    }
    _selectedDepartment = _userData?['facultyDepartment'];
    if (_selectedFaculty != null && _selectedDepartment != null) {
      final depts = _facultyDepartments[_selectedFaculty] ?? [];
      if (!depts.contains(_selectedDepartment)) {
        _selectedDepartment = null;
      }
    }
  }

  void _toggleEdit() {
    setState(() {
      if (_isEditing) {
        // Cancel edit — re-populate from stored data
        _populateEditFields();
      }
      _isEditing = !_isEditing;
    });
  }

  Future<void> _saveProfile() async {
    final user = _authService.currentUser;
    if (user == null) return;

    if (_selectedRole == UserRoleUtils.otherRoleValue &&
        _otherRoleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please specify your role.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updates = <String, dynamic>{
        'fullName': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'role': _selectedRole ?? '',
        'otherRole':
            _selectedRole == UserRoleUtils.otherRoleValue
                ? _otherRoleController.text.trim()
                : '',
        'studyLevel': _selectedStudyLevel ?? '',
        'department': _selectedFaculty ?? '',
        'facultyDepartment': _selectedDepartment ?? '',
      };

      await _authService.updateUserProfile(uid: user.uid, updates: updates);

      // Refresh local data
      final freshData = await _authService.getUserData(user.uid);
      setState(() {
        _userData = freshData;
        _isEditing = false;
        _isSaving = false;
        _populateEditFields();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _otherRoleController.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        toolbarHeight: 65,
        elevation: 0,
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.chevron_left, color: Colors.white, size: 24),
              Text(
                'Settings',
                style: AppStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        leadingWidth: 110,
        title: Text(
          'Profile',
          style: AppStyles.heading3.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Edit Profile',
              onPressed: _toggleEdit,
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              tooltip: 'Cancel',
              onPressed: _toggleEdit,
            ),
            IconButton(
              icon:
                  _isSaving
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.check, color: Colors.white),
              tooltip: 'Save',
              onPressed: _isSaving ? null : _saveProfile,
            ),
          ],
        ],
      ),
      body:
          _isLoading
              ? Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
              : _userData == null
              ? const Center(child: Text('No user data found'))
              : SingleChildScrollView(
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
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.secondaryOrange, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 14,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 4),
                Text(
                  'MUST',
                  style: AppStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: AppColors.primaryGreen,
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
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child:
                      (_userData?['photoUrl'] != null &&
                              _userData!['photoUrl'].toString().isNotEmpty)
                          ? Image.network(
                            _userData!['photoUrl'].toString(),
                            fit: BoxFit.cover,
                            width: 100,
                            height: 100,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 50,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                          )
                          : const Center(
                            child: Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 50,
                            ),
                          ),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: InkWell(
                  onTap: _showProfilePhotoActions,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.royalBlue,
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
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Name - centered
          Text(
            _userData?['fullName'] ?? 'No Name',
            style: AppStyles.heading3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // Role - centered
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              UserRoleUtils.displayRoleFromData(_userData, fallback: 'Student'),
              style: AppStyles.bodySmall.copyWith(
                color: AppColors.royalBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if ((_userData?['studyLevel'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              _userData!['studyLevel'],
              style: AppStyles.bodySmall.copyWith(color: AppColors.textGray),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionDivider(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[50],
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.royalBlue,
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
          _buildFieldLabel('Full Name'),
          const SizedBox(height: 8),
          _isEditing
              ? _buildEditTextField(
                controller: _fullNameController,
                hint: 'Enter your full name',
                icon: Icons.person_outline,
              )
              : _buildReadOnlyField(_userData?['fullName'] ?? 'Not provided'),

          const SizedBox(height: 20),

          // Role
          _buildFieldLabel('Role'),
          const SizedBox(height: 8),
          _isEditing
              ? _buildDropdown<String>(
                value: _selectedRole,
                hint: 'Select your role',
                icon: Icons.people_outline,
                items: _roles,
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value;
                    if (value != 'Student') _selectedStudyLevel = null;
                    if (value != UserRoleUtils.otherRoleValue) {
                      _otherRoleController.clear();
                    }
                  });
                },
              )
              : _buildReadOnlyField(
                UserRoleUtils.displayRoleFromData(_userData),
              ),

          if (_isEditing && _selectedRole == UserRoleUtils.otherRoleValue) ...[
            const SizedBox(height: 20),
            _buildFieldLabel('Specify your role'),
            const SizedBox(height: 8),
            _buildEditTextField(
              controller: _otherRoleController,
              hint: 'e.g. Cleaner, Electrician, Security',
              icon: Icons.edit_outlined,
            ),
          ],

          // Study Level (for Students)
          if (_isEditing &&
              UserRoleUtils.shouldShowStudyLevel(_selectedRole)) ...[
            const SizedBox(height: 20),
            _buildFieldLabel('Study Level'),
            const SizedBox(height: 8),
            _buildDropdown<String>(
              value: _selectedStudyLevel,
              hint: 'Select your study level',
              icon: Icons.menu_book_outlined,
              items: _studyLevels,
              onChanged: (value) => setState(() => _selectedStudyLevel = value),
            ),
          ] else if (!_isEditing &&
              (_userData?['studyLevel'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 20),
            _buildFieldLabel('Study Level'),
            const SizedBox(height: 8),
            _buildReadOnlyField(_userData!['studyLevel']),
          ],

          const SizedBox(height: 20),

          // ID Number (label varies by role)
          _buildFieldLabel(UserRoleUtils.displayIdLabel(_selectedRole)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _userData?['studentId'] ?? 'Not provided',
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
            'Contact administration to correct this ${UserRoleUtils.displayIdLabel(_selectedRole).toLowerCase()}.',
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),

          const SizedBox(height: 20),

          // Email Address (always read-only)
          _buildFieldLabel('Email Address'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _userData?['email'] ?? 'Not provided',
                    style: AppStyles.bodyMedium.copyWith(
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                Icon(Icons.lock_outline, size: 18, color: AppColors.textLight),
              ],
            ),
          ),

          const SizedBox(height: 20),

          if (UserRoleUtils.shouldShowFaculty(_selectedRole) ||
              (!_isEditing &&
                  UserRoleUtils.shouldShowFaculty(
                    _userData?['role']?.toString(),
                  ))) ...[
            // Faculty
            _buildFieldLabel('Faculty'),
            const SizedBox(height: 8),
            _isEditing
                ? _buildDropdown<String>(
                  value: _selectedFaculty,
                  hint: 'Select your faculty',
                  icon: Icons.school_outlined,
                  items: _faculties,
                  onChanged: (value) {
                    setState(() {
                      _selectedFaculty = value;
                      _selectedDepartment = null;
                    });
                  },
                  fontSize: 13,
                )
                : _buildReadOnlyField(
                  _userData?['department'] ?? 'Not provided',
                ),

            // Department (shown after faculty is selected)
            if (_isEditing && _selectedFaculty != null) ...[
              const SizedBox(height: 20),
              _buildFieldLabel('Department'),
              const SizedBox(height: 8),
              _buildDropdown<String>(
                value: _selectedDepartment,
                hint: 'Select your department',
                icon: Icons.apartment_outlined,
                items: _facultyDepartments[_selectedFaculty] ?? [],
                onChanged:
                    (value) => setState(() => _selectedDepartment = value),
                fontSize: 13,
              ),
            ] else if (!_isEditing &&
                (_userData?['facultyDepartment'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildFieldLabel('Department'),
              const SizedBox(height: 8),
              _buildReadOnlyField(_userData!['facultyDepartment']),
            ],
          ],

          const SizedBox(height: 20),

          // Phone Number
          _buildFieldLabel('Phone Number'),
          const SizedBox(height: 8),
          _isEditing
              ? _buildEditTextField(
                controller: _phoneController,
                hint: 'Enter your phone number',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              )
              : _buildReadOnlyField(
                _userData?['phoneNumber'] ?? 'Not provided',
              ),

          // Save button at bottom of section in edit mode
          if (_isEditing) ...[
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryOrange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child:
                    _isSaving
                        ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helper widgets ──

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: AppStyles.bodySmall.copyWith(
        color: AppColors.textGray,
        fontSize: 13,
      ),
    );
  }

  Widget _buildReadOnlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        value,
        style: AppStyles.bodyMedium.copyWith(color: AppColors.textDark),
      ),
    );
  }

  Widget _buildEditTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    double fontSize = 14,
  }) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      value: value as String?,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 20),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      items:
          items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Text(
                item,
                style: TextStyle(fontSize: fontSize),
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildSecuritySection() {
    return Container(
      color: AppColors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showChangePasswordDialog();
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
      showDialog(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.royalBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('No Password', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
              content: const Text(
                'This account uses Google sign-in and doesn\'t have a password to change.',
                style: TextStyle(fontSize: 14),
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
                  child: const Text('Reset'),
                ),
              ],
            ),
      );
      return;
    }

    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) {
              bool obscureCurrent = true;
              bool obscureNew = true;
              bool obscureConfirm = true;
              bool isSubmitting = false;

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: AppColors.royalBlue,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Text('Change Password'),
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
                                if (mounted) {
                                  Navigator.pop(dialogContext, true);
                                }
                              } catch (e) {
                                if (mounted) {
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

    if (result == true && mounted) {
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
    final emailFromData = _userData?['email']?.toString();
    if (emailFromData != null && emailFromData.isNotEmpty) {
      emailController.text = emailFromData;
    } else if (_authService.currentUser?.email != null) {
      emailController.text = _authService.currentUser!.email!;
    }

    final result = await showDialog<String?>(
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
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your email address and we\'ll send you a link to reset your password.',
                    style: TextStyle(fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
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
                  final email = emailController.text.trim();
                  if (email.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter your email address'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, email);
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

    if (result != null && mounted) {
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
        await _authService.resetPassword(result);
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
  }

  Widget _buildAccountSection() {
    return Container(
      color: AppColors.white,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _showDeleteAccountDialog();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              'Delete Account',
              style: AppStyles.bodyMedium.copyWith(
                color: const Color(0xFFDC3545),
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
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Delete Account',
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
                        'This action cannot be undone!',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This will permanently remove:\n• Your profile\n• All reports\n• Chat history\n• All data',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                      const SizedBox(height: 12),
                      if (!isGoogleSignIn) ...[
                        const Text(
                          'Enter password to confirm:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: passwordController,
                          obscureText: obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                              onPressed:
                                  () => setDialogState(
                                    () => obscurePassword = !obscurePassword,
                                  ),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                        ),
                      ] else ...[
                        const Text(
                          'You will be asked to sign in with Google to confirm.',
                          style: TextStyle(
                            fontSize: 12,
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
                    child: const Text('Delete'),
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
        MaterialPageRoute(builder: (_) => const HomeScreen()),
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
                  Icon(Icons.error_outline, color: Colors.red, size: 24),
                  SizedBox(width: 8),
                  Text('Error', style: TextStyle(fontSize: 16)),
                ],
              ),
              content: Text(e.toString(), style: const TextStyle(fontSize: 14)),
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
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_library_outlined,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadProfilePhoto(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.royalBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.royalBlue,
                    ),
                  ),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUploadProfilePhoto(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.red),
                  ),
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
      final ImagePicker imagePicker = ImagePicker();
      final picked = await imagePicker.pickImage(
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
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Uploading...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
      );

      try {
        await _authService.updateProfilePhoto(imageFile: picked);
        await _loadUserData();

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: AppColors.primaryGreen,
            ),
          );
        }
      } catch (storageError) {
        if (mounted) {
          Navigator.pop(context);

          // Show more specific error message
          String errorMessage = 'Failed to upload profile picture';
          if (storageError.toString().contains('StorageException')) {
            errorMessage =
                'Storage service unavailable. Please check your internet connection and try again.';
          } else if (storageError.toString().contains('permission')) {
            errorMessage = 'Permission denied. Please contact support.';
          } else if (storageError.toString().contains('cancelled')) {
            errorMessage = 'Upload was cancelled. Please try again.';
          }

          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Upload Failed'),
                  content: Text(errorMessage),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _pickAndUploadProfilePhoto(source); // Retry
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting photo: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
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
            backgroundColor: AppColors.primaryGreen,
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
}
