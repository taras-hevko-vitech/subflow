/// Build-time configuration via --dart-define (simpler than full flavors for MVP;
/// dev/prod differ only in these values).
///
///   flutter run --dart-define=API_BASE_URL=http://localhost:3000
///
/// Android emulator reaches the host machine at http://10.0.2.2:3000.
class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');
  static const sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Deep link that magic-link mails point to (https://subflow.app/auth?token=...).
  static const universalLinkHost = 'subflow.app';
}
