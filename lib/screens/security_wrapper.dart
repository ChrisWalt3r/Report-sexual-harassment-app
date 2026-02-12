import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/security_service.dart';
import '../services/auth_service.dart';
import 'pin_verification_screen.dart';
import 'home_screen.dart';
import 'welcome_screen.dart';

/// Wrapper that checks authentication and PIN protection
class SecurityWrapper extends StatefulWidget {
  const SecurityWrapper({super.key});

  @override
  State<SecurityWrapper> createState() => _SecurityWrapperState();
}

class _SecurityWrapperState extends State<SecurityWrapper> with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isPinVerified = false;
  bool _isCheckingPin = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPinStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // When app comes back to foreground, re-verify PIN if enabled
    if (state == AppLifecycleState.resumed) {
      final securityService = Provider.of<SecurityService>(context, listen: false);
      if (securityService.isPinEnabled && _isPinVerified) {
        setState(() {
          _isPinVerified = false;
        });
      }
    }
    
    // Handle inactivity timer based on app lifecycle
    final securityService = Provider.of<SecurityService>(context, listen: false);
    if (state == AppLifecycleState.paused) {
      securityService.stopInactivityTimer();
    } else if (state == AppLifecycleState.resumed) {
      securityService.startInactivityTimer();
    }
  }

  Future<void> _checkPinStatus() async {
    final securityService = Provider.of<SecurityService>(context, listen: false);
    await Future.delayed(const Duration(milliseconds: 100)); // Give time for provider to initialize
    
    if (!mounted) return;
    
    setState(() {
      _isInitialized = true;
      // If PIN is not enabled, mark as verified
      _isPinVerified = !securityService.isPinEnabled;
      _isCheckingPin = false;
    });

    // Start inactivity timer if auto-logout is enabled
    if (securityService.isAutoLogoutEnabled) {
      securityService.startInactivityTimer();
    }
  }

  void _onPinVerified() {
    setState(() {
      _isPinVerified = true;
    });

    // Start inactivity timer after successful PIN verification
    final securityService = Provider.of<SecurityService>(context, listen: false);
    if (securityService.isAutoLogoutEnabled) {
      securityService.startInactivityTimer();
    }
  }

  Future<bool> _showExitConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final securityService = Provider.of<SecurityService>(context);

    // Show loading while checking PIN status
    if (_isCheckingPin || !_isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        // Check if there are routes to pop back to
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return;
        }
        
        // At root screen - show exit confirmation
        final shouldExit = await _showExitConfirmation();
        if (shouldExit && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          // User is not logged in - show welcome screen
          if (!snapshot.hasData) {
            return const WelcomeScreen();
          }

          // User is logged in - check PIN protection
          if (securityService.isPinEnabled && !_isPinVerified) {
            return PinVerificationScreen(
              onVerified: _onPinVerified,
            );
          }

          // User is logged in and PIN is verified (or not required)
          return const HomeScreen();
        },
      ),
    );
  }
}
