import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/legal_resource.dart';
import '../services/support_service.dart';
import '../widgets/support_card.dart';

/// Screen displaying legal resources and guidance
class LegalGuidanceScreen extends StatefulWidget {
  const LegalGuidanceScreen({super.key});

  @override
  State<LegalGuidanceScreen> createState() => _LegalGuidanceScreenState();
}

class _LegalGuidanceScreenState extends State<LegalGuidanceScreen> {
  final SupportService _supportService = SupportService();
  List<LegalResource> _resources = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadResources();
  }

  Future<void> _loadResources() async {
    try {
      final resources = await _supportService.getLegalResources();
      setState(() {
        _resources = resources;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load resources. Please try again.';
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
          _showLaunchError('Unable to start phone call. Please try again later.');
        }
      } else {
        _showLaunchError('Unable to start phone call. Please try again later.');
      }
    } catch (_) {
      _showLaunchError('Unable to start phone call. Please try again later.');
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
          _showLaunchError('Unable to open website. Please try again later.');
        }
      } else {
        _showLaunchError('Unable to open website. Please try again later.');
      }
    } catch (_) {
      _showLaunchError('Unable to open website. Please try again later.');
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
        title: const Text('Legal Guidance'),
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
              onPressed: _loadResources,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadResources,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Header info
          _buildInfoHeader(),
          const SizedBox(height: 16),
          
          // Resources list
          ..._resources.map((resource) => _buildResourceCard(resource)),
        ],
      ),
    );
  }

  Widget _buildInfoHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gavel, color: Colors.indigo.shade400),
              const SizedBox(width: 12),
              Text(
                'Know Your Rights',
                style: TextStyle(
                  color: Colors.indigo.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You have legal options and protections. These resources can help you understand your rights and connect with legal support.',
            style: TextStyle(
              color: Colors.indigo.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceCard(LegalResource resource) {
    final tags = <Widget>[
      ServiceTag(
        label: resource.resourceType.displayName,
        color: Colors.indigo,
      ),
    ];
    
    if (resource.providesFreeConsultation) {
      tags.add(const ServiceTag(label: 'Free Consultation', color: Colors.green));
    }

    final actions = <SupportCardAction>[];
    
    if (resource.contactNumber != null) {
      actions.add(SupportCardAction(
        label: 'Call',
        icon: Icons.phone,
        onPressed: () => _makePhoneCall(resource.contactNumber!),
        color: Colors.green,
      ));
    }
    
    if (resource.website != null) {
      actions.add(SupportCardAction(
        label: 'Learn More',
        icon: Icons.language,
        onPressed: () => _openWebsite(resource.website!),
        color: Colors.blue,
      ));
    }

    return SupportCard(
      title: resource.title,
      description: resource.description,
      icon: Icons.gavel,
      iconColor: Colors.indigo,
      tags: tags,
      actions: actions,
      onTap: () => _showResourceDetails(resource),
    );
  }

  void _showResourceDetails(LegalResource resource) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                resource.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                resource.resourceType.displayName,
                style: TextStyle(
                  color: Colors.indigo.shade600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                resource.description,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
              if (resource.servicesOffered.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'Services Offered:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...resource.servicesOffered.map(
                  (service) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, 
                            color: Colors.green.shade400, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(service)),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
