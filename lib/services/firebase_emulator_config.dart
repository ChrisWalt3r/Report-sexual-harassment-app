class FirebaseEmulatorConfig {
  static bool _configured = false;

  static void configure() {
    if (_configured) return;
    _configured = true;
  }
}
