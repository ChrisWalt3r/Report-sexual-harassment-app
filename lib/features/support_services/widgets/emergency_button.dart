import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A prominent emergency call button widget
/// Designed for quick access in crisis situations
class EmergencyButton extends StatelessWidget {
  final String label;
  final String phoneNumber;
  final IconData icon;
  final Color? backgroundColor;
  final bool isCompact;

  const EmergencyButton({
    super.key,
    required this.label,
    required this.phoneNumber,
    this.icon = Icons.phone,
    this.backgroundColor,
    this.isCompact = false,
  });

  Future<void> _makePhoneCall(BuildContext context) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    try {
      if (await canLaunchUrl(phoneUri)) {
        final bool launched = await launchUrl(phoneUri);
        if (!launched && context.mounted) {
          _showError(context, 'Unable to place call. Please try again later.');
        }
      } else {
        if (context.mounted) {
          _showError(context, 'Phone calls are not supported on this device.');
        }
      }
    } catch (_) {
      if (context.mounted) {
        _showError(
          context,
          'An error occurred while trying to place the call.',
        );
      }
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Colors.red[700]!;

    if (isCompact) {
      return _buildCompactButton(context, bgColor);
    }

    return _buildFullButton(context, bgColor);
  }

  Widget _buildCompactButton(BuildContext context, Color bgColor) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _makePhoneCall(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullButton(BuildContext context, Color bgColor) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 4,
        shadowColor: bgColor.withOpacity(0.4),
        child: InkWell(
          onTap: () => _makePhoneCall(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      phoneNumber,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white.withOpacity(0.7),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A floating emergency action button for persistent access
class FloatingEmergencyButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FloatingEmergencyButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: onPressed,
      backgroundColor: Colors.red[700],
      icon: const Icon(Icons.emergency, color: Colors.white),
      label: const Text(
        'Emergency',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
