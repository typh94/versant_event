// Simple build info helpers for debugging deployments.
// Update BUILD_TIMESTAMP manually when making a web release if needed.

class BuildInfo {
  static const String version = '1.0.2+26';
  static const String buildTimestamp = String.fromEnvironment(
    'BUILD_TIMESTAMP',
    defaultValue: 'unknown',
  );
}
