enum InstallmentRecordStatus {
  pending,
  partial,
  missed,
  overdue,
  paid,
  rescheduled,
}

enum InstallmentVisualStatus { paid, partial, overdue, pending, rescheduled }

enum UserRole { owner, admin, salesMan }

extension UserRoleLabelExtension on UserRole {
  String get label => switch (this) {
    UserRole.owner => 'Owner',
    UserRole.admin => 'Admin',
    UserRole.salesMan => 'SalesMan',
  };
}
