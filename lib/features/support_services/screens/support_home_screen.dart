import 'package:flutter/material.dart';
import '../services/support_service.dart';
import '../models/emergency_contact.dart';
import '../widgets/emergency_button.dart';
import 'counseling_screen.dart';
import 'legal_guidance_screen.dart';
import 'emergency_contacts_screen.dart';
import 'medical_support_screen.dart';
import '../constants/emergency_constants.dart';

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
  // ignore: unused_field
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
      appBar: AppBar(
        title: const Text('Support Services'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reassurance message
              _buildReassuranceSection(),
              
              const SizedBox(height: 16),
              
              // Emergency quick access
              if (_priorityContacts.isNotEmpty) ...[
                _buildSectionHeader('Emergency Help'),
                EmergencyButton(
                  label: EmergencyConstants.emergencyLabel,
                  phoneNumber: EmergencyConstants.emergencyNumber,
                  backgroundColor: Colors.red[700],
                ),
                const SizedBox(height: 8),
              ],
              
              const SizedBox(height: 16),
              
              // Support service categories
              _buildSectionHeader('Support Resources'),
              const SizedBox(height: 8),
              _buildServiceGrid(),
              
              const SizedBox(height: 24),
              
              // Confidentiality notice
              _buildConfidentialityNotice(),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReassuranceSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.teal.shade50,
            Colors.blue.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        children: [
          Icon(
            Icons.favorite,
            color: Colors.teal.shade400,
            size: 40,
          ),
          const SizedBox(height: 12),
          Text(
            'You Are Not Alone',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re here to support you. All services are confidential and you can reach out at your own pace.',
            textAlign: TextAlign.center,
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildServiceGrid() {
    final services = [
      _ServiceItem(
        title: 'Counseling',
        subtitle: 'Talk to someone',
        icon: Icons.psychology,
        color: Colors.purple,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CounselingScreen()),
        ),
      ),
      _ServiceItem(
        title: 'Legal Guidance',
        subtitle: 'Know your rights',
        icon: Icons.gavel,
        color: Colors.indigo,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LegalGuidanceScreen()),
        ),
      ),
      _ServiceItem(
        title: 'Emergency Contacts',
        subtitle: 'Quick access',
        icon: Icons.emergency,
        color: Colors.red,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmergencyContactsScreen()),
        ),
      ),
      _ServiceItem(
        title: 'Medical Support',
        subtitle: 'Health services',
        icon: Icons.local_hospital,
        color: Colors.teal,
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
          childAspectRatio: 1.1,
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        onTap: service.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: service.color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  service.icon,
                  color: service.color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                service.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                service.subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidentialityNotice() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.lock, color: Colors.grey.shade600, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your privacy is protected. All interactions are confidential.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
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
