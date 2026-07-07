import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

/// PostHog funnel wrapper (subF-14). No-op unless a key is configured, so local dev never
/// needs a PostHog project; in debug it just prints. Keeps the funnel event names in one place.
class Analytics {
  static const _apiKey = String.fromEnvironment('POSTHOG_KEY');
  static bool get _enabled => _apiKey.isNotEmpty;

  static Future<void> capture(String event, [Map<String, Object>? props]) async {
    if (kDebugMode) debugPrint('analytics: $event ${props ?? ''}');
    if (_enabled) await Posthog().capture(eventName: event, properties: props);
  }

  // funnel steps
  static Future<void> onboardingStep(int step) => capture('onboarding_step', {'step': step});
  static Future<void> connectSuccess() => capture('connect_success');
  static Future<void> connectFail(String reason) => capture('connect_fail', {'reason': reason});
  static Future<void> firstSubscriptions(int count) => capture('first_subscriptions', {'count': count});
}
