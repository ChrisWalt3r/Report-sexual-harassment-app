/// Emergency service constants
/// These can be configured based on the user's region
class EmergencyConstants {
  EmergencyConstants._();

  /// Default emergency number (can be changed per region)
  /// Examples: '911' (US/Canada), '999' (UK), '112' (EU), '000' (Australia)
  static const String emergencyNumber = '911';
  
  /// Emergency label for display
  static const String emergencyLabel = 'Call Emergency Services';
  
  /// Immediate danger label
  static const String immediateDangerLabel = 'Call $emergencyNumber - Immediate Danger';
}
