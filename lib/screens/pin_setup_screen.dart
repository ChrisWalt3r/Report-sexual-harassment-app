import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../services/security_service.dart';

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
          const SnackBar(
            content: Text('PIN changed successfully'),
            backgroundColor: Colors.green,
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
          const SnackBar(
            content: Text('PIN setup successfully'),
            backgroundColor: Colors.green,
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
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        elevation: 0,
        foregroundColor: Colors.white,
        title: Text(
          widget.isChanging ? 'Change PIN' : 'Setup PIN',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.mustBlue, AppColors.mustBlueMedium],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.mustBlue.withOpacity(0.08),
                  border: Border.all(color: AppColors.mustGold, width: 2.5),
                ),
                child: const Icon(
                  Icons.pin_rounded,
                  size: 40,
                  color: AppColors.mustBlue,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                widget.isChanging ? 'Change Your Security PIN' : 'Create a Security PIN',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mustBlue,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Use a 4-digit PIN to add an extra layer of security',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            
            if (widget.isChanging) ...[
              const Text('Old PIN', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.mustBlue)),
              const SizedBox(height: 8),
              TextField(
                controller: _oldPinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                decoration: InputDecoration(
                  hintText: 'Enter old PIN',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.mustGold, width: 2),
                  ),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            const Text('New PIN', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.mustBlue)),
            const SizedBox(height: 8),
            TextField(
              controller: _newPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                hintText: 'Enter 4-digit PIN',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.mustGold, width: 2),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 24),
            
            const Text('Confirm PIN', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.mustBlue)),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmPinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              decoration: InputDecoration(
                hintText: 'Re-enter PIN',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.mustGold, width: 2),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 36),
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
                onPressed: _isLoading ? null : _setupPin,
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
                    : Text(
                        widget.isChanging ? 'Change PIN' : 'Setup PIN',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
