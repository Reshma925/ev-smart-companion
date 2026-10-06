enum MaintenanceDueStatus { notScheduled, upToDate, dueSoon, dueToday, overdue }

class MaintenanceDueAssessment {
  const MaintenanceDueAssessment({
    required this.status,
    required this.daysRemaining,
  });

  final MaintenanceDueStatus status;
  final int daysRemaining;

  String get label => switch (status) {
    MaintenanceDueStatus.notScheduled => 'NOT SCHEDULED',
    MaintenanceDueStatus.upToDate => 'UP TO DATE',
    MaintenanceDueStatus.dueSoon => 'DUE SOON',
    MaintenanceDueStatus.dueToday => 'DUE TODAY',
    MaintenanceDueStatus.overdue => 'OVERDUE',
  };

  String get description => switch (status) {
    MaintenanceDueStatus.notScheduled => 'No due date recorded',
    MaintenanceDueStatus.upToDate => 'Scheduled',
    MaintenanceDueStatus.dueSoon =>
      'Due in $daysRemaining ${daysRemaining == 1 ? 'day' : 'days'}',
    MaintenanceDueStatus.dueToday => 'Due today',
    MaintenanceDueStatus.overdue =>
      'Overdue by ${daysRemaining.abs()} ${daysRemaining.abs() == 1 ? 'day' : 'days'}',
  };
}

class MaintenanceScheduleService {
  const MaintenanceScheduleService._();

  static MaintenanceDueAssessment assessDate(
    DateTime? dueDate, {
    DateTime? now,
    int dueSoonDays = 30,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    if (dueDate == null) {
      return const MaintenanceDueAssessment(
        status: MaintenanceDueStatus.notScheduled,
        daysRemaining: 0,
      );
    }

    final days = _dateOnly(dueDate).difference(today).inDays;
    final status = days < 0
        ? MaintenanceDueStatus.overdue
        : days == 0
        ? MaintenanceDueStatus.dueToday
        : days <= dueSoonDays
        ? MaintenanceDueStatus.dueSoon
        : MaintenanceDueStatus.upToDate;
    return MaintenanceDueAssessment(status: status, daysRemaining: days);
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
