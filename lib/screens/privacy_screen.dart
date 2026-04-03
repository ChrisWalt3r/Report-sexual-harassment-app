import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        title: const Text('Privacy & Confidentiality'),
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
                  Icon(Icons.shield, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'Your Privacy Matters',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'We are committed to protecting your identity and information under MUST policies',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confidentiality Section
            _buildSection(
              context,
              icon: Icons.lock_outline,
              title: 'Confidentiality',
              content: 'All reports and conversations are strictly confidential. Your information is only shared with authorized MUST personnel directly involved in handling your case, including the Gender-Based Violence Committee and designated investigation officers.',
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 16),

            // Anonymous Reporting Section
            _buildSection(
              context,
              icon: Icons.visibility_off_outlined,
              title: 'Anonymous Reporting',
              content: 'You can submit reports without revealing your identity. Anonymous reports are taken seriously and investigated with the same priority as identified reports. You\'ll receive a unique tracking token to follow your case progress.',
              color: AppColors.secondaryOrange,
            ),
            const SizedBox(height: 16),

            // Data Protection Section
            _buildSection(
              context,
              icon: Icons.security_outlined,
              title: 'Data Protection',
              content: 'Your data is encrypted using industry-standard protocols and stored securely on MUST-approved servers. We follow strict data protection guidelines to ensure your information is safe from unauthorized access.',
              color: AppColors.royalBlue,
            ),
            const SizedBox(height: 16),

            // Your Rights Section
            _buildSection(
              context,
              icon: Icons.gavel_outlined,
              title: 'Your Rights',
              content: 'Under MUST policy, you have the right to:\n\n• Access and review your submitted reports\n• Request updates on investigation progress\n• Choose what information to share\n• Withdraw from the process at any time\n• Request data deletion (subject to legal requirements)\n• Receive support services regardless of report outcome',
              color: AppColors.maroon,
            ),
            const SizedBox(height: 16),

            // No Retaliation Section
            _buildSection(
              context,
              icon: Icons.verified_user_outlined,
              title: 'Protection from Retaliation',
              content: 'MUST has a zero-tolerance policy for retaliation. Anyone who reports harassment in good faith is protected from any form of retaliation, adverse action, or discrimination. Retaliation itself is a serious offense that will be investigated and punished.',
              color: AppColors.primaryGreen,
            ),
            const SizedBox(height: 16),

            // Legal Compliance Section
            _buildSection(
              context,
              icon: Icons.policy_outlined,
              title: 'Legal Compliance',
              content: 'Our privacy practices comply with:\n\n• Uganda Data Protection and Privacy Act\n• MUST University policies and procedures\n• International best practices for educational institutions\n• Confidentiality requirements for sensitive reporting',
              color: AppColors.royalBlue,
            ),
            const SizedBox(height: 16),

            // Contact Section
            _buildSection(
              context,
              icon: Icons.help_outline,
              title: 'Questions About Privacy?',
              content: 'If you have concerns about privacy, confidentiality, or data handling, contact:\n\n• Gender Desk Officer\n• Dean of Students Office\n• University Legal Office\n• Data Protection Officer\n\nAll inquiries are handled confidentially.',
              color: AppColors.secondaryOrange,
            ),
            const SizedBox(height: 24),

            // Acknowledgment
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
                    Icons.check_circle_outline, 
                    color: AppColors.primaryGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy Protection Guarantee',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By using SafeReport, your privacy is automatically protected under MUST policies. Your courage to speak up is valued and protected.',
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
                      // Navigate to support or contact
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Contact information available in Support Services'),
                          backgroundColor: AppColors.primaryGreen,
                        ),
                      );
                    },
                    icon: const Icon(Icons.contact_support, size: 18, color: Colors.white),
                    label: const Text(
                      'Get Support',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white, // Force white text
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