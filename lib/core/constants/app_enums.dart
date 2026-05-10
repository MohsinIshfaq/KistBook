enum InstallmentRecordStatus { pending, missed, paid }

enum InstallmentVisualStatus { paid, overdue, pending }

enum UserRole { owner, admin, salesMan }

extension UserRoleLabelExtension on UserRole {
  String get label => switch (this) {
        UserRole.owner => 'Owner',
        UserRole.admin => 'Admin',
        UserRole.salesMan => 'SalesMan',
      };
}
