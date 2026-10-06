import 'package:flutter_application_2/services/maintenance_schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 6, 16);

  test('marks a past maintenance due date overdue', () {
    final result = MaintenanceScheduleService.assessDate(
      DateTime(2026, 10, 5),
      now: now,
    );

    expect(result.status, MaintenanceDueStatus.overdue);
    expect(result.daysRemaining, -1);
    expect(result.description, 'Overdue by 1 day');
  });

  test('marks due today and due soon from calendar days', () {
    final today = MaintenanceScheduleService.assessDate(
      DateTime(2026, 10, 6, 23),
      now: now,
    );
    final soon = MaintenanceScheduleService.assessDate(
      DateTime(2026, 10, 13),
      now: now,
    );

    expect(today.status, MaintenanceDueStatus.dueToday);
    expect(soon.status, MaintenanceDueStatus.dueSoon);
    expect(soon.daysRemaining, 7);
  });

  test('does not invent or imply a schedule when no date was recorded', () {
    final result = MaintenanceScheduleService.assessDate(null, now: now);

    expect(result.status, MaintenanceDueStatus.notScheduled);
    expect(result.daysRemaining, 0);
  });
}
