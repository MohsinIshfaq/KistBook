import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kistbook/core/services/api_services.dart';
import 'package:kistbook/data/database/db_constants.dart';
import 'package:kistbook/data/database/db_helper.dart';
import 'package:kistbook/data/database/sync_metadata.dart';
import 'package:kistbook/data/datasources/installment_plan_remote_data_source.dart';
import 'package:kistbook/data/repositories/installment_plan_sync_repository.dart';
import 'package:kistbook/data/sync/sync_batch_models.dart';
import 'package:kistbook/data/sync/sync_cursor_store.dart';
import 'package:kistbook/services/session_manager.dart';
import 'package:kistbook/services/sync_change_notifier.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test(
    'plan create uploads canonical payload and stores plan/schedule mappings',
    () async {
      final fixture = await _InstallmentPlanSyncFixture.create();
      final customerId = await fixture.insertCustomer(
        serverId: 'server-customer-1',
      );
      final productId = await fixture.insertProduct(
        serverId: 'server-product-1',
      );
      final planId = await fixture.insertPlan(
        customerId: customerId,
        productId: productId,
      );

      await fixture.repository.uploadPending();

      final payload = fixture.remote.created.single.single;
      expect(payload['customerId'], 'server-customer-1');
      expect(payload['mode'], 'common');
      expect(payload['commonInstallmentAmount'], 3000);
      expect(payload['selectedProducts'], [
        {
          'productId': 'server-product-1',
          'quantity': 1,
          'agreedPrice': 10000.0,
        },
      ]);

      final plan = await fixture.planRow(planId);
      expect(plan?[SyncMetadata.serverId], 'server-plan-0');
      expect(plan?[SyncMetadata.isSync], 1);
      expect(await fixture.syncedInstallmentCount(planId), 3);
      await fixture.dispose();
    },
  );

  test('plan download applies server rows and advances cursor', () async {
    final fixture = await _InstallmentPlanSyncFixture.create();
    await fixture.insertCustomer(serverId: 'server-customer-download');
    await fixture.insertProduct(serverId: 'server-product-download');
    final events = <SyncResource>[];
    final subscription = fixture.changeNotifier.stream.listen(events.add);

    fixture.remote.downloadResults.add(
      const SyncDownloadResult(
        records: [
          {
            'serverId': 'server-plan-download',
            'customerId': 'server-customer-download',
            'mode': 'common',
            'selectedProducts': [
              {
                'serverId': 'server-plan-item-download',
                'productId': 'server-product-download',
                'quantity': 1,
                'agreedPrice': 10000,
                'itemName': 'Server Product x1',
              },
            ],
            'commonDeposit': 1000,
            'commonInstallmentAmount': 3000,
            'commonFrequencyInDays': 30,
            'commonFirstDueDate': '2026-06-01T00:00:00.000Z',
            'totalAmount': 10000,
            'remainingAmount': 9000,
            'installmentCount': 3,
            'note': 'Downloaded plan',
            'schedules': [
              {
                'serverId': 'server-installment-1',
                'sequenceNumber': 1,
                'scheduledDueDate': '2026-06-01T00:00:00.000Z',
                'currentDueDate': '2026-06-01T00:00:00.000Z',
                'amount': 3000,
                'paidAmount': 0,
                'status': 'pending',
                'isDeleted': false,
                'updatedAt': '2026-06-04T09:00:00.000Z',
              },
              {
                'serverId': 'server-installment-2',
                'sequenceNumber': 2,
                'scheduledDueDate': '2026-07-01T00:00:00.000Z',
                'currentDueDate': '2026-07-01T00:00:00.000Z',
                'amount': 3000,
                'paidAmount': 0,
                'status': 'pending',
                'isDeleted': false,
                'updatedAt': '2026-06-04T09:00:00.000Z',
              },
            ],
            'isDeleted': false,
            'createdAt': '2026-06-04T09:00:00.000Z',
            'updatedAt': '2026-06-04T09:10:00.000Z',
          },
        ],
        serverTime: '2026-06-04T09:11:00.000Z',
        hasMore: false,
        nextCursor: SyncCursor(
          lastUpdatedAt: '2026-06-04T09:10:00.000Z',
          lastServerId: 'server-plan-download',
        ),
      ),
    );

    await fixture.repository.downloadLatest();
    await Future<void>.delayed(Duration.zero);

    final plan = await fixture.planByServerId('server-plan-download');
    expect(plan?['notes'], 'Downloaded plan');
    expect(plan?[SyncMetadata.isSync], 1);
    expect(await fixture.syncedInstallmentCount(plan?['id'] as int), 2);
    expect(fixture.remote.downloadCalls, hasLength(2));
    expect(
      fixture.remote.downloadCalls.first['lastUpdatedAt'],
      '2001-01-01T00:00:00.000Z',
    );
    expect(
      (await fixture.cursorStore.read(
        SyncCursorStore.installmentPlans,
      )).lastUpdatedAt,
      '2026-06-04T09:10:00.000Z',
    );
    expect(events, contains(SyncResource.installmentPlans));

    await subscription.cancel();
    await fixture.dispose();
  });
}

class _InstallmentPlanSyncFixture {
  _InstallmentPlanSyncFixture({
    required this.directory,
    required this.dbHelper,
    required this.remote,
    required this.repository,
    required this.cursorStore,
    required this.changeNotifier,
  });

  final Directory directory;
  final DbHelper dbHelper;
  final _FakeInstallmentPlanRemoteDataSource remote;
  final InstallmentPlanSyncRepository repository;
  final SyncCursorStore cursorStore;
  final SyncChangeNotifier changeNotifier;

  static Future<_InstallmentPlanSyncFixture> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = await Directory.systemTemp.createTemp(
      'kistbook_plan_sync_',
    );
    final dbHelper = DbHelper(databasePath: p.join(directory.path, 'test.db'));
    await dbHelper.initialize();
    final remote = _FakeInstallmentPlanRemoteDataSource(preferences);
    final cursorStore = SyncCursorStore();
    final changeNotifier = SyncChangeNotifier();
    final repository = InstallmentPlanSyncRepository(
      dbHelper: dbHelper,
      remoteDataSource: remote,
      cursorStore: cursorStore,
      changeNotifier: changeNotifier,
    );
    return _InstallmentPlanSyncFixture(
      directory: directory,
      dbHelper: dbHelper,
      remote: remote,
      repository: repository,
      cursorStore: cursorStore,
      changeNotifier: changeNotifier,
    );
  }

  Future<int> insertCustomer({required String serverId}) async {
    final db = await dbHelper.database;
    return db.insert(
      DbConstants.customers,
      SyncMetadata.withServerChange(DbConstants.customers, {
        SyncMetadata.serverId: serverId,
        'card_number': 'CARD-1',
        'name': 'Customer',
        'phone': '03001234567',
        'cnic': '42101-0000000-1',
        'address': 'Lahore',
        'reference_name': '',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<int> insertProduct({required String serverId}) async {
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
    required int customerId,
    required int productId,
  }) async {
    final db = await dbHelper.database;
    final planId = await db.insert(
      DbConstants.plans,
      SyncMetadata.withLocalChange(DbConstants.plans, {
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
        'notes': 'Local plan',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    for (var index = 0; index < 3; index += 1) {
      await db.insert(
        DbConstants.installments,
        SyncMetadata.withLocalChange(DbConstants.installments, {
          'plan_id': planId,
          'sequence_number': index + 1,
          'scheduled_due_date': '2026-06-01T00:00:00.000Z',
          'current_due_date': '2026-06-01T00:00:00.000Z',
          'amount': 3000,
          'paid_amount': 0,
          'status': 'pending',
        }),
      );
    }
    return planId;
  }

  Future<Map<String, Object?>?> planRow(int planId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      DbConstants.plans,
      where: 'id = ?',
      whereArgs: [planId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> planByServerId(String serverId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      DbConstants.plans,
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> syncedInstallmentCount(int planId) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${DbConstants.installments} WHERE plan_id = ? AND ${SyncMetadata.isSync} = 1 AND ${SyncMetadata.serverId} IS NOT NULL',
      [planId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> dispose() async {
    changeNotifier.dispose();
    final db = await dbHelper.database;
    await db.close();
    await directory.delete(recursive: true);
  }
}

class _FakeInstallmentPlanRemoteDataSource
    extends InstallmentPlanRemoteDataSource {
  _FakeInstallmentPlanRemoteDataSource(SharedPreferences preferences)
    : super(_NoopApiServices(preferences));

  final created = <List<Map<String, Object?>>>[];
  final updated = <List<Map<String, Object?>>>[];
  final deleted = <List<Map<String, Object?>>>[];
  final downloadResults = <SyncDownloadResult>[];
  final downloadCalls = <Map<String, Object?>>[];

  @override
  Future<SyncUploadResult> create(List<Map<String, Object?>> plans) async {
    created.add(plans);
    return _success(plans);
  }

  @override
  Future<SyncUploadResult> update(List<Map<String, Object?>> plans) async {
    updated.add(plans);
    return _success(plans);
  }

  @override
  Future<SyncUploadResult> delete(List<Map<String, Object?>> plans) async {
    deleted.add(plans);
    return _success(plans, deleted: true);
  }

  @override
  Future<SyncDownloadResult> download({
    String? lastUpdatedAt,
    String? lastServerId,
    int limit = 10,
  }) async {
    downloadCalls.add({
      'lastUpdatedAt': lastUpdatedAt,
      'lastServerId': lastServerId,
      'limit': limit,
    });
    if (downloadResults.isEmpty) {
      return const SyncDownloadResult(
        records: [],
        serverTime: '2026-06-04T10:00:00.000Z',
        hasMore: false,
      );
    }
    return downloadResults.removeAt(0);
  }

  SyncUploadResult _success(
    List<Map<String, Object?>> plans, {
    bool deleted = false,
  }) {
    return SyncUploadResult(
      mappings: [
        for (var index = 0; index < plans.length; index += 1)
          SyncMapping(
            index: index,
            serverId:
                plans[index]['serverId']?.toString() ?? 'server-plan-$index',
          ),
      ],
      synced: [
        for (var index = 0; index < plans.length; index += 1)
          {
            'serverId':
                plans[index]['serverId']?.toString() ?? 'server-plan-$index',
            'customerId': plans[index]['customerId'],
            'mode': 'common',
            'selectedProducts': plans[index]['selectedProducts'],
            'commonDeposit': plans[index]['commonDeposit'],
            'commonInstallmentAmount': plans[index]['commonInstallmentAmount'],
            'commonFrequencyInDays': plans[index]['commonFrequencyInDays'],
            'commonFirstDueDate': plans[index]['commonFirstDueDate'],
            'totalAmount': 10000,
            'remainingAmount': 9000,
            'installmentCount': 3,
            'note': plans[index]['note'],
            'schedules': deleted
                ? const []
                : [
                    for (
                      var scheduleIndex = 0;
                      scheduleIndex < 3;
                      scheduleIndex += 1
                    )
                      {
                        'serverId': 'server-installment-$index-$scheduleIndex',
                        'sequenceNumber': scheduleIndex + 1,
                        'scheduledDueDate': '2026-06-01T00:00:00.000Z',
                        'currentDueDate': '2026-06-01T00:00:00.000Z',
                        'amount': scheduleIndex == 2 ? 3000 : 3000,
                        'paidAmount': 0,
                        'status': 'pending',
                        'isDeleted': false,
                        'updatedAt': '2026-06-04T10:00:00.000Z',
                      },
                  ],
            'isDeleted': deleted,
            'updatedAt': '2026-06-04T10:00:00.000Z',
            'createdAt': '2026-06-04T10:00:00.000Z',
          },
      ],
      failed: const [],
      conflicts: const [],
      serverTime: '2026-06-04T10:00:00.000Z',
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
