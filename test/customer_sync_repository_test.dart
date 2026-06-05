import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kistbook/core/services/api_services.dart';
import 'package:kistbook/data/database/db_constants.dart';
import 'package:kistbook/data/database/db_helper.dart';
import 'package:kistbook/data/database/sync_metadata.dart';
import 'package:kistbook/data/datasources/customer_remote_data_source.dart';
import 'package:kistbook/data/repositories/customer_sync_repository.dart';
import 'package:kistbook/data/sync/sync_batch_models.dart';
import 'package:kistbook/data/sync/sync_cursor_store.dart';
import 'package:kistbook/services/sync_change_notifier.dart';
import 'package:kistbook/services/session_manager.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'customer pending rows are split into create update and delete APIs',
    () async {
      final fixture = await _CustomerSyncFixture.create();
      final createId = await fixture.insertCustomer(name: 'New Customer');
      final updateId = await fixture.insertCustomer(
        name: 'Existing Customer',
        serverId: 'server-customer-existing',
      );
      final deleteId = await fixture.insertCustomer(
        name: 'Deleted Customer',
        serverId: 'server-customer-delete',
        isDeleted: true,
      );

      await fixture.repository.uploadPending();

      expect(
        fixture.remote.created.single.single['customerName'],
        'New Customer',
      );
      expect(
        fixture.remote.updated.single.single['serverId'],
        'server-customer-existing',
      );
      expect(
        fixture.remote.deleted.single.single['serverId'],
        'server-customer-delete',
      );
      expect((await fixture.customerRow(createId))?[SyncMetadata.isSync], 1);
      expect((await fixture.customerRow(updateId))?[SyncMetadata.isSync], 1);
      expect((await fixture.customerRow(deleteId))?[SyncMetadata.isSync], 1);
      await fixture.dispose();
    },
  );

  test('customer download stores server rows and notifies listeners', () async {
    final fixture = await _CustomerSyncFixture.create();
    final events = <SyncResource>[];
    final subscription = fixture.changeNotifier.stream.listen(events.add);
    fixture.remote.downloadResults.add(
      const SyncDownloadResult(
        records: [
          {
            'serverId': 'server-customer-download',
            'cardNumber': 'CARD-1',
            'customerName': 'Server Customer',
            'phoneNumber': '03009998888',
            'cnic': '42101-0000000-1',
            'address': 'Lahore',
            'reference': 'Server',
            'isDeleted': false,
            'createdAt': '2026-06-04T09:00:00.000Z',
            'updatedAt': '2026-06-04T09:05:00.000Z',
          },
        ],
        serverTime: '2026-06-04T09:06:00.000Z',
        hasMore: false,
      ),
    );

    await fixture.repository.downloadLatest();
    await Future<void>.delayed(Duration.zero);

    final row = await fixture.customerByServerId('server-customer-download');
    expect(row?['name'], 'Server Customer');
    expect(row?[SyncMetadata.isSync], 1);
    expect(fixture.remote.downloadCalls, hasLength(2));
    expect(
      fixture.remote.downloadCalls.first['lastUpdatedAt'],
      '2001-01-01T00:00:00.000Z',
    );
    expect(
      fixture.remote.downloadCalls.last['lastUpdatedAt'],
      '2026-06-04T09:05:00.000Z',
    );
    expect(
      fixture.remote.downloadCalls.last['lastServerId'],
      'server-customer-download',
    );
    expect(
      (await fixture.cursorStore.read(SyncCursorStore.customers)).lastUpdatedAt,
      '2026-06-04T09:05:00.000Z',
    );
    expect(events, contains(SyncResource.customers));

    await subscription.cancel();
    await fixture.dispose();
  });

  test('empty customer download keeps existing cursor unchanged', () async {
    final fixture = await _CustomerSyncFixture.create();
    fixture.remote.downloadResults.add(
      const SyncDownloadResult(
        records: [],
        serverTime: '2026-06-04T10:00:00.000Z',
        hasMore: false,
      ),
    );

    await fixture.repository.downloadLatest();

    expect(
      (await fixture.cursorStore.read(SyncCursorStore.customers)).lastUpdatedAt,
      isNull,
    );
    await fixture.dispose();
  });
}

class _CustomerSyncFixture {
  _CustomerSyncFixture({
    required this.directory,
    required this.dbHelper,
    required this.remote,
    required this.repository,
    required this.cursorStore,
    required this.changeNotifier,
  });

  final Directory directory;
  final DbHelper dbHelper;
  final _FakeCustomerRemoteDataSource remote;
  final CustomerSyncRepository repository;
  final SyncCursorStore cursorStore;
  final SyncChangeNotifier changeNotifier;

  static Future<_CustomerSyncFixture> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = await Directory.systemTemp.createTemp(
      'kistbook_customer_sync_',
    );
    final dbHelper = DbHelper(databasePath: p.join(directory.path, 'test.db'));
    await dbHelper.initialize();
    final remote = _FakeCustomerRemoteDataSource(preferences);
    final cursorStore = SyncCursorStore();
    final changeNotifier = SyncChangeNotifier();
    final repository = CustomerSyncRepository(
      dbHelper: dbHelper,
      remoteDataSource: remote,
      cursorStore: cursorStore,
      changeNotifier: changeNotifier,
    );
    return _CustomerSyncFixture(
      directory: directory,
      dbHelper: dbHelper,
      remote: remote,
      repository: repository,
      cursorStore: cursorStore,
      changeNotifier: changeNotifier,
    );
  }

  Future<int> insertCustomer({
    required String name,
    String? serverId,
    bool isDeleted = false,
  }) async {
    final db = await dbHelper.database;
    final values = <String, Object?>{
      'card_number': '',
      'name': name,
      'phone': '03001234567',
      'cnic': 'cnic-$name',
      'address': 'Lahore',
      'reference_name': '',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (serverId != null) {
      values[SyncMetadata.serverId] = serverId;
    }
    if (isDeleted) {
      values[SyncMetadata.isDeleted] = 1;
    }
    return db.insert(
      DbConstants.customers,
      SyncMetadata.withLocalChange(DbConstants.customers, values),
    );
  }

  Future<Map<String, Object?>?> customerRow(int customerId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      DbConstants.customers,
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> customerByServerId(String serverId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      DbConstants.customers,
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

class _FakeCustomerRemoteDataSource extends CustomerRemoteDataSource {
  _FakeCustomerRemoteDataSource(SharedPreferences preferences)
    : super(_NoopApiServices(preferences));

  final created = <List<Map<String, Object?>>>[];
  final updated = <List<Map<String, Object?>>>[];
  final deleted = <List<Map<String, Object?>>>[];
  final downloadResults = <SyncDownloadResult>[];
  final downloadCalls = <Map<String, Object?>>[];

  @override
  Future<SyncUploadResult> create(List<Map<String, Object?>> customers) async {
    created.add(customers);
    return _success(customers);
  }

  @override
  Future<SyncUploadResult> update(List<Map<String, Object?>> customers) async {
    updated.add(customers);
    return _success(customers);
  }

  @override
  Future<SyncUploadResult> delete(List<Map<String, Object?>> customers) async {
    deleted.add(customers);
    return _success(customers);
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

  SyncUploadResult _success(List<Map<String, Object?>> customers) {
    return SyncUploadResult(
      mappings: [
        for (var index = 0; index < customers.length; index += 1)
          SyncMapping(
            index: index,
            serverId:
                customers[index]['serverId']?.toString() ??
                'server-customer-$index',
          ),
      ],
      synced: [
        for (var index = 0; index < customers.length; index += 1)
          {
            'serverId':
                customers[index]['serverId']?.toString() ??
                'server-customer-$index',
            'updatedAt': '2026-06-04T10:00:00.000Z',
            'isDeleted': false,
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
