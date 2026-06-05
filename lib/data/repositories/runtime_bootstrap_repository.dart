import '../../core/constants/app_enums.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../database/sync_metadata.dart';
import '../datasources/runtime_bootstrap_remote_data_source.dart';
import 'customer_sync_repository.dart';
import 'installment_plan_sync_repository.dart';
import 'product_sync_repository.dart';
import '../../services/sync_change_notifier.dart';

class RuntimeBootstrapRepository {
  RuntimeBootstrapRepository({
    required DbHelper dbHelper,
    required RuntimeBootstrapRemoteDataSource remoteDataSource,
    required CustomerSyncRepository customerSyncRepository,
    required ProductSyncRepository productSyncRepository,
    required InstallmentPlanSyncRepository installmentPlanSyncRepository,
    SyncChangeNotifier? changeNotifier,
  }) : _dbHelper = dbHelper,
       _remoteDataSource = remoteDataSource,
       _customerSyncRepository = customerSyncRepository,
       _productSyncRepository = productSyncRepository,
       _installmentPlanSyncRepository = installmentPlanSyncRepository,
       _changeNotifier = changeNotifier;

  final DbHelper _dbHelper;
  final RuntimeBootstrapRemoteDataSource _remoteDataSource;
  final CustomerSyncRepository _customerSyncRepository;
  final ProductSyncRepository _productSyncRepository;
  final InstallmentPlanSyncRepository _installmentPlanSyncRepository;
  final SyncChangeNotifier? _changeNotifier;

  Future<void> bootstrap() async {
    final response = await _remoteDataSource.fetch();
    final data = _map(response['data']).isEmpty
        ? response
        : _map(response['data']);

    await _applyUsers(_records(data['users']));
    await _customerSyncRepository.applyDownloadedRecords(
      _records(data['customers']),
    );
    await _productSyncRepository.applyDownloadedRecords(
      _records(data['products']),
    );
    await _installmentPlanSyncRepository.applyDownloadedRecords(
      _records(data['installmentPlans']),
    );
    await _applyCustomerAccess(_records(data['customerAccess']));
    await _applyPlanAccess(_records(data['planAccess']));
    _changeNotifier?.notify(SyncResource.customers);
    _changeNotifier?.notify(SyncResource.products);
    _changeNotifier?.notify(SyncResource.installmentPlans);
  }

  Future<void> _applyUsers(List<Map<String, dynamic>> records) async {
    if (records.isEmpty) {
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final record in records) {
        final serverId = _string(record['serverId']) ?? _string(record['uuid']);
        if (serverId == null) {
          continue;
        }
        final existing = await _findUser(txn, serverId, record);
        final updatedAt =
            _string(record['updatedAt']) ??
            DateTime.now().toUtc().toIso8601String();
        final values = SyncMetadata.withServerChange(DbConstants.users, {
          SyncMetadata.serverId: serverId,
          SyncMetadata.dateUpdated: updatedAt,
          SyncMetadata.isDeleted: _bool(record['isDeleted']) ? 1 : 0,
          'uuid': serverId,
          'phone':
              _string(record['phoneNumber']) ?? _string(record['phone']) ?? '',
          'email': _string(record['email']) ?? '',
          'password': _string(existing?['password']) ?? 'remote-login-only',
          'first_name':
              _string(record['firstName']) ??
              _string(record['first_name']) ??
              '',
          'last_name':
              _string(record['lastName']) ?? _string(record['last_name']) ?? '',
          'role': _localRole(_string(record['role'])),
          'is_active': _bool(record['isActive'] ?? true) ? 1 : 0,
          'created_at': _string(record['createdAt']) ?? updatedAt,
          'updated_at': updatedAt,
        })..remove('id');

        if (existing == null) {
          await txn.insert(DbConstants.users, values);
        } else {
          await txn.update(
            DbConstants.users,
            values,
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
        }
      }
    });
  }

  Future<void> _applyCustomerAccess(List<Map<String, dynamic>> records) async {
    await _applyAccess(
      tableName: DbConstants.customerUserAccess,
      records: records,
      targetKey: 'customerId',
      targetTable: DbConstants.customers,
      targetColumn: 'customer_uuid',
    );
  }

  Future<void> _applyPlanAccess(List<Map<String, dynamic>> records) async {
    await _applyAccess(
      tableName: DbConstants.planUserAccess,
      records: records,
      targetKey: 'planId',
      targetTable: DbConstants.plans,
      targetColumn: 'plan_uuid',
    );
  }

  Future<void> _applyAccess({
    required String tableName,
    required List<Map<String, dynamic>> records,
    required String targetKey,
    required String targetTable,
    required String targetColumn,
  }) async {
    if (records.isEmpty) {
      return;
    }
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final record in records) {
        final serverId = _string(record['serverId']) ?? _string(record['uuid']);
        final userServerId = _string(record['userId']);
        final targetServerId = _string(record[targetKey]);
        if (serverId == null ||
            userServerId == null ||
            targetServerId == null) {
          continue;
        }

        final localUserUuid = await _localUserUuid(txn, userServerId);
        final localTargetId = await _localIdForServerId(
          txn,
          targetTable,
          targetServerId,
        );
        if (localUserUuid == null || localTargetId == null) {
          continue;
        }

        final existing = await _findAccess(
          txn,
          tableName,
          serverId,
          localUserUuid: localUserUuid,
          targetColumn: targetColumn,
          localTargetId: localTargetId,
        );
        final updatedAt =
            _string(record['updatedAt']) ??
            DateTime.now().toUtc().toIso8601String();
        final values = SyncMetadata.withServerChange(tableName, {
          SyncMetadata.serverId: serverId,
          SyncMetadata.dateUpdated: updatedAt,
          SyncMetadata.isDeleted: _bool(record['isDeleted']) ? 1 : 0,
          'uuid': serverId,
          'user_uuid': localUserUuid,
          targetColumn: '$localTargetId',
          'created_at': _string(record['createdAt']) ?? updatedAt,
          'updated_at': updatedAt,
        })..remove('id');

        if (existing == null) {
          await txn.insert(tableName, values);
        } else {
          await txn.update(
            tableName,
            values,
            where: 'id = ?',
            whereArgs: [existing['id']],
          );
        }
      }
    });
  }

  Future<Map<String, Object?>?> _findUser(
    dynamic executor,
    String serverId,
    Map<String, dynamic> record,
  ) async {
    final rows = await executor.query(
      DbConstants.users,
      where: 'uuid = ? OR ${SyncMetadata.serverId} = ?',
      whereArgs: [serverId, serverId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first;
    }
    final phone = _string(record['phoneNumber']) ?? _string(record['phone']);
    if (phone == null) {
      return null;
    }
    final phoneRows = await executor.query(
      DbConstants.users,
      where: 'phone = ?',
      whereArgs: [phone],
      limit: 1,
    );
    return phoneRows.isEmpty ? null : phoneRows.first;
  }

  Future<Map<String, Object?>?> _findAccess(
    dynamic executor,
    String tableName,
    String serverId, {
    required String localUserUuid,
    required String targetColumn,
    required int localTargetId,
  }) async {
    final rows = await executor.query(
      tableName,
      where: 'uuid = ? OR ${SyncMetadata.serverId} = ?',
      whereArgs: [serverId, serverId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first;
    }
    final pairRows = await executor.query(
      tableName,
      where: 'user_uuid = ? AND $targetColumn = ?',
      whereArgs: [localUserUuid, '$localTargetId'],
      limit: 1,
    );
    return pairRows.isEmpty ? null : pairRows.first;
  }

  Future<String?> _localUserUuid(dynamic executor, String serverId) async {
    final rows = await executor.query(
      DbConstants.users,
      columns: ['uuid'],
      where: 'uuid = ? OR ${SyncMetadata.serverId} = ?',
      whereArgs: [serverId, serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : _string(rows.first['uuid']);
  }

  Future<int?> _localIdForServerId(
    dynamic executor,
    String tableName,
    String serverId,
  ) async {
    final rows = await executor.query(
      tableName,
      columns: ['id'],
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : _int(rows.first['id']);
  }

  List<Map<String, dynamic>> _records(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value.whereType<Map>().map(_map).toList();
  }

  Map<String, dynamic> _map(Object? value) {
    if (value is! Map) {
      return const {};
    }
    return value.map((key, value) => MapEntry('$key', value));
  }

  String _localRole(String? value) {
    return switch ((value ?? '').toLowerCase()) {
      'owner' => UserRole.owner.name,
      'admin' => UserRole.admin.name,
      'salesman' || 'sales_man' => UserRole.salesMan.name,
      _ => UserRole.salesMan.name,
    };
  }

  String? _string(Object? value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  int? _int(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  bool _bool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
}
