import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        title: const Text('Terms of Service'),
        centerTitle: true,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        toolbarHeight: 65,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.royalBlue, AppColors.royalBlue.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.royalBlue.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(Icons.description, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Terms of Service',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'SafeReport App - MUST University Campus Safety Platform',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Acceptance Section
            _buildSection(
              context,
              icon: Icons.check_circle_outline,
              title: 'Acceptance of Terms',
              content: 'By accessing and using the SafeReport application, you accept and agree to be bound by the terms and provision of this agreement. This app is provided by Mbarara University of Science and Technology (MUST) for campus safety and harassment reporting.',
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 16),

            // Use of Service Section
            _buildSection(
              context,
              icon: Icons.security_outlined,
              title: 'Use of Service',
              content: 'SafeReport is designed exclusively for reporting incidents of sexual harassment and seeking support within the MUST campus community. Users must:\n\n• Provide accurate and truthful information\n• Use the service responsibly and in good faith\n• Respect the confidentiality of others\n• Not misuse the platform for false reporting\n• Comply with MUST policies and Ugandan law',
              color: AppColors.secondaryOrange,
            ),
            const SizedBox(height: 16),

            // User Responsibilities Section
            _buildSection(
              context,
              icon: Icons.person_outline,
              title: 'User Responsibilities',
              content: 'As a user of SafeReport, you are responsible for:\n\n• Maintaining the confidentiality of your account\n• Reporting genuine incidents only\n• Providing accurate contact information when required\n• Cooperating with official investigations when necessary\n• Respecting the privacy and dignity of all parties involved',
              color: AppColors.royalBlue,
            ),
            const SizedBox(height: 16),

            // Privacy and Data Section
            _buildSection(
              context,
              icon: Icons.privacy_tip_outlined,
              title: 'Privacy and Data Protection',
              content: 'MUST is committed to protecting your privacy and personal data in accordance with:\n\n• Uganda Data Protection and Privacy Act\n• MUST University data protection policies\n• International best practices for sensitive data handling\n\nFor detailed information, please refer to our Privacy Policy.',
              color: AppColors.maroon,
            ),
            const SizedBox(height: 16),

            // Prohibited Activities Section
            _buildSection(
              context,
              icon: Icons.block_outlined,
              title: 'Prohibited Activities',
              content: 'The following activities are strictly prohibited:\n\n• Making false or malicious reports\n• Attempting to identify anonymous reporters\n• Sharing confidential information outside the platform\n• Using the service for harassment or intimidation\n• Attempting to hack or compromise the system\n• Violating any applicable laws or regulations',
              color: AppColors.error,
            ),
            const SizedBox(height: 16),

            // Limitation of Liability Section
            _buildSection(
              context,
              icon: Icons.gavel_outlined,
              title: 'Limitation of Liability',
              content: 'MUST provides SafeReport as a support tool for campus safety. While we strive to maintain the highest standards of service:\n\n• The app is provided "as is" without warranties\n• MUST is not liable for technical issues or service interruptions\n• Users are encouraged to also report serious incidents through official channels\n• Emergency situations should be reported to appropriate authorities immediately',
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 16),

            // Modifications Section
            _buildSection(
              context,
              icon: Icons.update_outlined,
              title: 'Modifications to Terms',
              content: 'MUST reserves the right to modify these terms at any time. Users will be notified of significant changes through:\n\n• In-app notifications\n• Email communications\n• University official channels\n\nContinued use of the app after modifications constitutes acceptance of the updated terms.',
              color: AppColors.royalBlue,
            ),
            const SizedBox(height: 16),

            // Contact Information Section
            _buildSection(
              context,
              icon: Icons.contact_support_outlined,
              title: 'Contact Information',
              content: 'For questions about these Terms of Service, contact:\n\n• MUST Gender Desk Office\n• Dean of Students Office\n• University Legal Office\n• ICT Support Services\n\nEmail: safereport@must.ac.ug\nPhone: +256-485-420512',
              color: AppColors.secondaryOrange,
            ),
            const SizedBox(height: 24),

            // Effective Date
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark 
                    ? AppColors.primaryGreen.withOpacity(0.1) 
                    : AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.calendar_today, 
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Effective Date',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'These Terms of Service are effective as of January 1, 2024, and apply to all users of the SafeReport application.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: const Text('Back'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primaryGreen,
                      side: const BorderSide(color: AppColors.primaryGreen),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Show acceptance confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Terms acknowledged. Thank you for using SafeReport responsibly.'),
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check, size: 18, color: Colors.white),
                    label: const Text(
                      'I Understand',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark 
              ? color.withOpacity(0.2) 
              : color.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}