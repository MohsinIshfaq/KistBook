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
import 'package:kistbook/data/repositories/customer_plan_refresh_repository.dart';
import 'package:kistbook/data/repositories/customer_repository.dart';
import 'package:kistbook/data/repositories/installment_plan_sync_repository.dart';
import 'package:kistbook/data/repositories/product_sync_repository.dart';
import 'package:kistbook/data/sync/sync_batch_models.dart';
import 'package:kistbook/data/sync/sync_cursor_store.dart';
import 'package:kistbook/services/session_manager.dart';
import 'package:kistbook/services/sync_change_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('refresh applies related products before customer plans', () async {
    final fixture = await _CustomerPlanRefreshFixture.create();
    final customerId = await fixture.insertCustomer(
      serverId: 'server-customer-detail',
    );
    fixture.remote.planResponses.add({
      'success': true,
      'data': {
        'customerId': 'server-customer-detail',
        'products': [
          {
            'serverId': 'server-product-detail',
            'brandName': 'Brand',
            'productName': 'Server Product',
            'skuCode': 'SKU-DETAIL',
            'salesPrice': 12000,
            'notes': '',
            'productImages': [],
            'variants': [],
            'priceHistory': [],
            'isDeleted': false,
            'createdAt': '2026-06-04T09:00:00.000Z',
            'updatedAt': '2026-06-04T09:00:00.000Z',
          },
        ],
        'plans': [
          {
            'serverId': 'server-plan-detail',
            'customerId': 'server-customer-detail',
            'mode': 'common',
            'selectedProducts': [
              {
                'serverId': 'server-plan-item-detail',
                'productId': 'server-product-detail',
                'quantity': 1,
                'agreedPrice': 12000,
                'itemName': 'Server Product',
              },
            ],
            'commonDeposit': 1000,
            'commonInstallmentAmount': 3000,
            'commonFrequencyInDays': 30,
            'commonFirstDueDate': '2026-06-01T00:00:00.000Z',
            'totalAmount': 12000,
            'remainingAmount': 11000,
            'installmentCount': 4,
            'note': 'Remote customer plan',
            'schedules': [
              {
                'serverId': 'server-schedule-detail',
                'sequenceNumber': 1,
                'scheduledDueDate': '2026-06-01T00:00:00.000Z',
                'currentDueDate': '2026-06-01T00:00:00.000Z',
                'amount': 3000,
                'paidAmount': 0,
                'status': 'pending',
                'isDeleted': false,
                'createdAt': '2026-06-04T09:00:00.000Z',
                'updatedAt': '2026-06-04T09:00:00.000Z',
              },
            ],
            'isDeleted': false,
            'createdAt': '2026-06-04T09:00:00.000Z',
            'updatedAt': '2026-06-04T09:00:00.000Z',
          },
        ],
      },
    });

    final result = await fixture.repository.refreshCustomerPlans(customerId);
    final profile = await fixture.customerRepository.fetchCustomerProfile(
      customerId,
    );

    expect(result.didRefresh, isTrue);
    expect(result.productCount, 1);
    expect(result.planCount, 1);
    expect(fixture.remote.planDetailCalls, ['server-customer-detail']);
    expect(profile?.products.single.name, 'Server Product');
    expect(profile?.plans.single.notes, 'Remote customer plan');
    expect(profile?.history.any((item) => item.productIds.isNotEmpty), isTrue);

    await fixture.dispose();
  });

  test('refresh skips local-only customers without server id', () async {
    final fixture = await _CustomerPlanRefreshFixture.create();
    final customerId = await fixture.insertCustomer();

    final result = await fixture.repository.refreshCustomerPlans(customerId);

    expect(result.didRefresh, isFalse);
    expect(fixture.remote.planDetailCalls, isEmpty);

    await fixture.dispose();
  });
}

class _CustomerPlanRefreshFixture {
  _CustomerPlanRefreshFixture({
    required this.directory,
    required this.dbHelper,
    required this.remote,
    required this.customerRepository,
    required this.repository,
    required this.changeNotifier,
  });

  final Directory directory;
  final DbHelper dbHelper;
  final _FakeCustomerRemoteDataSource remote;
  final CustomerRepository customerRepository;
  final CustomerPlanRefreshRepository repository;
  final SyncChangeNotifier changeNotifier;

  static Future<_CustomerPlanRefreshFixture> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = await Directory.systemTemp.createTemp(
      'kistbook_customer_plan_refresh_',
    );
    final dbHelper = DbHelper(databasePath: p.join(directory.path, 'test.db'));
    await dbHelper.initialize();
    final remote = _FakeCustomerRemoteDataSource(preferences);
    final cursorStore = SyncCursorStore();
    final changeNotifier = SyncChangeNotifier();
    final customerRepository = CustomerRepository(dbHelper);
    final productSyncRepository = ProductSyncRepository(
      dbHelper: dbHelper,
      remoteDataSource: _FakeProductRemoteDataSource(preferences),
      cursorStore: cursorStore,
      changeNotifier: changeNotifier,
    );
    final installmentPlanSyncRepository = InstallmentPlanSyncRepository(
      dbHelper: dbHelper,
      remoteDataSource: _FakeInstallmentPlanRemoteDataSource(preferences),
      cursorStore: cursorStore,
      changeNotifier: changeNotifier,
    );
    final repository = CustomerPlanRefreshRepository(
      customerRepository: customerRepository,
      remoteDataSource: remote,
      productSyncRepository: productSyncRepository,
      installmentPlanSyncRepository: installmentPlanSyncRepository,
    );
    return _CustomerPlanRefreshFixture(
      directory: directory,
      dbHelper: dbHelper,
      remote: remote,
      customerRepository: customerRepository,
      repository: repository,
      changeNotifier: changeNotifier,
    );
  }

  Future<int> insertCustomer({String? serverId}) async {
    final db = await dbHelper.database;
    final values = <String, Object?>{
      'card_number': 'CARD-DETAIL',
      'name': 'Detail Customer',
      'phone': '03001234567',
      'cnic': '42101-0000000-1',
      'address': 'Lahore',
      'reference_name': '',
      'created_at': DateTime(2026, 6, 1).toIso8601String(),
    };
    if (serverId != null) {
      values[SyncMetadata.serverId] = serverId;
    }
    return db.insert(
      DbConstants.customers,
      SyncMetadata.withServerChange(DbConstants.customers, values),
    );
  }

  Future<void> dispose() async {
    changeNotifier.dispose();
    final db = await dbHelper.database;
    await db.close();
    await directory.delete(recursive: true);
  }
}

class _FakeCustomerRemoteDataSource extends CustomerRemoteDataSource {
  _FakeCustomerRemoteDataSource(SharedPreferences preferences)
    : super(_NoopApiServices(preferences));

  final planResponses = <Map<String, dynamic>>[];
  final planDetailCalls = <String>[];

  @override
  Future<Map<String, dynamic>> planDetails(String serverId) async {
    planDetailCalls.add(serverId);
    return planResponses.removeAt(0);
  }
}

class _FakeProductRemoteDataSource extends ProductRemoteDataSource {
  _FakeProductRemoteDataSource(SharedPreferences preferences)
    : super(_NoopApiServices(preferences));
}

class _FakeInstallmentPlanRemoteDataSource
    extends InstallmentPlanRemoteDataSource {
  _FakeInstallmentPlanRemoteDataSource(SharedPreferences preferences)
    : super(_NoopApiServices(preferences));

  @override
  Future<SyncDownloadResult> download({
    String? lastUpdatedAt,
    String? lastServerId,
    int limit = 10,
  }) async {
    return const SyncDownloadResult(
      records: [],
      serverTime: '2026-06-04T10:00:00.000Z',
      hasMore: false,
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
