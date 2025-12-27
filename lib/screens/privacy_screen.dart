import 'package:flutter/material.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy & Confidentiality'),
        centerTitle: true,
        backgroundColor: const Color(0xFF2f3293),
        foregroundColor: Colors.white,
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
                gradient: const LinearGradient(
                  colors: [Color(0xFF2f3293), Color(0xFF4c5ed9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
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
                    'We are committed to protecting your identity and information',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confidentiality Section
            _buildSection(
              icon: Icons.lock,
              title: 'Confidentiality',
              content:
                  'All reports and conversations are strictly confidential. Your information is only shared with authorized personnel directly involved in handling your case.',
            ),
            const SizedBox(height: 16),

            // Anonymous Reporting Section
            _buildSection(
              icon: Icons.visibility_off,
              title: 'Anonymous Reporting',
              content:
                  'You can submit reports without revealing your identity. Anonymous reports are taken seriously and investigated with the same priority as identified reports.',
            ),
            const SizedBox(height: 16),

            // Data Protection Section
            _buildSection(
              icon: Icons.security,
              title: 'Data Protection',
              content:
                  'Your data is encrypted and stored securely. We follow strict data protection protocols to ensure your information is safe from unauthorized access.',
            ),
            const SizedBox(height: 16),

            // Your Rights Section
            _buildSection(
              icon: Icons.gavel,
              title: 'Your Rights',
              content:
                  'You have the right to:\n• Access your submitted reports\n• Request deletion of your data\n• Choose what information to share\n• Withdraw from the process at any time',
            ),
            const SizedBox(height: 16),

            // No Retaliation Section
            _buildSection(
              icon: Icons.verified_user,
              title: 'Protection from Retaliation',
              content:
                  'MUST has a strict no-retaliation policy. Anyone who reports harassment in good faith is protected from any form of retaliation or adverse action.',
            ),
            const SizedBox(height: 16),

            // Contact Section
            _buildSection(
              icon: Icons.help_outline,
              title: 'Questions?',
              content:
                  'If you have concerns about privacy or confidentiality, contact the Gender Desk Officer or the Dean of Students office.',
            ),
            const SizedBox(height: 24),

            // Acknowledgment
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade600),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'By using this app, your privacy is automatically protected under MUST policies.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2f3293).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF2f3293), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
