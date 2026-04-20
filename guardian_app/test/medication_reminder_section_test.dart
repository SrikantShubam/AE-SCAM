import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:guardian/features/medication/models/medication_reminder_summary.dart';
import 'package:guardian/features/medication/providers/medication_reminder_provider.dart';
import 'package:guardian/features/medication/widgets/medication_reminder_section.dart';

Widget _wrap(Widget child, MedicationReminderSummary summary) {
  return ProviderScope(
    overrides: [
      medicationReminderSummaryProvider.overrideWithValue(summary),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('shows a due-now reminder with action buttons', (tester) async {
    const summary = MedicationReminderSummary(
      title: 'Morning blood pressure tablet',
      dosage: '1 tablet',
      nextDoseLabel: 'Due now',
      statusLabel: 'Level 1 reminder',
      statusTone: MedicationReminderTone.dueNow,
      reminderBody: 'It is time for your morning medicine.',
      scheduleId: 'schedule-1',
      scheduledAt: DateTime(2026, 4, 10, 8, 0),
    );

    await tester.pumpWidget(
      _wrap(const MedicationReminderSection(), summary),
    );

    expect(find.text('Medicine reminders'), findsOneWidget);
    expect(find.text('Morning blood pressure tablet'), findsOneWidget);
    expect(find.text('Due now'), findsOneWidget);
    expect(find.text('Level 1 reminder'), findsOneWidget);
    expect(find.text('Taken'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Remind me later'), findsOneWidget);
  });

  testWidgets('shows overdue alarm urgency state', (tester) async {
    const summary = MedicationReminderSummary(
      title: 'Evening diabetes medicine',
      dosage: '2 tablets',
      nextDoseLabel: 'Overdue by 20 min',
      statusLabel: 'Level 3 alarm',
      statusTone: MedicationReminderTone.overdueAlarm,
      reminderBody: 'This dose is overdue. Please take it now.',
      scheduleId: 'schedule-2',
      scheduledAt: DateTime(2026, 4, 10, 20, 0),
      eventId: 'dose-2',
    );

    await tester.pumpWidget(
      _wrap(const MedicationReminderSection(), summary),
    );

    expect(find.text('Level 3 alarm'), findsOneWidget);
    expect(find.text('Overdue by 20 min'), findsOneWidget);
    expect(find.text('Alarm on this phone'), findsOneWidget);
  });

  testWidgets('remind me later stays enabled for actionable reminders', (
    tester,
  ) async {
    const summary = MedicationReminderSummary(
      title: 'Morning blood pressure tablet',
      dosage: '1 tablet',
      nextDoseLabel: 'Due now',
      statusLabel: 'Level 1 reminder',
      statusTone: MedicationReminderTone.dueNow,
      reminderBody: 'It is time for your morning medicine.',
      scheduleId: 'schedule-1',
      scheduledAt: DateTime(2026, 4, 10, 8, 0),
    );

    await tester.pumpWidget(_wrap(const MedicationReminderSection(), summary));

    final remindLaterButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Remind me later'),
    );
    expect(remindLaterButton.onPressed, isNotNull);
  });
}
