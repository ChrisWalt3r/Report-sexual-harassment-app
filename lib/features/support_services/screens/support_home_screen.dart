import 'package:flutter/material.dart';
import '../services/support_service.dart';
import '../models/emergency_contact.dart';
import '../widgets/emergency_button.dart';
import 'counseling_screen.dart';
import 'legal_guidance_screen.dart';
import 'emergency_contacts_screen.dart';
import 'medical_support_screen.dart';
import '../constants/emergency_constants.dart';
import '../../../constants/app_colors.dart';

/// Main hub for all support services
/// Designed with victim-centered, trauma-informed approach
class SupportHomeScreen extends StatefulWidget {
  const SupportHomeScreen({super.key});

  @override
  State<SupportHomeScreen> createState() => _SupportHomeScreenState();
}

class _SupportHomeScreenState extends State<SupportHomeScreen> {
  final SupportService _supportService = SupportService();
  List<EmergencyContact> _priorityContacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPriorityContacts();
  }

  Future<void> _loadPriorityContacts() async {
    try {
      final contacts = await _supportService.getPriorityEmergencyContacts();
      setState(() {
        _priorityContacts = contacts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _supportService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Support Services',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        toolbarHeight: 65,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              
              // Emergency quick access
              if (_priorityContacts.isNotEmpty) ...[
                _buildSectionHeader('Emergency Help', Icons.emergency_rounded, Colors.red),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: EmergencyButton(
                    label: EmergencyConstants.emergencyLabel,
                    phoneNumber: EmergencyConstants.emergencyNumber,
                    backgroundColor: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Support service categories
              _buildSectionHeader('Support Resources', Icons.support_agent_rounded, AppColors.royalBlue),
              const SizedBox(height: 12),
              _buildServiceGrid(),
              
              const SizedBox(height: 24),
              
              // Confidentiality notice
              _buildConfidentialityNotice(),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceGrid() {
    final services = [
      _ServiceItem(
        title: 'Counseling',
        subtitle: 'Professional support',
        icon: Icons.psychology_rounded,
        color: AppColors.royalBlue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CounselingScreen()),
        ),
      ),
      _ServiceItem(
        title: 'Legal Help',
        subtitle: 'Know your rights',
        icon: Icons.gavel_rounded,
        color: AppColors.secondaryOrange,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LegalGuidanceScreen()),
        ),
      ),
      _ServiceItem(
        title: 'Emergency',
        subtitle: 'Immediate help',
        icon: Icons.emergency_rounded,
        color: Colors.red[600]!,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
        ),
      ),
      _ServiceItem(
        title: 'Medical',
        subtitle: 'Health services',
        icon: Icons.local_hospital_rounded,
        color: AppColors.primaryGreen,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MedicalSupportScreen()),
        ),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          return _buildServiceCard(service);
        },
      ),
    );
  }

  Widget _buildServiceCard(_ServiceItem service) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: service.color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: service.color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: service.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: service.color,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: service.color.withOpacity(0.3),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    service.icon,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  service.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  service.subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: service.color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Access',
                        style: TextStyle(
                          color: service.color,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(Icons.arrow_forward_rounded, color: service.color, size: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickTipsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                    color: AppColors.mustGold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lightbulb_rounded, color: AppColors.mustGold, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Remember',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTipItem(
              icon: Icons.check_circle_rounded,
              color: AppColors.mustGreen,
              text: 'It\'s not your fault',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              icon: Icons.schedule_rounded,
              color: AppColors.mustBlue,
              text: 'Take your time - there\'s no rush',
            ),
            const SizedBox(height: 12),
            _buildTipItem(
              icon: Icons.people_rounded,
              color: AppColors.mustGold,
              text: 'You deserve support and care',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipItem({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfidentialityNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.royalBlue.withOpacity(0.05),
            AppColors.royalBlue.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.royalBlue.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.royalBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.shield_rounded, color: AppColors.royalBlue, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your Privacy Matters',
                  style: TextStyle(
                    color: AppColors.royalBlue,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'All interactions are encrypted and confidential. Your safety is our priority.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ServiceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
