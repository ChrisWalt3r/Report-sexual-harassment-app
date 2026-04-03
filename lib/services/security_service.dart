import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_service.dart';

class SecurityService extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();
  
  Timer? _inactivityTimer;
  bool _isPinEnabled = false;
  bool _isAutoLogoutEnabled = false;
  int _autoLogoutMinutes = 15; // Default 15 minutes
  
  static const String _pinKey = 'user_pin';
  static const String _pinEnabledKey = 'pin_enabled';
  static const String _autoLogoutEnabledKey = 'auto_logout_enabled';
  static const String _autoLogoutMinutesKey = 'auto_logout_minutes';
  
  bool get isPinEnabled => _isPinEnabled;
  bool get isAutoLogoutEnabled => _isAutoLogoutEnabled;
  int get autoLogoutMinutes => _autoLogoutMinutes;
  
  SecurityService() {
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    try {
      final pinEnabled = await _secureStorage.read(key: _pinEnabledKey);
      final autoLogoutEnabled = await _secureStorage.read(key: _autoLogoutEnabledKey);
      final logoutMinutes = await _secureStorage.read(key: _autoLogoutMinutesKey);
      
      _isPinEnabled = pinEnabled == 'true';
      _isAutoLogoutEnabled = autoLogoutEnabled == 'true';
      _autoLogoutMinutes = int.tryParse(logoutMinutes ?? '15') ?? 15;
      
      if (_isAutoLogoutEnabled) {
        startInactivityTimer();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading security settings: $e');
    }
  }
  
  // PIN Management
  Future<bool> setupPin(String pin) async {
    try {
      await _secureStorage.write(key: _pinKey, value: pin);
      await _secureStorage.write(key: _pinEnabledKey, value: 'true');
      _isPinEnabled = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting up PIN: $e');
      return false;
    }
  }
  
  Future<bool> verifyPin(String pin) async {
    try {
      final storedPin = await _secureStorage.read(key: _pinKey);
      return storedPin == pin;
    } catch (e) {
      debugPrint('Error verifying PIN: $e');
      return false;
    }
  }
  
  Future<bool> changePin(String oldPin, String newPin) async {
    try {
      final isValid = await verifyPin(oldPin);
      if (!isValid) return false;
      
      await _secureStorage.write(key: _pinKey, value: newPin);
      return true;
    } catch (e) {
      debugPrint('Error changing PIN: $e');
      return false;
    }
  }
  
  Future<void> disablePin() async {
    try {
      await _secureStorage.delete(key: _pinKey);
      await _secureStorage.write(key: _pinEnabledKey, value: 'false');
      _isPinEnabled = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error disabling PIN: $e');
    }
  }
  
  // Auto Logout Management
  Future<void> setAutoLogout(bool enabled, {int? minutes}) async {
    try {
      _isAutoLogoutEnabled = enabled;
      if (minutes != null) {
        _autoLogoutMinutes = minutes;
      }
      
      await _secureStorage.write(key: _autoLogoutEnabledKey, value: enabled.toString());
      await _secureStorage.write(key: _autoLogoutMinutesKey, value: _autoLogoutMinutes.toString());
      
      if (enabled) {
        startInactivityTimer();
      } else {
        stopInactivityTimer();
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error setting auto logout: $e');
    }
  }
  
  void startInactivityTimer() {
    stopInactivityTimer();
    
    if (_isAutoLogoutEnabled) {
      _inactivityTimer = Timer(
        Duration(minutes: _autoLogoutMinutes),
        () async {
          await _authService.signOut();
          // Trigger logout event - will be handled by app navigation
        },
      );
    }
  }
  
  void resetInactivityTimer() {
    if (_isAutoLogoutEnabled) {
      startInactivityTimer();
    }
  }
  
  void stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }
  
  @override
  void dispose() {
    stopInactivityTimer();
    super.dispose();
  }
}
