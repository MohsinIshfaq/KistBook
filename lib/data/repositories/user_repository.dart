import '../../core/constants/app_enums.dart';
import '../../core/utils/id_generator.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../database/sync_metadata.dart';
import '../datasources/access_assignment_remote_data_source.dart';
import '../models/customer_user_access_model.dart';
import '../models/local_user_model.dart';
import '../models/plan_user_access_model.dart';
import 'generic_repository.dart';

class UserRepository extends GenericRepository<LocalUserModel> {
  UserRepository(DbHelper dbHelper)
    : super(
        dbHelper: dbHelper,
        tableName: DbConstants.users,
        fromMap: LocalUserModel.fromMap,
      );

  Future<List<LocalUserModel>> fetchUsers() async {
    return getAll(orderBy: 'updated_at DESC');
  }

  Future<LocalUserModel?> findByPhone(String phone) async {
    return findOneBy('phone', phone);
  }

  Future<LocalUserModel?> findByEmail(String email) async {
    final database = await db;
    final rows = await database.query(
      DbConstants.users,
      where: 'LOWER(email) = ? AND is_deleted = 0',
      whereArgs: [email.toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalUserModel.fromMap(rows.first);
  }

  Future<LocalUserModel?> findByServerIdentity(String serverId) async {
    final normalized = serverId.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final database = await db;
    final rows = await database.query(
      DbConstants.users,
      where: '(uuid = ? OR ${SyncMetadata.serverId} = ?) AND is_deleted = 0',
      whereArgs: [normalized, normalized],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalUserModel.fromMap(rows.first);
  }

  Future<LocalUserModel?> findByLogin(String login) async {
    final database = await db;
    final rows = await database.query(
      DbConstants.users,
      where: '(phone = ? OR LOWER(email) = ?) AND is_deleted = 0',
      whereArgs: [login, login.toLowerCase()],
      limit: 1,
    );
    return rows.isEmpty ? null : LocalUserModel.fromMap(rows.first);
  }

  Future<bool> hasUsers() async => (await fetchUsers()).isNotEmpty;

  Future<bool> hasOwner() async {
    final database = await db;
    final rows = await database.query(
      DbConstants.users,
      where: 'role = ? AND is_active = ? AND is_deleted = 0',
      whereArgs: [UserRole.owner.name, 1],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<LocalUserModel> createOwner({
    required String phone,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final now = DateTime.now();
    final user = LocalUserModel(
      uuid: IdGenerator.localUuid(),
      phone: phone,
      email: email,
      password: password,
      firstName: firstName,
      lastName: lastName,
      role: UserRole.owner,
      isActive: true,
      isSync: false,
      createdAt: now,
      updatedAt: now,
    );
    final id = await insert(user);
    return LocalUserModel(
      id: id,
      uuid: user.uuid,
      phone: user.phone,
      email: user.email,
      password: user.password,
      firstName: user.firstName,
      lastName: user.lastName,
      role: user.role,
      isActive: user.isActive,
      isSync: user.isSync,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }

  Future<LocalUserModel> saveUser(LocalUserModel user) async {
    final saved = await save(user);
    return saved.id == user.id ? saved : user.copyWith(id: saved.id);
  }

  Future<void> markServerIdentity({
    required int userId,
    required String serverId,
  }) async {
    if (serverId.trim().isEmpty) {
      return;
    }
    final database = await db;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.update(
      DbConstants.users,
      SyncMetadata.withServerChange(DbConstants.users, {
        SyncMetadata.serverId: serverId,
        SyncMetadata.dateUpdated: now,
        'updated_at': now,
      }),
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> deleteUser(int userId) async {
    final user = await findOne(userId);
    if (user == null) {
      return;
    }
    final database = await db;
    await database.transaction((txn) async {
      await txn.update(
        DbConstants.customerUserAccess,
        SyncMetadata.withLocalChange(DbConstants.customerUserAccess, {
          'is_deleted': 1,
        }),
        where: 'user_uuid = ?',
        whereArgs: [user.uuid],
      );
      await txn.update(
        DbConstants.planUserAccess,
        SyncMetadata.withLocalChange(DbConstants.planUserAccess, {
          'is_deleted': 1,
        }),
        where: 'user_uuid = ?',
        whereArgs: [user.uuid],
      );
      await txn.update(
        DbConstants.users,
        SyncMetadata.withLocalChange(DbConstants.users, {'is_deleted': 1}),
        where: 'id = ?',
        whereArgs: [userId],
      );
    });
  }

  Future<List<CustomerUserAccessModel>> fetchCustomerAccess(
    String userUuid,
  ) async {
    final database = await db;
    final rows = await database.query(
      DbConstants.customerUserAccess,
      where: 'user_uuid = ? AND is_deleted = 0',
      whereArgs: [userUuid],
      orderBy: 'created_at DESC',
    );
    return rows.map(CustomerUserAccessModel.fromMap).toList();
  }

  Future<List<PlanUserAccessModel>> fetchPlanAccess(String userUuid) async {
    final database = await db;
    final rows = await database.query(
      DbConstants.planUserAccess,
      where: 'user_uuid = ? AND is_deleted = 0',
      whereArgs: [userUuid],
      orderBy: 'created_at DESC',
    );
    return rows.map(PlanUserAccessModel.fromMap).toList();
  }

  Future<List<PlanUserAccessModel>> fetchActivePlanAccess() async {
    final database = await db;
    final rows = await database.query(
      DbConstants.planUserAccess,
      where: 'is_deleted = 0',
      orderBy: 'created_at DESC',
    );
    return rows.map(PlanUserAccessModel.fromMap).toList();
  }

  Future<Map<int, String>> fetchActivePlanAssignees({
    String? exceptUserUuid,
  }) async {
    final assignments = await fetchActivePlanAccess();
    final result = <int, String>{};
    for (final assignment in assignments) {
      if (exceptUserUuid != null && assignment.userUuid == exceptUserUuid) {
        continue;
      }
      final planId = int.tryParse(assignment.planUuid);
      if (planId == null) {
        continue;
      }
      result.putIfAbsent(planId, () => assignment.userUuid);
    }
    return result;
  }

  Future<String> serverIdForUserUuid(String userUuid) async {
    final database = await db;
    final rows = await database.query(
      DbConstants.users,
      columns: ['uuid', SyncMetadata.serverId],
      where: 'uuid = ? AND is_deleted = 0',
      whereArgs: [userUuid],
      limit: 1,
    );
    if (rows.isEmpty) {
      throw StateError('Selected salesman is unavailable locally.');
    }

    return _requiredServerId(rows.first, 'Selected salesman');
  }

  Future<List<String>> customerServerIdsForLocalIds(List<int> customerIds) {
    return _serverIdsForLocalIds(
      tableName: DbConstants.customers,
      localIds: customerIds,
      label: 'customer',
    );
  }

  Future<List<String>> planServerIdsForLocalIds(List<int> planIds) {
    return _serverIdsForLocalIds(
      tableName: DbConstants.plans,
      localIds: planIds,
      label: 'plan',
    );
  }

  Future<void> replaceAssignmentsFromServer({
    required String userUuid,
    required List<AccessAssignmentRecord> customerAccess,
    required List<AccessAssignmentRecord> planAccess,
  }) async {
    final database = await db;
    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction((txn) async {
      await _replaceAccessTableFromServer(
        txn: txn,
        tableName: DbConstants.customerUserAccess,
        userUuid: userUuid,
        targetTable: DbConstants.customers,
        targetColumn: 'customer_uuid',
        records: customerAccess,
        now: now,
      );
      await _replaceAccessTableFromServer(
        txn: txn,
        tableName: DbConstants.planUserAccess,
        userUuid: userUuid,
        targetTable: DbConstants.plans,
        targetColumn: 'plan_uuid',
        records: planAccess,
        now: now,
      );
    });
  }

  Future<void> saveAssignments({
    required String userUuid,
    required List<int> customerIds,
    required List<int> planIds,
  }) async {
    final database = await db;
    final now = DateTime.now();
    await database.transaction((txn) async {
      final normalizedPlanIds = planIds.toSet();
      if (normalizedPlanIds.isNotEmpty) {
        final placeholders = List.filled(
          normalizedPlanIds.length,
          '?',
        ).join(',');
        final blockedRows = await txn.query(
          DbConstants.planUserAccess,
          where:
              'plan_uuid IN ($placeholders) AND user_uuid != ? AND is_deleted = 0',
          whereArgs: [...normalizedPlanIds.map((item) => '$item'), userUuid],
          limit: 1,
        );
        if (blockedRows.isNotEmpty) {
          throw StateError(
            'One or more selected plans are already assigned to another salesman.',
          );
        }
      }

      await txn.update(
        DbConstants.customerUserAccess,
        SyncMetadata.withLocalChange(DbConstants.customerUserAccess, {
          'is_deleted': 1,
        }),
        where: 'user_uuid = ?',
        whereArgs: [userUuid],
      );
      await txn.update(
        DbConstants.planUserAccess,
        SyncMetadata.withLocalChange(DbConstants.planUserAccess, {
          'is_deleted': 1,
        }),
        where: 'user_uuid = ?',
        whereArgs: [userUuid],
      );

      for (final customerId in customerIds.toSet()) {
        await txn.insert(
          DbConstants.customerUserAccess,
          SyncMetadata.withLocalChange(
            DbConstants.customerUserAccess,
            CustomerUserAccessModel(
              uuid: IdGenerator.localUuid(),
              userUuid: userUuid,
              customerUuid: '$customerId',
              isSync: false,
              createdAt: now,
              updatedAt: now,
            ).toMap()..remove('id'),
          ),
        );
      }

      for (final planId in normalizedPlanIds) {
        await txn.insert(
          DbConstants.planUserAccess,
          SyncMetadata.withLocalChange(
            DbConstants.planUserAccess,
            PlanUserAccessModel(
              uuid: IdGenerator.localUuid(),
              userUuid: userUuid,
              planUuid: '$planId',
              isSync: false,
              createdAt: now,
              updatedAt: now,
            ).toMap()..remove('id'),
          ),
        );
      }
    });
  }

  Future<List<String>> _serverIdsForLocalIds({
    required String tableName,
    required List<int> localIds,
    required String label,
  }) async {
    final database = await db;
    final result = <String>[];
    for (final localId in localIds.toSet()) {
      final rows = await database.query(
        tableName,
        columns: ['id', SyncMetadata.serverId],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [localId],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Selected $label is unavailable locally.');
      }
      result.add(_requiredServerId(rows.first, 'Selected $label'));
    }
    return result;
  }

  Future<void> _replaceAccessTableFromServer({
    required dynamic txn,
    required String tableName,
    required String userUuid,
    required String targetTable,
    required String targetColumn,
    required List<AccessAssignmentRecord> records,
    required String now,
  }) async {
    await txn.update(
      tableName,
      SyncMetadata.withServerChange(tableName, {
        SyncMetadata.isDeleted: 1,
        SyncMetadata.dateUpdated: now,
        'updated_at': now,
      }),
      where: 'user_uuid = ?',
      whereArgs: [userUuid],
    );

    for (final record in records.where((item) => !item.isDeleted)) {
      final localTargetId = await _localIdForServerId(
        txn,
        targetTable,
        record.targetId,
      );
      if (localTargetId == null) {
        throw StateError('Assigned record is unavailable locally.');
      }

      final existing = await _findAccessRow(
        txn,
        tableName,
        record.serverId,
        userUuid,
        targetColumn,
        localTargetId,
      );
      final updatedAt = record.updatedAt ?? now;
      final values = SyncMetadata.withServerChange(tableName, {
        SyncMetadata.serverId: record.serverId,
        SyncMetadata.dateUpdated: updatedAt,
        SyncMetadata.isDeleted: 0,
        'uuid': record.serverId,
        'user_uuid': userUuid,
        targetColumn: '$localTargetId',
        'created_at': record.createdAt ?? updatedAt,
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
  }

  Future<Map<String, Object?>?> _findAccessRow(
    dynamic txn,
    String tableName,
    String serverId,
    String userUuid,
    String targetColumn,
    int localTargetId,
  ) async {
    final rows = await txn.query(
      tableName,
      where: 'uuid = ? OR ${SyncMetadata.serverId} = ?',
      whereArgs: [serverId, serverId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      return rows.first;
    }

    final pairRows = await txn.query(
      tableName,
      where: 'user_uuid = ? AND $targetColumn = ?',
      whereArgs: [userUuid, '$localTargetId'],
      limit: 1,
    );
    return pairRows.isEmpty ? null : pairRows.first;
  }

  Future<int?> _localIdForServerId(
    dynamic txn,
    String tableName,
    String serverId,
  ) async {
    final rows = await txn.query(
      tableName,
      columns: ['id'],
      where: '${SyncMetadata.serverId} = ? AND is_deleted = 0',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : (rows.first['id'] as num?)?.toInt();
  }

  String _requiredServerId(Map<String, Object?> row, String label) {
    final serverId = row[SyncMetadata.serverId]?.toString().trim();
    if (serverId != null && serverId.isNotEmpty) {
      return serverId;
    }

    final uuid = row['uuid']?.toString().trim();
    if (uuid != null && _isUuid(uuid)) {
      return uuid;
    }

    throw StateError('$label must be synced before assignment.');
  }

  bool _isUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}
