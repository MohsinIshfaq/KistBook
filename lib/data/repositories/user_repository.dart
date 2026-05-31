import '../../core/constants/app_enums.dart';
import '../../core/utils/id_generator.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../database/sync_metadata.dart';
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
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    final now = DateTime.now();
    final user = LocalUserModel(
      uuid: IdGenerator.localUuid(),
      phone: phone,
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

  Future<void> saveAssignments({
    required String userUuid,
    required List<int> customerIds,
    required List<int> planIds,
  }) async {
    final database = await db;
    final now = DateTime.now();
    await database.transaction((txn) async {
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

      for (final planId in planIds.toSet()) {
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
}
