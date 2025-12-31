import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/emergency_contact.dart';
import '../services/support_service.dart';
import '../widgets/emergency_button.dart';
import '../constants/emergency_constants.dart';

/// Screen displaying emergency contacts for quick access
class EmergencyContactsScreen extends StatefulWidget {
  const EmergencyContactsScreen({super.key});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  final SupportService _supportService = SupportService();
  List<EmergencyContact> _contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    final contacts = await _supportService.getEmergencyContacts();
    contacts.sort((a, b) => a.priority.compareTo(b.priority));
    setState(() {
      _contacts = contacts;
      _isLoading = false;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        final bool launched = await launchUrl(phoneUri);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not start phone call.')),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Phone calls are not supported on this device.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred while trying to place the call.')),
        );
      }
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
        title: const Text('Emergency Contacts'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildUrgentNotice(),
                const SizedBox(height: 16),
                EmergencyButton(
                  label: EmergencyConstants.immediateDangerLabel,
                  phoneNumber: EmergencyConstants.emergencyNumber,
                ),
                const SizedBox(height: 24),
                ..._contacts.map((c) => _buildContactCard(c)),
              ],
            ),
    );
  }

  Widget _buildUrgentNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'If you are in immediate danger, call 911 immediately.',
              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(EmergencyContact contact) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(contact.category),
          child: Icon(_getCategoryIcon(contact.category), color: Colors.white, size: 20),
        ),
        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(contact.description ?? contact.category.displayName),
        trailing: IconButton(
          icon: const Icon(Icons.phone, color: Colors.green),
          onPressed: () => _makePhoneCall(contact.phoneNumber),
        ),
        onTap: () => _makePhoneCall(contact.phoneNumber),
      ),
    );
  }

  Color _getCategoryColor(EmergencyCategory category) {
    switch (category) {
      case EmergencyCategory.police: return Colors.blue;
      case EmergencyCategory.medical: return Colors.red;
      case EmergencyCategory.crisisHotline: return Colors.purple;
      case EmergencyCategory.womenShelter: return Colors.pink;
      case EmergencyCategory.legalAid: return Colors.indigo;
      case EmergencyCategory.general: return Colors.grey;
    }
  }

  IconData _getCategoryIcon(EmergencyCategory category) {
    switch (category) {
      case EmergencyCategory.police: return Icons.local_police;
      case EmergencyCategory.medical: return Icons.local_hospital;
      case EmergencyCategory.crisisHotline: return Icons.phone_in_talk;
      case EmergencyCategory.womenShelter: return Icons.home;
      case EmergencyCategory.legalAid: return Icons.gavel;
      case EmergencyCategory.general: return Icons.emergency;
    }
  }
}
