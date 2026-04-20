class AppConstants {
  const AppConstants._();

  static const String appName = 'Guardian';
  static const String databaseName = 'guardian_local.db';
  static const int databaseVersion = 5;

  static const double minimumButtonHeight = 56;
  static const double screenPadding = 24;

  static const Duration syncRetryInterval = Duration(minutes: 15);
  static const Duration guardianEscalationInterval = Duration(minutes: 10);
  static const Duration riskBannerTimeout = Duration(seconds: 30);
}
