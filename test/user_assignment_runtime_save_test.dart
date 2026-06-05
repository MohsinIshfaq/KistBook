import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kistbook/core/constants/app_enums.dart';
import 'package:kistbook/core/services/api_services.dart';
import 'package:kistbook/data/database/db_constants.dart';
import 'package:kistbook/data/database/db_helper.dart';
import 'package:kistbook/data/database/sync_metadata.dart';
import 'package:kistbook/data/datasources/access_assignment_remote_data_source.dart';
import 'package:kistbook/data/models/local_user_model.dart';
import 'package:kistbook/data/repositories/auth_repository.dart';
import 'package:kistbook/data/repositories/customer_repository.dart';
import 'package:kistbook/data/repositories/installment_repository.dart';
import 'package:kistbook/data/repositories/user_repository.dart';
import 'package:kistbook/modules/users/user_controller.dart';
import 'package:kistbook/services/auth_api_service.dart';
import 'package:kistbook/services/session_manager.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'saveAssignmentsForUser calls API with server UUIDs and mirrors response locally',
    () async {
      final fixture = await _AssignmentRuntimeFixture.create();
      final salesman = await fixture.insertSalesman();
      final customerId = await fixture.insertCustomer('server-customer-1');
      final productId = await fixture.insertProduct('server-product-1');
      final planId = await fixture.insertPlan(
        serverId: 'server-plan-1',
        customerId: customerId,
        productId: productId,
      );
      final controller = fixture.controller();
      controller.assignedCustomerIds = {customerId};
      controller.assignedPlanIds = {planId};

      await controller.saveAssignmentsForUser(salesman);

      expect(fixture.remote.calls, hasLength(1));
      expect(
        fixture.remote.calls.single['userId'],
        '11111111-1111-4111-8111-111111111111',
      );
      expect(fixture.remote.calls.single['customerIds'], ['server-customer-1']);
      expect(fixture.remote.calls.single['planIds'], ['server-plan-1']);

      final customerAccess = await fixture.activeAccessRow(
        DbConstants.customerUserAccess,
        'customer_uuid',
        customerId,
      );
      final planAccess = await fixture.activeAccessRow(
        DbConstants.planUserAccess,
        'plan_uuid',
        planId,
      );
      expect(
        customerAccess?[SyncMetadata.serverId],
        'server-customer-access-0',
      );
      expect(customerAccess?[SyncMetadata.isSync], 1);
      expect(planAccess?[SyncMetadata.serverId], 'server-plan-access-0');
      expect(planAccess?[SyncMetadata.isSync], 1);

      await fixture.dispose();
    },
  );

  test(
    'failed assignment API call leaves previous local assignments unchanged',
    () async {
      final fixture = await _AssignmentRuntimeFixture.create();
      final salesman = await fixture.insertSalesman();
      final oldCustomerId = await fixture.insertCustomer('server-customer-old');
      final newCustomerId = await fixture.insertCustomer('server-customer-new');
      await fixture.insertCustomerAccess(
        userUuid: salesman.uuid,
        customerId: oldCustomerId,
        serverId: 'server-old-access',
      );
      fixture.remote.failure = const ApiException(message: 'No internet.');
      final controller = fixture.controller();
      controller.assignedCustomerIds = {newCustomerId};
      controller.assignedPlanIds = {};

      await expectLater(
        controller.saveAssignmentsForUser(salesman),
        throwsA(isA<ApiException>()),
      );

      expect(
        await fixture.activeAccessRow(
          DbConstants.customerUserAccess,
          'customer_uuid',
          oldCustomerId,
        ),
        isNotNull,
      );
      expect(
        await fixture.activeAccessRow(
          DbConstants.customerUserAccess,
          'customer_uuid',
          newCustomerId,
        ),
        isNull,
      );

      await fixture.dispose();
    },
  );

  test('unsynced selected customer fails before API call', () async {
    final fixture = await _AssignmentRuntimeFixture.create();
    final salesman = await fixture.insertSalesman();
    final customerId = await fixture.insertCustomer(null);
    final controller = fixture.controller();
    controller.assignedCustomerIds = {customerId};
    controller.assignedPlanIds = {};

    await expectLater(
      controller.saveAssignmentsForUser(salesman),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('Selected customer must be synced before assignment.'),
        ),
      ),
    );
    expect(fixture.remote.calls, isEmpty);

    await fixture.dispose();
  });
}

class _AssignmentRuntimeFixture {
  _AssignmentRuntimeFixture({
    required this.directory,
    required this.dbHelper,
    required this.userRepository,
    required this.remote,
    required this.apiServices,
  });

  final Directory directory;
  final DbHelper dbHelper;
  final UserRepository userRepository;
  final _FakeAccessAssignmentRemoteDataSource remote;
  final ApiServices apiServices;

  static Future<_AssignmentRuntimeFixture> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = await Directory.systemTemp.createTemp(
      'kistbook_assignment_runtime_',
    );
    final dbHelper = DbHelper(databasePath: p.join(directory.path, 'test.db'));
    await dbHelper.initialize();
    final apiServices = _NoopApiServices(preferences);
    final remote = _FakeAccessAssignmentRemoteDataSource(apiServices);

    return _AssignmentRuntimeFixture(
      directory: directory,
      dbHelper: dbHelper,
      userRepository: UserRepository(dbHelper),
      remote: remote,
      apiServices: apiServices,
    );
  }

  UserController controller() {
    return UserController(
      userRepository: userRepository,
      customerRepository: CustomerRepository(dbHelper),
      installmentRepository: InstallmentRepository(dbHelper),
      authApiService: AuthApiService(AuthRepository(apiServices)),
      accessAssignmentRemoteDataSource: remote,
    );
  }

  Future<LocalUserModel> insertSalesman() {
    return userRepository.saveUser(
      LocalUserModel(
        uuid: '11111111-1111-4111-8111-111111111111',
        phone: '03001234567',
        email: 'sales@example.com',
        password: 'password',
        firstName: 'Sales',
        lastName: 'User',
        role: UserRole.salesMan,
        isActive: true,
        isSync: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<int> insertCustomer(String? serverId) async {
    final db = await dbHelper.database;
    final values = <String, Object?>{
      'card_number': 'CARD-${serverId ?? 'LOCAL'}',
      'name': 'Customer',
      'phone': '03001234567',
      'cnic': '42101-${DateTime.now().microsecondsSinceEpoch}-1',
      'address': 'Lahore',
      'reference_name': '',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (serverId != null) {
      values[SyncMetadata.serverId] = serverId;
    }

    return db.insert(
      DbConstants.customers,
      serverId == null
          ? SyncMetadata.withLocalChange(DbConstants.customers, values)
          : SyncMetadata.withServerChange(DbConstants.customers, values),
    );
  }

  Future<int> insertProduct(String serverId) async {
    final db = await dbHelper.database;

    return db.insert(
      DbConstants.products,
      SyncMetadata.withServerChange(DbConstants.products, {
        SyncMetadata.serverId: serverId,
        'categories_text': '[]',
        'brand_name': '',
        'name': 'Product',
        'sku': '',
        'sale_price': 10000,
        'notes': '',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<int> insertPlan({
    required String serverId,
    required int customerId,
    required int productId,
  }) async {
    final db = await dbHelper.database;

    return db.insert(
      DbConstants.plans,
      SyncMetadata.withServerChange(DbConstants.plans, {
        SyncMetadata.serverId: serverId,
        'customer_id': customerId,
        'product_id': productId,
        'quantity': 1,
        'unit_price': 10000,
        'product_ids_text': '$productId',
        'product_selections_text': '[{"product_id":$productId,"quantity":1}]',
        'item_name': 'Product x1',
        'total_amount': 10000,
        'deposit_amount': 1000,
        'installment_amount': 3000,
        'installment_count': 3,
        'frequency_days': 30,
        'start_date_iso': '2026-06-01T00:00:00.000Z',
        'notes': '',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<void> insertCustomerAccess({
    required String userUuid,
    required int customerId,
    required String serverId,
  }) async {
    final db = await dbHelper.database;
    await db.insert(
      DbConstants.customerUserAccess,
      SyncMetadata.withServerChange(DbConstants.customerUserAccess, {
        SyncMetadata.serverId: serverId,
        'uuid': serverId,
        'user_uuid': userUuid,
        'customer_uuid': '$customerId',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<Map<String, Object?>?> activeAccessRow(
    String tableName,
    String targetColumn,
    int targetId,
  ) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      tableName,
      where: '$targetColumn = ? AND is_deleted = 0',
      whereArgs: ['$targetId'],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> dispose() async {
    final db = await dbHelper.database;
    await db.close();
    await directory.delete(recursive: true);
  }
}

class _FakeAccessAssignmentRemoteDataSource
    extends AccessAssignmentRemoteDataSource {
  _FakeAccessAssignmentRemoteDataSource(super.apiServices);

  final calls = <Map<String, Object?>>[];
  ApiException? failure;

  @override
  Future<AccessAssignmentSaveResult> replaceAssignments({
    required String userId,
    required List<String> customerIds,
    required List<String> planIds,
  }) async {
    calls.add({
      'userId': userId,
      'customerIds': customerIds,
      'planIds': planIds,
    });
    final error = failure;
    if (error != null) {
      throw error;
    }

    return AccessAssignmentSaveResult(
      userId: userId,
      customerAccess: [
        for (var index = 0; index < customerIds.length; index += 1)
          AccessAssignmentRecord(
            serverId: 'server-customer-access-$index',
            userId: userId,
            targetId: customerIds[index],
            isDeleted: false,
            createdAt: '2026-06-04T09:00:00.000Z',
            updatedAt: '2026-06-04T09:05:00.000Z',
          ),
      ],
      planAccess: [
        for (var index = 0; index < planIds.length; index += 1)
          AccessAssignmentRecord(
            serverId: 'server-plan-access-$index',
            userId: userId,
            targetId: planIds[index],
            isDeleted: false,
            createdAt: '2026-06-04T09:00:00.000Z',
            updatedAt: '2026-06-04T09:05:00.000Z',
          ),
      ],
    );
  }
}

class _NoopApiServices extends ApiServices {
  _NoopApiServices(SharedPreferences preferences)
    : super(
        sessionManager: _NoopSessionManager(preferences),
        httpClient: http.Client(),
      );
}

class _NoopSessionManager extends SessionManager {
  _NoopSessionManager(super.preferences)
    : super(secureStorage: const FlutterSecureStorage());
}
