import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/security_service.dart';
import '../services/theme_service.dart';

class PinSetupScreen extends StatefulWidget {
  final bool isChanging;
  
  const PinSetupScreen({super.key, this.isChanging = false});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final _oldPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _oldPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _setupPin() async {
    if (_newPinController.text.length != 4) {
      _showError('PIN must be 4 digits');
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      _showError('PINs do not match');
      return;
    }

    setState(() => _isLoading = true);

    final securityService = context.read<SecurityService>();

    if (widget.isChanging) {
      final isOldPinValid = await securityService.verifyPin(_oldPinController.text);
      if (!isOldPinValid) {
        setState(() => _isLoading = false);
        _showError('Old PIN is incorrect');
        return;
      }
      
      final success = await securityService.changePin(
        _oldPinController.text,
        _newPinController.text,
      );
      
      setState(() => _isLoading = false);
      
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN changed successfully'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      } else {
        _showError('Failed to change PIN');
      }
    } else {
      final success = await securityService.setupPin(_newPinController.text);
      setState(() => _isLoading = false);
      
      if (success && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN setup successfully'),
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      } else {
        _showError('Failed to setup PIN');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 65,
        title: Text(
          widget.isChanging ? 'Change PIN' : 'Setup PIN',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  border: Border.all(color: AppColors.secondaryOrange, width: 3),
                ),
                child: Icon(
                  Icons.security,
                  size: 48,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                widget.isChanging ? 'Change Your Security PIN' : 'Create a Security PIN',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.royalBlue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Use a 4-digit PIN to add an extra layer of security to your account',
                style: TextStyle(
                  fontSize: 14, 
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            
            if (widget.isChanging) ...[
              Text(
                'Old PIN', 
                style: TextStyle(
                  fontWeight: FontWeight.w600, 
                  color: isDark ? Colors.white : AppColors.royalBlue,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _oldPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textDark,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter old PIN',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white54 : AppColors.textSecondary,
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.textSecondary.withOpacity(0.3) : AppColors.borderLight,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppColors.textSecondary.withOpacity(0.3) : AppColors.borderLight,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            Text(
              'New PIN', 
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                color: isDark ? Colors.white : AppColors.royalBlue,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _newPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textDark,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Enter 4-digit PIN',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.textSecondary.withOpacity(0.3) : AppColors.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.textSecondary.withOpacity(0.3) : AppColors.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            
            Text(
              'Confirm PIN', 
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                color: isDark ? Colors.white : AppColors.royalBlue,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textDark,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                hintText: 'Re-enter PIN',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : AppColors.textSecondary,
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.textSecondary.withOpacity(0.3) : AppColors.borderLight,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.textSecondary.withOpacity(0.3) : AppColors.borderLight,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _setupPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondaryOrange,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.isChanging ? 'Change PIN' : 'Setup PIN',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // Explicit white color
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            // Security tips
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark 
                    ? AppColors.primaryGreen.withOpacity(0.1) 
                    : AppColors.primaryGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Security Tips',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.textDark,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• Choose a PIN that\'s easy to remember but hard to guess\n• Don\'t use obvious combinations like 1234 or 0000\n• Keep your PIN private and secure',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}