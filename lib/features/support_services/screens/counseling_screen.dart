import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/counseling_service.dart';
import '../services/support_service.dart';
import '../widgets/support_card.dart';

/// Screen displaying available counseling services
class CounselingScreen extends StatefulWidget {
  const CounselingScreen({super.key});

  @override
  State<CounselingScreen> createState() => _CounselingScreenState();
}

class _CounselingScreenState extends State<CounselingScreen> {
  final SupportService _supportService = SupportService();
  List<CounselingService> _services = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    try {
      final services = await _supportService.getCounselingServices();
      setState(() {
        _services = services;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load services. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _showLaunchError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        final bool launched = await launchUrl(phoneUri);
        if (!launched) {
          _showLaunchError('Unable to place call. Please try again later.');
        }
      } else {
        _showLaunchError('Calling is not supported on this device.');
      }
    } catch (_) {
      _showLaunchError('An error occurred while trying to place the call.');
    }
  }

  Future<void> _openWebsite(String url) async {
    final Uri websiteUri = Uri.parse(url);
    try {
      if (await canLaunchUrl(websiteUri)) {
        final bool launched = await launchUrl(
          websiteUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          _showLaunchError('Unable to open the website. Please try again later.');
        }
      } else {
        _showLaunchError('Unable to open this link on your device.');
      }
    } catch (_) {
      _showLaunchError('An error occurred while trying to open the website.');
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
        title: const Text('Counseling Support'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadServices,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadServices,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Header info
          _buildInfoHeader(),
          const SizedBox(height: 16),
          
          // Service list
          ..._services.map((service) => _buildServiceCard(service)),
        ],
      ),
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.purple.shade400),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'All counseling services listed here are confidential. You can reach out whenever you feel ready.',
              style: TextStyle(
                color: Colors.purple.shade700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(CounselingService service) {
    final tags = <Widget>[];
    
    if (service.isAvailable24Hours) {
      tags.add(const ServiceTag(label: '24/7', color: Colors.green));
    }
    if (service.isFree) {
      tags.add(const ServiceTag(label: 'Free', color: Colors.blue));
    }
    if (service.isConfidential) {
      tags.add(const ServiceTag(label: 'Confidential', color: Colors.orange));
    }

    final actions = <SupportCardAction>[];
    
    if (service.contactNumber != 'N/A') {
      actions.add(SupportCardAction(
        label: 'Call',
        icon: Icons.phone,
        onPressed: () => _makePhoneCall(service.contactNumber),
        color: Colors.green,
      ));
    }
    
    if (service.website != null) {
      actions.add(SupportCardAction(
        label: 'Website',
        icon: Icons.language,
        onPressed: () => _openWebsite(service.website!),
        color: Colors.blue,
      ));
    }

    return SupportCard(
      title: service.name,
      description: service.description,
      icon: Icons.psychology,
      iconColor: Colors.purple,
      tags: tags,
      actions: actions,
    );
  }
}
