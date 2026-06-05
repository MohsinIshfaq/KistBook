import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kistbook/core/services/api_services.dart';
import 'package:kistbook/data/database/db_constants.dart';
import 'package:kistbook/data/database/db_helper.dart';
import 'package:kistbook/data/database/sync_metadata.dart';
import 'package:kistbook/data/datasources/customer_remote_data_source.dart';
import 'package:kistbook/data/datasources/installment_plan_remote_data_source.dart';
import 'package:kistbook/data/datasources/product_remote_data_source.dart';
import 'package:kistbook/data/datasources/runtime_bootstrap_remote_data_source.dart';
import 'package:kistbook/data/repositories/customer_sync_repository.dart';
import 'package:kistbook/data/repositories/installment_plan_sync_repository.dart';
import 'package:kistbook/data/repositories/product_sync_repository.dart';
import 'package:kistbook/data/repositories/runtime_bootstrap_repository.dart';
import 'package:kistbook/data/sync/sync_cursor_store.dart';
import 'package:kistbook/services/session_manager.dart';
import 'package:kistbook/services/sync_change_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'runtime bootstrap stores assigned plan, customer and local access rows',
    () async {
      final fixture = await _RuntimeBootstrapFixture.create();
      final events = <SyncResource>[];
      final subscription = fixture.changeNotifier.stream.listen(events.add);
      fixture.remote.response = {
        'data': {
          'users': [
            {
              'serverId': 'server-user-sales',
              'uuid': 'server-user-sales',
              'phoneNumber': '03001234567',
              'email': 'sales@example.com',
              'firstName': 'Sales',
              'lastName': 'User',
              'role': 'salesman',
              'isActive': true,
              'isDeleted': false,
              'createdAt': '2026-06-04T09:00:00.000Z',
              'updatedAt': '2026-06-04T09:00:00.000Z',
            },
          ],
          'customers': [
            {
              'serverId': 'server-customer-1',
              'cardNumber': 'CARD-1',
              'customerName': 'Assigned Customer',
              'phoneNumber': '03009998888',
              'cnic': '42101-0000000-1',
              'address': 'Lahore',
              'reference': 'Owner',
              'isDeleted': false,
              'createdAt': '2026-06-04T09:00:00.000Z',
              'updatedAt': '2026-06-04T09:05:00.000Z',
            },
          ],
          'products': [
            {
              'serverId': 'server-product-1',
              'productName': 'Assigned Product',
              'salesPrice': 120000,
              'brandName': '',
              'skuCode': '',
              'notes': '',
              'productImages': [],
              'variants': [],
              'priceHistory': [],
              'isDeleted': false,
              'createdAt': '2026-06-04T09:00:00.000Z',
              'updatedAt': '2026-06-04T09:05:00.000Z',
            },
          ],
          'installmentPlans': [
            {
              'serverId': 'server-plan-1',
              'customerId': 'server-customer-1',
              'mode': 'common',
              'selectedProducts': [
                {
                  'serverId': 'server-plan-item-1',
                  'productId': 'server-product-1',
                  'quantity': 1,
                  'agreedPrice': 120000,
                  'itemName': 'Assigned Product x1',
                },
              ],
              'commonDeposit': 20000,
              'commonInstallmentAmount': 10000,
              'commonFrequencyInDays': 30,
              'commonFirstDueDate': '2026-07-01T00:00:00.000Z',
              'totalAmount': 120000,
              'remainingAmount': 100000,
              'installmentCount': 10,
              'note': 'Assigned plan',
              'schedules': [
                {
                  'serverId': 'server-installment-1',
                  'sequenceNumber': 1,
                  'scheduledDueDate': '2026-07-01T00:00:00.000Z',
                  'currentDueDate': '2026-07-01T00:00:00.000Z',
                  'amount': 10000,
                  'paidAmount': 0,
                  'status': 'pending',
                  'isDeleted': false,
                  'createdAt': '2026-06-04T09:00:00.000Z',
                  'updatedAt': '2026-06-04T09:05:00.000Z',
                },
              ],
              'isDeleted': false,
              'createdAt': '2026-06-04T09:00:00.000Z',
              'updatedAt': '2026-06-04T09:05:00.000Z',
            },
          ],
          'customerAccess': [],
          'planAccess': [
            {
              'serverId': 'server-plan-access-1',
              'userId': 'server-user-sales',
              'planId': 'server-plan-1',
              'isDeleted': false,
              'createdAt': '2026-06-04T09:00:00.000Z',
              'updatedAt': '2026-06-04T09:05:00.000Z',
            },
          ],
        },
      };

      await fixture.repository.bootstrap();
      await Future<void>.delayed(Duration.zero);

      final customer = await fixture.rowByServerId(
        DbConstants.customers,
        'server-customer-1',
      );
      final product = await fixture.rowByServerId(
        DbConstants.products,
        'server-product-1',
      );
      final plan = await fixture.rowByServerId(
        DbConstants.plans,
        'server-plan-1',
      );
      final planAccess = await fixture.accessRow(
        tableName: DbConstants.planUserAccess,
        serverId: 'server-plan-access-1',
      );

      expect(customer?['name'], 'Assigned Customer');
      expect(product?['name'], 'Assigned Product');
      expect(plan?['notes'], 'Assigned plan');
      expect(planAccess?['user_uuid'], 'server-user-sales');
      expect(planAccess?['plan_uuid'], '${plan?['id']}');
      expect(planAccess?[SyncMetadata.isSync], 1);
      expect(
        events,
        containsAll(<SyncResource>[
          SyncResource.customers,
          SyncResource.products,
          SyncResource.installmentPlans,
        ]),
      );

      await subscription.cancel();
      await fixture.dispose();
    },
  );
}

class _RuntimeBootstrapFixture {
  _RuntimeBootstrapFixture({
    required this.directory,
    required this.dbHelper,
    required this.remote,
    required this.repository,
    required this.changeNotifier,
  });

  final Directory directory;
  final DbHelper dbHelper;
  final _FakeRuntimeBootstrapRemoteDataSource remote;
  final RuntimeBootstrapRepository repository;
  final SyncChangeNotifier changeNotifier;

  static Future<_RuntimeBootstrapFixture> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = await Directory.systemTemp.createTemp(
      'kistbook_runtime_bootstrap_',
    );
    final dbHelper = DbHelper(databasePath: p.join(directory.path, 'test.db'));
    await dbHelper.initialize();
    final apiServices = _NoopApiServices(preferences);
    final cursorStore = SyncCursorStore();
    final changeNotifier = SyncChangeNotifier();
    final remote = _FakeRuntimeBootstrapRemoteDataSource(apiServices);
    final repository = RuntimeBootstrapRepository(
      dbHelper: dbHelper,
      remoteDataSource: remote,
      customerSyncRepository: CustomerSyncRepository(
        dbHelper: dbHelper,
        remoteDataSource: CustomerRemoteDataSource(apiServices),
        cursorStore: cursorStore,
        changeNotifier: changeNotifier,
      ),
      productSyncRepository: ProductSyncRepository(
        dbHelper: dbHelper,
        remoteDataSource: ProductRemoteDataSource(apiServices),
        cursorStore: cursorStore,
        changeNotifier: changeNotifier,
      ),
      installmentPlanSyncRepository: InstallmentPlanSyncRepository(
        dbHelper: dbHelper,
        remoteDataSource: InstallmentPlanRemoteDataSource(apiServices),
        cursorStore: cursorStore,
        changeNotifier: changeNotifier,
      ),
      changeNotifier: changeNotifier,
    );
    return _RuntimeBootstrapFixture(
      directory: directory,
      dbHelper: dbHelper,
      remote: remote,
      repository: repository,
      changeNotifier: changeNotifier,
    );
  }

  Future<Map<String, Object?>?> rowByServerId(
    String tableName,
    String serverId,
  ) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      tableName,
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> accessRow({
    required String tableName,
    required String serverId,
  }) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      tableName,
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> dispose() async {
    changeNotifier.dispose();
    final db = await dbHelper.database;
    await db.close();
    await directory.delete(recursive: true);
  }
}

class _FakeRuntimeBootstrapRemoteDataSource
    extends RuntimeBootstrapRemoteDataSource {
  _FakeRuntimeBootstrapRemoteDataSource(super.apiServices);

  Map<String, dynamic> response = const {'data': <String, dynamic>{}};

  @override
  Future<Map<String, dynamic>> fetch() async => response;
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
