import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/bottom_nav_bar.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  int _currentNavIndex = 2;
  bool _isEmergencyMode = false;

  final List<EmergencyContact> _emergencyContacts = [
    EmergencyContact(
      name: 'Campus Security',
      number: '+256740535992',
      type: 'Security',
      icon: Icons.security,
      color: Colors.blue,
      description: '24/7 Campus Security Office',
    ),
    EmergencyContact(
      name: 'Police Emergency',
      number: '112',
      type: 'Police',
      icon: Icons.local_police,
      color: Colors.red,
      description: 'National Emergency Police Line',
    ),
    EmergencyContact(
      name: 'Campus Medical Center',
      number: '+256740470116',
      type: 'Medical',
      icon: Icons.local_hospital,
      color: Colors.green,
      description: 'MUST Medical Emergency',
    ),
    EmergencyContact(
      name: 'Gender Desk Officer',
      number: '+256740535992',
      type: 'Support',
      icon: Icons.support_agent,
      color: Colors.purple,
      description: 'Sexual Harassment Support',
    ),
    EmergencyContact(
      name: 'Counseling Services',
      number: '+255123456792',
      type: 'Counseling',
      icon: Icons.psychology,
      color: Colors.orange,
      description: 'Mental Health Support',
    ),
  ];

  Future<void> _makePhoneCall(String phoneNumber) async {
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
    }
  }

  Future<void> _sendSMS(String phoneNumber, String message) async {
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
    setState(() {
      _isEmergencyMode = true;
    });

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
              _makePhoneCall(_emergencyContacts[0].number);
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
              setState(() {
                _isEmergencyMode = false;
              });
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
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.red.shade700,
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showEmergencyInfo,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emergency Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red.shade700, Colors.red.shade900],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.emergency,
                    size: 60,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Need Help?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap any button below for immediate assistance',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  _buildPanicButton(),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Quick Dial Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'QUICK DIAL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            _buildQuickDialGrid(),
            
            const SizedBox(height: 24),
            
            // Emergency Contacts List
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'ALL EMERGENCY CONTACTS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            _buildEmergencyContactsList(),
            
            const SizedBox(height: 24),
            
            // Safety Tips
            _buildSafetyTips(),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          setState(() {
            _currentNavIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildPanicButton() {
    return GestureDetector(
      onTap: _activatePanicMode,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.crisis_alert,
              size: 50,
              color: Colors.red.shade700,
            ),
            const SizedBox(height: 8),
            Text(
              'PANIC',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDialGrid() {
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
                  icon: const Icon(Icons.message, color: Colors.blue, size: 22),
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
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue.shade700),
              const SizedBox(width: 8),
              Text(
                'Safety Tips',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
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
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue.shade700,
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
                      backgroundColor: Colors.blue,
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
            child: const Text('Got it'),
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

  EmergencyContact({
    required this.name,
    required this.number,
    required this.type,
    required this.icon,
    required this.color,
    required this.description,
  });
}
