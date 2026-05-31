import 'db_constants.dart';

class SyncMetadata {
  static const serverId = 'server_id';
  static const dateUpdated = 'date_updated';
  static const isSync = 'is_sync';
  static const isDeleted = 'is_deleted';

  static const syncableTables = <String>[
    DbConstants.customers,
    DbConstants.products,
    DbConstants.productImages,
    DbConstants.users,
    DbConstants.customerUserAccess,
    DbConstants.planUserAccess,
    DbConstants.plans,
    DbConstants.installments,
    DbConstants.payments,
  ];

  static bool isSyncableTable(String tableName) =>
      syncableTables.contains(tableName);

  static Map<String, Object?> withLocalChange(
    String tableName,
    Map<String, Object?> values, {
    DateTime? now,
  }) {
    if (!isSyncableTable(tableName)) {
      return values;
    }

    final timestamp = (now ?? DateTime.now().toUtc()).toIso8601String();
    final next = Map<String, Object?>.from(values);
    next.putIfAbsent(dateUpdated, () => timestamp);
    next[isSync] = 0;
    next.putIfAbsent(isDeleted, () => 0);

    if (!next.containsKey('updated_at')) {
      next['updated_at'] = timestamp;
    }
    if (!next.containsKey('created_at')) {
      next['created_at'] = timestamp;
    }

    return next;
  }

  static Map<String, Object?> withServerChange(
    String tableName,
    Map<String, Object?> values, {
    DateTime? now,
  }) {
    if (!isSyncableTable(tableName)) {
      return values;
    }

    final timestamp = (now ?? DateTime.now().toUtc()).toIso8601String();
    final next = Map<String, Object?>.from(values);
    next.putIfAbsent(dateUpdated, () => timestamp);
    next[isSync] = 1;
    next.putIfAbsent(isDeleted, () => 0);
    next.putIfAbsent('updated_at', () => next[dateUpdated] ?? timestamp);
    next.putIfAbsent('created_at', () => next[dateUpdated] ?? timestamp);
    return next;
  }
}
