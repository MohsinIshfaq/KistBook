import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kistbook/core/services/api_services.dart';
import 'package:kistbook/data/database/db_constants.dart';
import 'package:kistbook/data/database/db_helper.dart';
import 'package:kistbook/data/database/sync_metadata.dart';
import 'package:kistbook/data/datasources/product_remote_data_source.dart';
import 'package:kistbook/data/repositories/product_sync_repository.dart';
import 'package:kistbook/data/sync/sync_batch_models.dart';
import 'package:kistbook/data/sync/sync_cursor_store.dart';
import 'package:kistbook/services/sync_change_notifier.dart';
import 'package:kistbook/services/session_manager.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test(
    'product create uploads minimum payload and stores server mapping',
    () async {
      final fixture = await _ProductSyncFixture.create();
      final productId = await fixture.insertProduct(
        name: 'Reno 13',
        salePrice: 145000,
      );

      await fixture.repository.uploadPending();

      expect(fixture.remote.created.single.single['productName'], 'Reno 13');
      expect(fixture.remote.created.single.single['salesPrice'], 145000);
      expect(
        fixture.remote.created.single.single.containsKey('categoryId'),
        isFalse,
      );
      expect(
        fixture.remote.created.single.single.containsKey('productImages'),
        isFalse,
      );

      final row = await fixture.productRow(productId);
      expect(row?[SyncMetadata.serverId], 'server-product-0');
      expect(row?[SyncMetadata.isSync], 1);
      await fixture.dispose();
    },
  );

  test(
    'product update omits images unless local image rows are dirty',
    () async {
      final fixture = await _ProductSyncFixture.create();
      await fixture.insertProduct(
        name: 'Reno 13',
        salePrice: 150000,
        serverId: 'server-product-existing',
      );

      await fixture.repository.uploadPending();

      expect(
        fixture.remote.updated.single.single['serverId'],
        'server-product-existing',
      );
      expect(
        fixture.remote.updated.single.single.containsKey('productImages'),
        isFalse,
      );
      await fixture.dispose();
    },
  );

  test(
    'product update sends replacement images when image rows are dirty',
    () async {
      final fixture = await _ProductSyncFixture.create();
      final productId = await fixture.insertProduct(
        name: 'Reno 13',
        salePrice: 150000,
        serverId: 'server-product-existing',
      );
      final imagePath = p.join(fixture.directory.path, 'product.jpg');
      await File(imagePath).writeAsBytes([1, 2, 3, 4]);
      await fixture.insertProductImage(
        productId: productId,
        imagePath: imagePath,
      );

      await fixture.repository.uploadPending();

      final images =
          fixture.remote.updated.single.single['productImages'] as List;
      expect(images, hasLength(1));
      expect(images.single['originalName'], 'product.jpg');
      expect(images.single['imageBase64'], isNotEmpty);
      await fixture.dispose();
    },
  );

  test(
    'product update sends generic variants when product row is dirty',
    () async {
      final fixture = await _ProductSyncFixture.create();
      final productId = await fixture.insertProduct(
        name: 'Reno 13',
        salePrice: 150000,
        serverId: 'server-product-existing',
      );
      await fixture.insertVariant(
        productId: productId,
        sku: 'OPPO-R13-BLK-256',
        salePrice: 155000,
        attributes: const {'Color': 'Black', 'Storage': '256GB'},
      );

      await fixture.repository.uploadPending();

      final variants = fixture.remote.updated.single.single['variants'] as List;
      expect(variants, hasLength(1));
      expect(variants.single['skuCode'], 'OPPO-R13-BLK-256');
      expect(variants.single['attributes'], hasLength(2));
      await fixture.dispose();
    },
  );

  test(
    'image-only product update omits variants to avoid authoritative delete',
    () async {
      final fixture = await _ProductSyncFixture.create();
      final productId = await fixture.insertProduct(
        name: 'Reno 13',
        salePrice: 150000,
        serverId: 'server-product-existing',
        isSynced: true,
      );
      await fixture.insertVariant(
        productId: productId,
        sku: 'OPPO-R13-BLK-256',
        salePrice: 155000,
        attributes: const {'Color': 'Black'},
      );
      final imagePath = p.join(fixture.directory.path, 'product.jpg');
      await File(imagePath).writeAsBytes([1, 2, 3, 4]);
      await fixture.insertProductImage(
        productId: productId,
        imagePath: imagePath,
      );

      await fixture.repository.uploadPending();

      expect(
        fixture.remote.updated.single.single.containsKey('productImages'),
        isTrue,
      );
      expect(
        fixture.remote.updated.single.single.containsKey('variants'),
        isFalse,
      );
      await fixture.dispose();
    },
  );

  test(
    'product download stores minimum server row and notifies listeners',
    () async {
      final fixture = await _ProductSyncFixture.create();
      final events = <SyncResource>[];
      final subscription = fixture.changeNotifier.stream.listen(events.add);
      fixture.remote.downloadResults.add(
        const SyncDownloadResult(
          records: [
            {
              'serverId': 'server-product-download',
              'productName': 'Server Product',
              'salesPrice': 25000,
              'brandName': '',
              'skuCode': '',
              'notes': '',
              'productImages': [],
              'variants': [
                {
                  'serverId': 'server-variant-download',
                  'skuCode': 'SRV-VAR-1',
                  'salePrice': 26000,
                  'attributes': [
                    {'name': 'Color', 'value': 'Black'},
                  ],
                },
              ],
              'priceHistory': [
                {
                  'serverId': 'server-price-history-1',
                  'previousPrice': null,
                  'newPrice': 25000,
                  'changedAt': '2026-06-04T09:00:00.000Z',
                },
                {
                  'serverId': 'server-price-history-2',
                  'previousPrice': 25000,
                  'newPrice': 26000,
                  'changedAt': '2026-06-04T09:10:00.000Z',
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
            lastUpdatedAt: '2026-06-04T09:10:16.000Z',
            lastServerId: 'cursor-product-download',
          ),
        ),
      );

      await fixture.repository.downloadLatest();
      await Future<void>.delayed(Duration.zero);

      final row = await fixture.productByServerId('server-product-download');
      expect(row?['name'], 'Server Product');
      expect(row?['sale_price'], 25000);
      expect(row?[SyncMetadata.isSync], 1);
      expect(await fixture.variantCount(row?['id'] as int), 1);
      expect(await fixture.priceHistoryCount(row?['id'] as int), 2);
      expect(fixture.remote.downloadCalls, hasLength(2));
      expect(
        fixture.remote.downloadCalls.first['lastUpdatedAt'],
        '2001-01-01T00:00:00.000Z',
      );
      expect(
        fixture.remote.downloadCalls.last['lastUpdatedAt'],
        '2026-06-04T09:10:16.000Z',
      );
      expect(
        fixture.remote.downloadCalls.last['lastServerId'],
        'cursor-product-download',
      );
      expect(
        (await fixture.cursorStore.read(
          SyncCursorStore.products,
        )).lastUpdatedAt,
        '2026-06-04T09:10:16.000Z',
      );
      expect(events, contains(SyncResource.products));

      await subscription.cancel();
      await fixture.dispose();
    },
  );
}

class _ProductSyncFixture {
  _ProductSyncFixture({
    required this.directory,
    required this.dbHelper,
    required this.remote,
    required this.repository,
    required this.cursorStore,
    required this.changeNotifier,
  });

  final Directory directory;
  final DbHelper dbHelper;
  final _FakeProductRemoteDataSource remote;
  final ProductSyncRepository repository;
  final SyncCursorStore cursorStore;
  final SyncChangeNotifier changeNotifier;

  static Future<_ProductSyncFixture> create() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final directory = await Directory.systemTemp.createTemp(
      'kistbook_product_sync_',
    );
    final dbHelper = DbHelper(databasePath: p.join(directory.path, 'test.db'));
    await dbHelper.initialize();
    final remote = _FakeProductRemoteDataSource(preferences);
    final cursorStore = SyncCursorStore();
    final changeNotifier = SyncChangeNotifier();
    final repository = ProductSyncRepository(
      dbHelper: dbHelper,
      remoteDataSource: remote,
      cursorStore: cursorStore,
      changeNotifier: changeNotifier,
    );
    return _ProductSyncFixture(
      directory: directory,
      dbHelper: dbHelper,
      remote: remote,
      repository: repository,
      cursorStore: cursorStore,
      changeNotifier: changeNotifier,
    );
  }

  Future<int> insertProduct({
    required String name,
    required double salePrice,
    String? serverId,
    bool isSynced = false,
  }) async {
    final db = await dbHelper.database;
    final values = <String, Object?>{
      'categories_text': '[]',
      'brand_name': '',
      'name': name,
      'sku': '',
      'sale_price': salePrice,
      'notes': '',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (serverId != null) {
      values[SyncMetadata.serverId] = serverId;
    }
    return db.insert(
      DbConstants.products,
      isSynced
          ? SyncMetadata.withServerChange(DbConstants.products, values)
          : SyncMetadata.withLocalChange(DbConstants.products, values),
    );
  }

  Future<void> insertVariant({
    required int productId,
    required String sku,
    required double salePrice,
    required Map<String, String> attributes,
  }) async {
    final db = await dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final variantId = await db.insert(DbConstants.productVariants, {
      'product_id': productId,
      'sku': sku,
      'sale_price': salePrice,
      'is_deleted': 0,
      'created_at': now,
      'updated_at': now,
    });
    for (final entry in attributes.entries) {
      await db.insert(DbConstants.productVariantAttributes, {
        'variant_id': variantId,
        'name': entry.key,
        'value': entry.value,
        'is_deleted': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }

  Future<void> insertProductImage({
    required int productId,
    required String imagePath,
  }) async {
    final db = await dbHelper.database;
    await db.insert(
      DbConstants.productImages,
      SyncMetadata.withLocalChange(DbConstants.productImages, {
        'product_id': productId,
        'image_path': imagePath,
        'sort_order': 0,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<Map<String, Object?>?> productRow(int productId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      DbConstants.products,
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> productByServerId(String serverId) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      DbConstants.products,
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> variantCount(int productId) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${DbConstants.productVariants} WHERE product_id = ? AND is_deleted = 0',
      [productId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<int> priceHistoryCount(int productId) async {
    final db = await dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM ${DbConstants.productPriceHistory} WHERE product_id = ?',
      [productId],
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

class _FakeProductRemoteDataSource extends ProductRemoteDataSource {
  _FakeProductRemoteDataSource(SharedPreferences preferences)
    : super(_NoopApiServices(preferences));

  final created = <List<Map<String, Object?>>>[];
  final updated = <List<Map<String, Object?>>>[];
  final downloadResults = <SyncDownloadResult>[];
  final downloadCalls = <Map<String, Object?>>[];

  @override
  Future<SyncUploadResult> create(List<Map<String, Object?>> products) async {
    created.add(products);
    return _success(products);
  }

  @override
  Future<SyncUploadResult> update(List<Map<String, Object?>> products) async {
    updated.add(products);
    return _success(products);
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

  SyncUploadResult _success(List<Map<String, Object?>> products) {
    return SyncUploadResult(
      mappings: [
        for (var index = 0; index < products.length; index += 1)
          SyncMapping(
            index: index,
            serverId:
                products[index]['serverId']?.toString() ??
                'server-product-$index',
          ),
      ],
      synced: [
        for (var index = 0; index < products.length; index += 1)
          {
            'serverId':
                products[index]['serverId']?.toString() ??
                'server-product-$index',
            'salesPrice': products[index]['salesPrice'],
            'updatedAt': '2026-06-04T10:00:00.000Z',
            'isDeleted': false,
            'productImages': const [],
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
