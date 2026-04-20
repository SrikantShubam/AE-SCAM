class ScamNotificationInput {
  const ScamNotificationInput({
    required this.sourcePackage,
    required this.sender,
    required this.messageBody,
    required this.receivedAtMs,
  });

  final String sourcePackage;
  final String? sender;
  final String messageBody;
  final int receivedAtMs;
}
