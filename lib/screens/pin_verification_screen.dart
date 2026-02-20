import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/security_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class PinVerificationScreen extends StatefulWidget {
  final VoidCallback? onVerified;
  
  const PinVerificationScreen({
    super.key,
    this.onVerified,
  });

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  int _failedAttempts = 0;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _verifyPin() async {
    if (_pinController.text.length != 4) {
      _showError('PIN must be 4 digits');
      return;
    }

    setState(() => _isLoading = true);

    final securityService = context.read<SecurityService>();
    final isValid = await securityService.verifyPin(_pinController.text);

    setState(() => _isLoading = false);

    if (isValid && mounted) {
      // Reset inactivity timer after successful PIN entry
      securityService.resetInactivityTimer();
      
      // Call the callback if provided, otherwise navigate to home
      if (widget.onVerified != null) {
        widget.onVerified!();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      }
    } else {
      _failedAttempts++;
      _pinController.clear();
      
      if (_failedAttempts >= 3) {
        _showError('Too many failed attempts. Logging out for security.');
        // Log out user after too many failed attempts
        await AuthService().signOut();
      } else {
        _showError('Incorrect PIN. ${3 - _failedAttempts} attempts remaining');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.15),
                      border: Border.all(color: AppColors.mustGold, width: 3),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Enter Your PIN',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please enter your 4-digit PIN to continue',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),
                  
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 16,
                        color: AppColors.mustBlue,
                      ),
                      decoration: InputDecoration(
                        hintText: '••••',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        counterText: '',
                      ),
                      onSubmitted: (_) => _verifyPin(),
                    ),
                  ),
                  const SizedBox(height: 28),
                  
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.mustGold, AppColors.mustGoldLight],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.mustGold.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _verifyPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: AppColors.mustBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.mustBlue),
                              ),
                            )
                          : const Text(
                              'Verify',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
