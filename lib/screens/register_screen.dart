import 'package:flutter/material.dart';
import 'package:report_harassment/constants/app_colors.dart';
import 'package:report_harassment/services/auth_service.dart';
import 'package:report_harassment/widgets/custom_text_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  final _emailController = TextEditingController();
  final _facultyController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Role selection
  String? _selectedRole;
  final List<String> _roles = ['Student', 'Staff', 'Other'];

  // Gender selection
  String? _selectedGender;
  final List<String> _genders = ['Male', 'Female'];

  // Study level (for students)
  String? _selectedStudyLevel;
  final List<String> _studyLevels = ['Undergraduate', 'Postgraduate'];
  
  final List<String> _faculties = [
    'Faculty of Medicine',
    'Faculty of Science',
    'Faculty of Computing and Informatics',
    'Faculty of Applied Sciences and Technology',
    'Faculty of Business and Management Sciences',
    'Faculty of Interdisciplinary Studies',
  ];
  
  String? _selectedFaculty;
  String? _selectedDepartment;

  // Faculty → Departments mapping
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
    _fullNameController.dispose();
    _studentIdController.dispose();
    _emailController.dispose();
    _facultyController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    // Temporarily bypass validation to test registration
    // Check if basic required fields have content
    if (_fullNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _studentIdController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _selectedRole == null ||
        _selectedGender == null ||
        _selectedFaculty == null) {
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill in: ${_getMissingFields()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        studentId: _studentIdController.text.trim(),
        department: _selectedFaculty ?? _facultyController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
        role: _selectedRole ?? '',
        studyLevel: _selectedStudyLevel ?? '',
        facultyDepartment: _selectedDepartment ?? '',
        gender: _selectedGender ?? '',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account created successfully! Please login to continue.'),
            backgroundColor: AppColors.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Sign out the user after registration
        await _authService.signOut();
        
        // Navigate back to login screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getMissingFields() {
    List<String> missing = [];
    if (_fullNameController.text.trim().isEmpty) missing.add('Full Name');
    if (_emailController.text.trim().isEmpty) missing.add('Email');
    if (_passwordController.text.trim().isEmpty) missing.add('Password');
    if (_studentIdController.text.trim().isEmpty) missing.add('ID');
    if (_phoneController.text.trim().isEmpty) missing.add('Phone');
    if (_selectedRole == null) missing.add('Role');
    if (_selectedGender == null) missing.add('Gender');
    if (_selectedFaculty == null) missing.add('Faculty');
    if (_selectedRole == 'Student' && _selectedStudyLevel == null) missing.add('Study Level');
    if (_selectedFaculty != null && _selectedDepartment == null) missing.add('Department');
    
    return missing.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white, // White background like welcome and login screens
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // Back button
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Back to Login',
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // App Logo/Icon - Same as welcome and login screens
                ClipOval(
                  child: Image.asset(
                    'assets/icon/app_icon_circle.jpeg',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Create Account Title
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textPrimary,
                    letterSpacing: 1.2,
                  ),
                ),
                
                const SizedBox(height: 6),
                
                const Text(
                  'SafeReport',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: AppColors.royalBlue,
                    letterSpacing: 1.5,
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Subtitle
                const Text(
                  'Join us to report safely and confidentially.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                
                const SizedBox(height: 32),

                // Full Name
                CustomTextField(
                  controller: _fullNameController,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  prefixIcon: Icons.person_outline,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Role Dropdown
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'I am a...',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    hintText: 'Select your role',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
                    prefixIcon: Icon(Icons.people_outline, color: AppColors.royalBlue),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.inputFill,
                  ),
                  items: _roles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role, style: const TextStyle(color: Colors.black)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedRole = value;
                      // Reset study level when role changes
                      if (value != 'Student') {
                        _selectedStudyLevel = null;
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

                // Gender Dropdown
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    hintText: 'Select your gender',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
                    prefixIcon: Icon(Icons.wc_outlined, color: AppColors.royalBlue),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.inputFill,
                  ),
                  items: _genders.map((gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(gender, style: const TextStyle(color: Colors.black)),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedGender = value),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your gender';
                    }
                    return null;
                  },
                ),

                // Study Level Dropdown (only for Students)
                if (_selectedRole == 'Student') ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedStudyLevel,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Study Level',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      hintText: 'Select your study level',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
                      prefixIcon: Icon(Icons.menu_book_outlined, color: AppColors.royalBlue),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryGreen),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryGreen),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.error, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.inputFill,
                    ),
                    items: _studyLevels.map((level) {
                      return DropdownMenuItem(
                        value: level,
                        child: Text(level, style: const TextStyle(color: Colors.black)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedStudyLevel = value);
                    },
                    validator: (value) {
                      if (_selectedRole == 'Student' && (value == null || value.isEmpty)) {
                        return 'Please select your study level';
                      }
                      return null;
                    },
                  ),
                ],

                const SizedBox(height: 16),
                
                // Student ID
                CustomTextField(
                  controller: _studentIdController,
                  label: _selectedRole == 'Staff' ? 'Staff ID' : _selectedRole == 'Other' ? 'ID Number' : 'Student ID',
                  hint: _selectedRole == 'Staff' ? 'Enter your staff ID' : _selectedRole == 'Other' ? 'Enter your ID number' : 'Enter your student ID',
                  prefixIcon: Icons.badge_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your ID';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Email
                CustomTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  hint: 'Enter your email address',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email address';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Faculty Dropdown
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedFaculty,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Faculty',
                    labelStyle: TextStyle(color: AppColors.textSecondary),
                    hintText: 'Select your faculty',
                    hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
                    prefixIcon: Icon(Icons.school_outlined, color: AppColors.royalBlue),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.error, width: 2),
                    ),
                    filled: true,
                    fillColor: AppColors.inputFill,
                  ),
                  items: _faculties.map((faculty) {
                    return DropdownMenuItem(
                      value: faculty,
                      child: Text(
                        faculty,
                        style: const TextStyle(fontSize: 13, color: Colors.black),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFaculty = value;
                      _selectedDepartment = null; // Reset department on faculty change
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select your faculty';
                    }
                    return null;
                  },
                ),

                // Department Dropdown (shown after faculty is selected)
                if (_selectedFaculty != null) ...[
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: _selectedDepartment,
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: 'Department',
                      labelStyle: TextStyle(color: AppColors.textSecondary),
                      hintText: 'Select your department',
                      hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.6)),
                      prefixIcon: Icon(Icons.apartment_outlined, color: AppColors.royalBlue),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryGreen),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryGreen),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.error, width: 2),
                      ),
                      filled: true,
                      fillColor: AppColors.inputFill,
                    ),
                    items: (_facultyDepartments[_selectedFaculty] ?? []).map((dept) {
                      return DropdownMenuItem(
                        value: dept,
                        child: Text(
                          dept,
                          style: const TextStyle(fontSize: 13, color: Colors.black),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedDepartment = value);
                    },
                    validator: (value) {
                      if (_selectedFaculty != null && (value == null || value.isEmpty)) {
                        return 'Please select your department';
                      }
                      return null;
                    },
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Phone Number
                CustomTextField(
                  controller: _phoneController,
                  label: 'Phone Number',
                  hint: 'Enter your phone number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Password
                CustomTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Create a password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                
                
                const SizedBox(height: 32),
                
                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryOrange,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add, size: 24),
                              SizedBox(width: 12),
                              Text(
                                'Create Account',
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
                
                const SizedBox(height: 16),
                
                // Terms and Conditions
                Text(
                  'By creating an account, you agree to our Terms of Service and Privacy Policy',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
