// config.dart — Central configuration for FaceAttend app.
//
// IMPORTANT: Change BASE_URL to your laptop's LAN IP address
// before running on a physical Android device.
//
// How to find your IP:
//   Windows: run `ipconfig` in Command Prompt → look for "IPv4 Address"
//   Example: 192.168.1.42
//
// Then set:  const String baseUrl = 'http://192.168.1.42:8000';

class AppConfig {
  // ─── API ──────────────────────────────────────────────────────────
  static const String baseUrl = 'https://sunrise-enterprices.onrender.com';

  // ─── Face Recognition ─────────────────────────────────────────────
  /// Minimum confidence to display (informational only — threshold enforced server-side)
  static const double displayThreshold = 0.35;
  static String get recognizeUrl => '$baseUrl/recognize';

  static String get authLoginUrl => '$baseUrl/auth/login';
  static String get authSignupUrl => '$baseUrl/auth/signup';

  // ─── App ──────────────────────────────────────────────────────────
  static const String appName = 'FaceAttend';
  static const int apiTimeoutSeconds = 60;

  // ─── API Endpoints ────────────────────────────────────────────────
  static String get healthUrl        => '$baseUrl/health';
  static String get peopleUrl        => '$baseUrl/people';
  static String get registerUrl      => '$baseUrl/register';
  static String get checkInUrl       => '$baseUrl/attendance/check-in';
  static String get checkOutUrl      => '$baseUrl/attendance/check-out';
  static String get todayUrl         => '$baseUrl/attendance/today';
  static String historyUrl(String employeeId) =>
      '$baseUrl/attendance/history/$employeeId';
}
