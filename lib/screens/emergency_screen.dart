import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../models/official_contact.dart';
import '../services/official_contacts_service.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  bool _isLoading = false;
  bool _isContactsLoading = true;
  final OfficialContactsService _officialContactsService = OfficialContactsService();
  List<EmergencyContact> _emergencyContacts = [];

  @override
  void initState() {
    super.initState();
    _loadEmergencyContacts();
  }

  Future<void> _loadEmergencyContacts() async {
    try {
      final contacts = await _officialContactsService.getContacts();
      final emergencyContacts = contacts
          .where((contact) =>
              (contact.phoneNumber ?? '').trim().isNotEmpty &&
              _isEmergencyCategory(contact.category))
          .map(_mapOfficialContactToEmergencyContact)
          .toList();

      if (!mounted) return;

      setState(() {
        _emergencyContacts = emergencyContacts;
        _isContactsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _emergencyContacts = [];
        _isContactsLoading = false;
      });
    }
  }

  bool _isEmergencyCategory(ContactCategory category) {
    return category == ContactCategory.security ||
        category == ContactCategory.police ||
        category == ContactCategory.counseling ||
        category == ContactCategory.medical ||
        category == ContactCategory.deanOfStudents ||
        category == ContactCategory.ashc ||
        category == ContactCategory.ushc ||
        category == ContactCategory.crisisHotline ||
        category == ContactCategory.genderDesk ||
        category == ContactCategory.womenShelter ||
        category == ContactCategory.legalServices ||
        category == ContactCategory.humanResources;
  }

  EmergencyContact _mapOfficialContactToEmergencyContact(OfficialContact contact) {
    final number = (contact.phoneNumber ?? '').trim();
    return EmergencyContact(
      name: contact.name,
      number: number,
      type: contact.category.displayName,
      icon: _iconForCategory(contact.category),
      color: _colorForCategory(contact.category),
      description: (contact.description?.trim().isNotEmpty ?? false)
          ? contact.description!.trim()
          : contact.title,
      category: contact.category,
    );
  }

  IconData _iconForCategory(ContactCategory category) {
    switch (category) {
      case ContactCategory.security:
        return Icons.security;
      case ContactCategory.police:
        return Icons.local_police;
      case ContactCategory.medical:
        return Icons.local_hospital;
      case ContactCategory.counseling:
        return Icons.psychology;
      case ContactCategory.deanOfStudents:
        return Icons.badge;
      case ContactCategory.ashc:
      case ContactCategory.ushc:
        return Icons.support_agent;
      case ContactCategory.crisisHotline:
        return Icons.phone_in_talk;
      case ContactCategory.genderDesk:
        return Icons.diversity_2;
      case ContactCategory.womenShelter:
        return Icons.home;
      case ContactCategory.legalServices:
        return Icons.gavel;
      case ContactCategory.humanResources:
        return Icons.people_alt;
      case ContactCategory.administration:
      case ContactCategory.other:
        return Icons.contact_phone;
    }
  }

  Color _colorForCategory(ContactCategory category) {
    switch (category) {
      case ContactCategory.security:
      case ContactCategory.ashc:
      case ContactCategory.ushc:
        return AppColors.mustBlue;
      case ContactCategory.deanOfStudents:
      case ContactCategory.genderDesk:
        return AppColors.mustGold;
      case ContactCategory.medical:
      case ContactCategory.counseling:
        return AppColors.mustGreen;
      case ContactCategory.police:
      case ContactCategory.crisisHotline:
        return Colors.red;
      case ContactCategory.womenShelter:
      case ContactCategory.legalServices:
      case ContactCategory.humanResources:
      case ContactCategory.administration:
      case ContactCategory.other:
        return AppColors.mustBlueMedium;
    }
  }

  EmergencyContact? _primaryEmergencyContact() {
    for (final contact in _emergencyContacts) {
      if (contact.category == ContactCategory.security ||
          contact.category == ContactCategory.police ||
          contact.category == ContactCategory.crisisHotline) {
        return contact;
      }
    }
    return _emergencyContacts.isNotEmpty ? _emergencyContacts.first : null;
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          _showErrorSnackBar('Could not launch phone call');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _sendSMS(String phoneNumber, String message) async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    final Uri launchUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {'body': message},
    );
    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        if (mounted) {
          _showErrorSnackBar('Could not launch SMS');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _activatePanicMode() {
    if (_isLoading) return;

    final primaryContact = _primaryEmergencyContact();
    if (primaryContact == null) {
      _showErrorSnackBar('No emergency contacts available. Please contact admin.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Emergency Alert'),
          ],
        ),
        content: const Text(
          'Emergency mode activated!\n\nYour location will be shared with campus security and emergency contacts will be notified.\n\nDo you want to call Campus Security now?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _makePhoneCall(primaryContact.number);
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text('CALL SECURITY NOW'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        centerTitle: true,
        toolbarHeight: 65,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Emergency Services',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showEmergencyInfo,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.15),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.emergency_rounded,
                            size: 44,
                            color: AppColors.error,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Need Immediate Help?',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Use panic mode to quickly reach security and emergency services.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          _buildPanicButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
              _buildSectionHeader('Quick Dial'),
              const SizedBox(height: 10),
              _buildQuickDialGrid(),

              const SizedBox(height: 22),
              _buildSectionHeader('All Emergency Contacts'),
              const SizedBox(height: 10),
              _buildEmergencyContactsList(),

              const SizedBox(height: 22),
              _buildSafetyTips(),
              const SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.grey.shade600,
          letterSpacing: 0.9,
        ),
      ),
    );
  }

  Widget _buildPanicButton() {
    return GestureDetector(
      onTap: _activatePanicMode,
      child: Container(
        width: 170,
        height: 58,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.error, Color(0xFFD32F2F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.crisis_alert,
              size: 24,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            const Text(
              'PANIC MODE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDialGrid() {
    if (_isContactsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_emergencyContacts.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'No emergency contacts are configured by admin yet.',
          style: TextStyle(fontSize: 13),
          textAlign: TextAlign.center,
        ),
      );
    }

    final quickDialContacts = _emergencyContacts.take(3).toList();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: quickDialContacts.map((contact) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildQuickDialButton(contact),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickDialButton(EmergencyContact contact) {
    return GestureDetector(
      onTap: () => _showContactOptions(contact),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: contact.color.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: contact.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                contact.icon,
                color: contact.color,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              contact.type,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              contact.number,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyContactsList() {
    if (_isContactsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_emergencyContacts.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'No emergency contacts found in Firebase. Ask admin to add active contacts with phone numbers.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _emergencyContacts.length,
        separatorBuilder: (context, index) => Divider(
          height: 1,
          color: Colors.grey.shade200,
        ),
        itemBuilder: (context, index) {
          final contact = _emergencyContacts[index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: contact.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(contact.icon, color: contact.color, size: 24),
            ),
            title: Text(
              contact.name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  contact.description,
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  contact.number,
                  style: TextStyle(
                    fontSize: 12,
                    color: contact.color,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.phone, color: Colors.green, size: 22),
                  onPressed: () => _makePhoneCall(contact.number),
                  tooltip: 'Call',
                ),
                IconButton(
                  icon: const Icon(Icons.message, color: AppColors.mustBlue, size: 22),
                  onPressed: () => _sendSMS(
                    contact.number,
                    'Emergency: I need help. This is an urgent situation at MUST Campus.',
                  ),
                  tooltip: 'Send SMS',
                ),
              ],
            ),
            isThreeLine: true,
            onTap: () => _showContactOptions(contact),
          );
        },
      ),
    );
  }

  Widget _buildSafetyTips() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mustBlue.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.mustBlue.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, color: AppColors.mustGold),
              const SizedBox(width: 8),
              const Text(
                'Safety Tips',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mustBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildSafetyTip('Save these numbers in your phone for quick access'),
          _buildSafetyTip('Share your location with trusted contacts'),
          _buildSafetyTip('Use the panic button in dangerous situations'),
          _buildSafetyTip('Stay in well-lit, populated areas when possible'),
          _buildSafetyTip('Trust your instincts - if something feels wrong, seek help'),
        ],
      ),
    );
  }

  Widget _buildSafetyTip(String tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 16, color: AppColors.mustGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.mustBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactOptions(EmergencyContact contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: contact.color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(contact.icon, color: contact.color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              contact.name,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              contact.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              contact.number,
              style: TextStyle(
                fontSize: 16,
                color: contact.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _makePhoneCall(contact.number);
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('Call Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                      Navigator.pop(context);
                      _sendSMS(
                        contact.number,
                        'Emergency: I need help. This is an urgent situation at MUST Campus.',
                      );
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Send SMS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.mustBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showEmergencyInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Services Info'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This emergency feature provides:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Quick dial to campus security'),
              Text('• Direct line to police (112)'),
              Text('• Medical emergency services'),
              Text('• Gender desk support officer'),
              Text('• Counseling services'),
              SizedBox(height: 12),
              Text(
                'How to use:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Tap any contact to call or message'),
              Text('• Use PANIC button for immediate alert'),
              Text('• Your location can be shared automatically'),
              SizedBox(height: 12),
              Text(
                'Note: All emergency calls and messages are logged for your safety and security.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it', style: TextStyle(color: AppColors.mustBlue)),
          ),
        ],
      ),
    );
  }
}

class EmergencyContact {
  final String name;
  final String number;
  final String type;
  final IconData icon;
  final Color color;
  final String description;
  final ContactCategory category;

  EmergencyContact({
    required this.name,
    required this.number,
    required this.type,
    required this.icon,
    required this.color,
    required this.description,
    required this.category,
  });
}
