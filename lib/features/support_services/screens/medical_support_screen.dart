import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/medical_support.dart';
import '../services/support_service.dart';
import '../widgets/support_card.dart';

/// Screen displaying medical support resources
class MedicalSupportScreen extends StatefulWidget {
  const MedicalSupportScreen({super.key});

  @override
  State<MedicalSupportScreen> createState() => _MedicalSupportScreenState();
}

class _MedicalSupportScreenState extends State<MedicalSupportScreen> {
  final SupportService _supportService = SupportService();
  List<MedicalSupport> _resources = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    final resources = await _supportService.getMedicalSupport();
    setState(() {
      _resources = resources;
      _isLoading = false;
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
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
        title: const Text('Medical Support'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadResources,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                children: [
                  _buildInfoHeader(),
                  const SizedBox(height: 16),
                  ..._resources.map((r) => _buildResourceCard(r)),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.health_and_safety, color: Colors.teal.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Medical care is available and confidential. You deserve proper healthcare and support.',
              style: TextStyle(color: Colors.teal.shade700, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(MedicalSupport resource) {
    final tags = <Widget>[
      ServiceTag(label: resource.serviceType.displayName, color: Colors.teal),
    ];
    if (resource.hasSpecializedUnit) {
      tags.add(const ServiceTag(label: 'Specialized Care', color: Colors.purple));
    }
    if (resource.isConfidential) {
      tags.add(const ServiceTag(label: 'Confidential', color: Colors.orange));
    }

    final actions = <SupportCardAction>[];
    if (resource.phoneNumber != null) {
      actions.add(SupportCardAction(
        label: 'Call',
        icon: Icons.phone,
        onPressed: () => _makePhoneCall(resource.phoneNumber!),
        color: Colors.green,
      ));
    }

    return SupportCard(
      title: resource.facilityName,
      description: resource.description,
      icon: Icons.local_hospital,
      iconColor: Colors.teal,
      tags: tags,
      actions: actions,
    );
  }
}
