import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import 'home_screen.dart';

class AnonymousInfoScreen extends StatefulWidget {
  const AnonymousInfoScreen({super.key});

  @override
  State<AnonymousInfoScreen> createState() => _AnonymousInfoScreenState();
}

class _AnonymousInfoScreenState extends State<AnonymousInfoScreen> {
  final _formKey = GlobalKey<FormState>();

  // Required fields
  String? _selectedRole;
  String? _selectedGender;
  final _otherRoleController = TextEditingController();

  // Optional fields
  String? _selectedFaculty;
  String? _selectedDepartment;

  final List<String> _roles = ['Student', 'Staff', 'Other'];
  final List<String> _genders = ['Male', 'Female', 'Prefer not to say'];

  final List<String> _faculties = [
    'Faculty of Medicine',
    'Faculty of Science',
    'Faculty of Computing and Informatics',
    'Faculty of Applied Sciences and Technology',
    'Faculty of Business and Management Sciences',
    'Faculty of Interdisciplinary Studies',
  ];

  final Map<String, List<String>> _facultyDepartments = {
    'Faculty of Medicine': [
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
    'Faculty of Science': [
      'Biology',
      'Chemistry',
      'Physics',
      'Mathematics',
    ],
    'Faculty of Computing and Informatics': [
      'Computer Science',
      'Information Technology',
      'Software Engineering',
    ],
    'Faculty of Applied Sciences and Technology': [
      'Biomedical Sciences & Engineering',
      'Civil Engineering',
      'Electrical & Electronics Engineering',
      'Mechanical Engineering',
      'Petroleum & Environmental Management',
    ],
    'Faculty of Business and Management Sciences': [
      'Accounting & Finance',
      'Business Administration',
      'Economics',
      'Procurement & Supply Chain Management',
      'Marketing & Entrepreneurship',
    ],
    'Faculty of Interdisciplinary Studies': [
      'Planning & Governance',
      'Human Development & Relational Sciences',
      'Environment & Livelihood Support Systems',
      'Community Engagement & Service Learning',
    ],
  };

  @override
  void dispose() {
    _otherRoleController.dispose();
    super.dispose();
  }

  InputDecoration _dropdownDecoration({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.mustBlue, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  void _handleContinue() {
    if (!_formKey.currentState!.validate()) return;

    // Store anonymous session info for statistics
    final anonymousInfo = {
      'role': _selectedRole == 'Other' ? _otherRoleController.text.trim() : _selectedRole,
      'gender': _selectedGender,
      'faculty': _selectedFaculty ?? '',
      'department': _selectedDepartment ?? '',
    };

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(anonymousInfo: anonymousInfo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.mustBlue,
              AppColors.mustBlueMedium,
            ],
            stops: [0.0, 0.4],
          ),
        ),
        child: Column(
          children: [
            // App Bar
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(
                        color: AppColors.mustGold,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.visibility_off_outlined,
                      size: 28,
                      color: AppColors.mustBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Quick Info',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Help us understand the community better',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.85),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                ],
              ),
            ),

            // Form card
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Privacy assurance
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.mustBlue.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.mustBlue.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: AppColors.mustGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Your identity stays anonymous. This info is only used for statistics.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Section: Required
                        Text(
                          'Required',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mustBlue,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Role dropdown
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: _dropdownDecoration(
                            label: 'I am a...',
                            hint: 'Select your role',
                            icon: Icons.people_outline,
                          ),
                          items: _roles.map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedRole = value;
                              if (value != 'Other') {
                                _otherRoleController.clear();
                              }
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your role';
                            }
                            return null;
                          },
                        ),

                        // Custom role text field when "Other" is selected
                        if (_selectedRole == 'Other') ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _otherRoleController,
                            decoration: _dropdownDecoration(
                              label: 'Specify your role',
                              hint: 'e.g. Cleaner, Security, Cook...',
                              icon: Icons.edit_outlined,
                            ),
                            validator: (value) {
                              if (_selectedRole == 'Other' && (value == null || value.trim().isEmpty)) {
                                return 'Please specify your role';
                              }
                              return null;
                            },
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Gender dropdown
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: _dropdownDecoration(
                            label: 'Gender',
                            hint: 'Select your gender',
                            icon: Icons.wc_outlined,
                          ),
                          items: _genders.map((gender) {
                            return DropdownMenuItem(
                              value: gender,
                              child: Text(gender),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedGender = value);
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select your gender';
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 24),

                        // Section: Optional
                        Text(
                          'Optional',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Faculty dropdown (optional)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedFaculty,
                          decoration: _dropdownDecoration(
                            label: 'Faculty (optional)',
                            hint: 'Select your faculty',
                            icon: Icons.school_outlined,
                          ),
                          items: _faculties.map((faculty) {
                            return DropdownMenuItem(
                              value: faculty,
                              child: Text(
                                faculty,
                                style: const TextStyle(fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedFaculty = value;
                              _selectedDepartment = null;
                            });
                          },
                        ),

                        // Department dropdown (optional, shown after faculty)
                        if (_selectedFaculty != null) ...[
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedDepartment,
                            decoration: _dropdownDecoration(
                              label: 'Department (optional)',
                              hint: 'Select your department',
                              icon: Icons.apartment_outlined,
                            ),
                            items: (_facultyDepartments[_selectedFaculty] ?? [])
                                .map((dept) {
                              return DropdownMenuItem(
                                value: dept,
                                child: Text(
                                  dept,
                                  style: const TextStyle(fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() => _selectedDepartment = value);
                            },
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Continue button
                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _handleContinue,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.mustGold,
                              foregroundColor: AppColors.mustBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 2,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.arrow_forward, size: 22),
                                SizedBox(width: 10),
                                Text(
                                  'Continue to Dashboard',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Skip link
                        Center(
                          child: TextButton(
                            onPressed: () {
                              // Still require role and gender before skipping
                              if (_selectedRole == null || _selectedGender == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Please select your role and gender before continuing.'),
                                    backgroundColor: AppColors.mustBlue,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                                return;
                              }
                              if (_selectedRole == 'Other' && _otherRoleController.text.trim().isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Please specify your role.'),
                                    backgroundColor: AppColors.mustBlue,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                );
                                return;
                              }
                              final anonymousInfo = {
                                'role': _selectedRole == 'Other' ? _otherRoleController.text.trim() : _selectedRole,
                                'gender': _selectedGender,
                                'faculty': '',
                                'department': '',
                              };
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => HomeScreen(anonymousInfo: anonymousInfo),
                                ),
                              );
                            },
                            child: Text(
                              'Skip optional fields',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
