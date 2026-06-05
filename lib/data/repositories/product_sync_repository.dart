import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../services/product_image_storage.dart';
import '../../services/sync_change_notifier.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../database/sync_metadata.dart';
import '../datasources/product_remote_data_source.dart';
import '../models/product_model.dart';
import '../sync/sync_batch_models.dart';
import '../sync/sync_cursor_store.dart';

class ProductSyncRepository {
  ProductSyncRepository({
    required DbHelper dbHelper,
    required ProductRemoteDataSource remoteDataSource,
    required SyncCursorStore cursorStore,
    SyncChangeNotifier? changeNotifier,
  }) : _dbHelper = dbHelper,
       _remoteDataSource = remoteDataSource,
       _cursorStore = cursorStore,
       _changeNotifier = changeNotifier;

  static const _batchSize = 10;
  static const _initialLastUpdatedAt = '2001-01-01T00:00:00.000Z';

  final DbHelper _dbHelper;
  final ProductRemoteDataSource _remoteDataSource;
  final SyncCursorStore _cursorStore;
  final SyncChangeNotifier? _changeNotifier;

  Future<void> uploadPending() async {
    final database = await _dbHelper.database;
    final rows = await database.query(
      DbConstants.products,
      where: '${SyncMetadata.isSync} = 0',
      orderBy: 'id ASC',
    );
    final dirtyImageProductIds = await _dirtyImageProductIds(database);

    final createRows = <Map<String, Object?>>[];
    final updateRows = <Map<String, Object?>>[];
    final deleteRows = <Map<String, Object?>>[];
    final neverSyncedDeletes = <int>[];
    final queuedIds = <int>{};

    for (final row in rows) {
      final id = _int(row['id']);
      final serverId = _string(row[SyncMetadata.serverId]);
      final isDeleted = _bool(row[SyncMetadata.isDeleted]);
      if (id == null) {
        continue;
      }
      queuedIds.add(id);
      if (serverId == null && isDeleted) {
        neverSyncedDeletes.add(id);
      } else if (serverId == null) {
        createRows.add(row);
      } else if (isDeleted) {
        deleteRows.add(row);
      } else {
        updateRows.add(row);
      }
    }

    for (final productId in dirtyImageProductIds.difference(queuedIds)) {
      final row = await _productRow(database, productId);
      if (row != null && !_bool(row[SyncMetadata.isDeleted])) {
        updateRows.add(row);
      }
    }

    await _hardDeleteNeverSynced(database, neverSyncedDeletes);
    await _uploadCreates(database, createRows);
    await _uploadUpdates(database, updateRows, queuedIds);
    await _uploadDeletes(deleteRows);
  }

  Future<void> downloadLatest() async {
    var cursor = await _cursorStore.read(SyncCursorStore.products);
    while (true) {
      final result = await _remoteDataSource.download(
        lastUpdatedAt: cursor.lastUpdatedAt ?? _initialLastUpdatedAt,
        lastServerId: cursor.lastServerId,
        limit: _batchSize,
      );

      if (result.records.isEmpty) {
        return;
      }

      for (final record in result.records) {
        await applyDownloadedRecord(record);
      }
      _changeNotifier?.notify(SyncResource.products);

      final lastRecord = result.records.last;
      cursor = _nextCursor(result, lastRecord);
      if (_string(cursor.lastUpdatedAt) == null) {
        return;
      }
      await _cursorStore.save(SyncCursorStore.products, cursor);
    }
  }

  SyncCursor _nextCursor(
    SyncDownloadResult result,
    Map<String, dynamic> lastRecord,
  ) {
    final serverCursor = result.nextCursor;
    return SyncCursor(
      lastUpdatedAt:
          _string(serverCursor?.lastUpdatedAt) ??
          _string(lastRecord['updatedAt']),
      lastServerId:
          _string(serverCursor?.lastServerId) ??
          _string(lastRecord['serverId']),
    );
  }

  Future<void> _uploadCreates(
    Database database,
    List<Map<String, Object?>> rows,
  ) async {
    for (final chunk in _chunks(rows)) {
      final payload = <Map<String, Object?>>[];
      for (final row in chunk) {
        payload.add(
          await _productPayload(
            database,
            row,
            includeImages: true,
            includeVariants: true,
          ),
        );
      }
      final result = await _remoteDataSource.create(payload);
      await _applyUploadResult(chunk, result);
    }
  }

  Future<void> _uploadUpdates(
    Database database,
    List<Map<String, Object?>> rows,
    Set<int> dirtyProductIds,
  ) async {
    for (final chunk in _chunks(rows)) {
      final payload = <Map<String, Object?>>[];
      for (final row in chunk) {
        final productId = _int(row['id']);
        payload.add(
          await _productPayload(
            database,
            row,
            includeImages:
                productId != null && await _hasDirtyImages(database, productId),
            includeVariants:
                productId != null && dirtyProductIds.contains(productId),
          ),
        );
      }
      final result = await _remoteDataSource.update(payload);
      await _applyUploadResult(chunk, result);
    }
  }

  Future<void> _uploadDeletes(List<Map<String, Object?>> rows) async {
    for (final chunk in _chunks(rows)) {
      final result = await _remoteDataSource.delete(
        chunk
            .map(
              (row) => <String, Object?>{
                'serverId': _string(row[SyncMetadata.serverId]),
                'updatedAt':
                    _string(row[SyncMetadata.dateUpdated]) ??
                    _string(row['updated_at']),
              },
            )
            .toList(),
      );
      await _applyUploadResult(chunk, result);
    }
  }

  Future<Map<String, Object?>> _productPayload(
    Database database,
    Map<String, Object?> row, {
    required bool includeImages,
    required bool includeVariants,
  }) async {
    final productId = _int(row['id']);
    final payload = <String, Object?>{
      if (_string(row[SyncMetadata.serverId]) != null)
        'serverId': _string(row[SyncMetadata.serverId]),
      'updatedAt':
          _string(row[SyncMetadata.dateUpdated]) ?? _string(row['updated_at']),
      'productName': _string(row['name']) ?? '',
      'salesPrice': _num(row['sale_price']),
      if (_string(row['brand_name']) != null)
        'brandName': _string(row['brand_name']),
      if (_string(row['sku']) != null) 'skuCode': _string(row['sku']),
      if (_string(row['notes']) != null) 'notes': _string(row['notes']),
    };

    if (includeImages && productId != null) {
      final images = await _imagePayloads(database, productId);
      if (images.isNotEmpty || await _hasDirtyImages(database, productId)) {
        payload['productImages'] = images;
      }
    }
    if (includeVariants && productId != null) {
      payload['variants'] = await _variantPayloads(database, productId);
    }

    return payload;
  }

  Future<List<Map<String, Object?>>> _variantPayloads(
    Database database,
    int productId,
  ) async {
    final rows = await database.query(
      DbConstants.productVariants,
      where: 'product_id = ? AND is_deleted = 0',
      whereArgs: [productId],
      orderBy: 'id ASC',
    );
    final variants = <Map<String, Object?>>[];
    for (final row in rows) {
      final variantId = _int(row['id']);
      if (variantId == null) {
        continue;
      }
      final attributes = await database.query(
        DbConstants.productVariantAttributes,
        where: 'variant_id = ? AND is_deleted = 0',
        whereArgs: [variantId],
        orderBy: 'id ASC',
      );
      variants.add({
        if (_string(row[SyncMetadata.serverId]) != null)
          'serverId': _string(row[SyncMetadata.serverId]),
        'skuCode': _string(row['sku']) ?? '',
        'salePrice': _num(row['sale_price']),
        'attributes': attributes
            .map(
              (attribute) => {
                'name': _string(attribute['name']) ?? '',
                'value': _string(attribute['value']) ?? '',
              },
            )
            .toList(),
      });
    }
    return variants;
  }

  Future<List<Map<String, Object?>>> _imagePayloads(
    Database database,
    int productId,
  ) async {
    final rows = await database.query(
      DbConstants.productImages,
      where: 'product_id = ? AND is_deleted = 0',
      whereArgs: [productId],
      orderBy: 'sort_order ASC, id ASC',
    );
    final images = <Map<String, Object?>>[];
    for (final row in rows) {
      final path = _string(row['image_path']);
      if (path == null) {
        continue;
      }
      final file = File(path);
      if (!await file.exists()) {
        continue;
      }
      images.add({
        'imageBase64': base64Encode(await file.readAsBytes()),
        'originalName': p.basename(path),
        'mimeType': _mimeType(path),
      });
    }
    return images;
  }

  Future<void> _applyUploadResult(
    List<Map<String, Object?>> rows,
    SyncUploadResult result,
  ) async {
    if (result.mappings.isEmpty) {
      return;
    }

    final syncedByServerId = {
      for (final record in result.synced)
        if (_string(record['serverId']) != null)
          _string(record['serverId'])!: record,
    };
    final database = await _dbHelper.database;
    await database.transaction((txn) async {
      for (final mapping in result.mappings) {
        if (mapping.index < 0 || mapping.index >= rows.length) {
          continue;
        }
        final row = rows[mapping.index];
        final localId = _int(row['id']);
        if (localId == null || mapping.serverId.isEmpty) {
          continue;
        }
        final synced = syncedByServerId[mapping.serverId];
        await txn.update(
          DbConstants.products,
          SyncMetadata.withServerChange(DbConstants.products, {
            SyncMetadata.serverId: mapping.serverId,
            SyncMetadata.dateUpdated:
                _string(synced?['updatedAt']) ?? result.serverTime,
            SyncMetadata.isDeleted: _bool(synced?['isDeleted']) ? 1 : 0,
          }),
          where: 'id = ?',
          whereArgs: [localId],
        );

        await _markImagesSynced(
          txn,
          localId,
          (synced?['productImages'] as List?) ?? const [],
        );
      }
    });
  }

  Future<void> _markImagesSynced(
    Transaction txn,
    int productId,
    List<dynamic> serverImages,
  ) async {
    final activeRows = await txn.query(
      DbConstants.productImages,
      where: 'product_id = ? AND is_deleted = 0',
      whereArgs: [productId],
      orderBy: 'sort_order ASC, id ASC',
    );

    for (var index = 0; index < activeRows.length; index += 1) {
      final serverImage =
          index < serverImages.length && serverImages[index] is Map
          ? Map<String, dynamic>.from(serverImages[index] as Map)
          : const <String, dynamic>{};
      await txn.update(
        DbConstants.productImages,
        SyncMetadata.withServerChange(DbConstants.productImages, {
          if (_string(serverImage['serverId']) != null)
            SyncMetadata.serverId: _string(serverImage['serverId']),
          'remote_url': _string(serverImage['url']),
          'original_name': _string(serverImage['originalName']),
          'mime_type': _string(serverImage['mimeType']),
          'image_size': _int(serverImage['size']),
        }),
        where: 'id = ?',
        whereArgs: [activeRows[index]['id']],
      );
    }

    await txn.update(
      DbConstants.productImages,
      SyncMetadata.withServerChange(DbConstants.productImages, {
        SyncMetadata.isDeleted: 1,
      }),
      where: 'product_id = ? AND is_deleted = 1',
      whereArgs: [productId],
    );
  }

  Future<void> applyDownloadedRecords(List<Map<String, dynamic>> records) async {
    for (final record in records) {
      await applyDownloadedRecord(record);
    }
  }

  Future<void> applyDownloadedRecord(Map<String, dynamic> record) async {
    final serverId = _string(record['serverId']);
    if (serverId == null) {
      return;
    }

    final database = await _dbHelper.database;
    final existing = await _findExisting(database, serverId, record);
    if (existing != null && !_bool(existing[SyncMetadata.isSync])) {
      return;
    }

    final serverImages = record['productImages'];
    final downloadedImages = await _downloadImages(record);
    final shouldReplaceImages =
        serverImages is List &&
        (serverImages.isEmpty || downloadedImages.isNotEmpty);
    final removedImagePaths = <String>[];
    try {
      await database.transaction((txn) async {
        final productId = await _upsertDownloadedProduct(
          txn,
          record,
          existing,
          serverId,
        );
        if (shouldReplaceImages) {
          removedImagePaths.addAll(
            await _replaceDownloadedImages(txn, productId, downloadedImages),
          );
        }
        await _replaceDownloadedVariants(txn, productId, record);
        await _replaceDownloadedPriceHistory(txn, productId, record);
      });
    } catch (_) {
      for (final image in downloadedImages) {
        await ProductImageStorage.deleteImage(image.localPath);
      }
      rethrow;
    }

    for (final imagePath in removedImagePaths) {
      await ProductImageStorage.deleteImage(imagePath);
    }
  }

  Future<int> _upsertDownloadedProduct(
    Transaction txn,
    Map<String, dynamic> record,
    Map<String, Object?>? existing,
    String serverId,
  ) async {
    final existingCategories = _string(existing?['categories_text']);
    final values = SyncMetadata.withServerChange(DbConstants.products, {
      SyncMetadata.serverId: serverId,
      SyncMetadata.dateUpdated:
          _string(record['updatedAt']) ??
          DateTime.now().toUtc().toIso8601String(),
      SyncMetadata.isDeleted: _bool(record['isDeleted']) ? 1 : 0,
      'categories_text':
          existingCategories ??
          jsonEncode(const [ProductModel.defaultCategory]),
      'brand_name': _string(record['brandName']) ?? '',
      'name': _string(record['productName']) ?? '',
      'sku': _string(record['skuCode']) ?? '',
      'sale_price': _num(record['salesPrice']),
      'notes': _string(record['notes']) ?? '',
    })..remove('id');

    if (existing == null) {
      return txn.insert(DbConstants.products, values);
    }

    final productId = _int(existing['id']);
    if (productId == null) {
      return txn.insert(DbConstants.products, values);
    }
    await txn.update(
      DbConstants.products,
      values,
      where: 'id = ?',
      whereArgs: [productId],
    );
    return productId;
  }

  Future<List<_DownloadedProductImage>> _downloadImages(
    Map<String, dynamic> record,
  ) async {
    final images = record['productImages'];
    if (images is! List) {
      return const [];
    }

    final downloaded = <_DownloadedProductImage>[];
    for (final image in images.whereType<Map>()) {
      final data = Map<String, dynamic>.from(image);
      final url = _string(data['url']);
      if (url == null) {
        continue;
      }
      try {
        final bytes = await _remoteDataSource.downloadImage(url);
        final localPath = await ProductImageStorage.saveBytes(
          bytes: bytes,
          sourceName: _string(data['originalName']) ?? url,
        );
        downloaded.add(
          _DownloadedProductImage(
            localPath: localPath,
            serverId: _string(data['serverId']),
            remoteUrl: url,
            originalName: _string(data['originalName']),
            mimeType: _string(data['mimeType']),
            size: _int(data['size']) ?? bytes.length,
          ),
        );
      } catch (_) {
        // Keep the product data syncable even if one image cannot be fetched.
      }
    }
    return downloaded;
  }

  Future<List<String>> _replaceDownloadedImages(
    Transaction txn,
    int productId,
    List<_DownloadedProductImage> images,
  ) async {
    final existingImages = await txn.query(
      DbConstants.productImages,
      where: 'product_id = ? AND is_deleted = 0',
      whereArgs: [productId],
    );
    final removedPaths = existingImages
        .map((row) => _string(row['image_path']))
        .whereType<String>()
        .toList();

    await txn.update(
      DbConstants.productImages,
      SyncMetadata.withServerChange(DbConstants.productImages, {
        SyncMetadata.isDeleted: 1,
      }),
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    for (var index = 0; index < images.length; index += 1) {
      final image = images[index];
      await txn.insert(
        DbConstants.productImages,
        SyncMetadata.withServerChange(DbConstants.productImages, {
          'product_id': productId,
          SyncMetadata.serverId: image.serverId,
          'image_path': image.localPath,
          'remote_url': image.remoteUrl,
          'original_name': image.originalName,
          'mime_type': image.mimeType,
          'image_size': image.size,
          'sort_order': index,
        }),
      );
    }

    return removedPaths;
  }

  Future<void> _replaceDownloadedVariants(
    Transaction txn,
    int productId,
    Map<String, dynamic> record,
  ) async {
    final existingVariants = await txn.query(
      DbConstants.productVariants,
      columns: ['id'],
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    final variantIds = existingVariants.map((row) => row['id']).toList();
    if (variantIds.isNotEmpty) {
      final placeholders = List.filled(variantIds.length, '?').join(',');
      await txn.delete(
        DbConstants.productVariantAttributes,
        where: 'variant_id IN ($placeholders)',
        whereArgs: variantIds,
      );
    }
    await txn.delete(
      DbConstants.productVariants,
      where: 'product_id = ?',
      whereArgs: [productId],
    );

    final variants = record['variants'];
    if (variants is! List) {
      return;
    }
    final now = DateTime.now().toUtc().toIso8601String();
    for (final item in variants.whereType<Map>()) {
      final variant = Map<String, dynamic>.from(item);
      final variantId = await txn.insert(DbConstants.productVariants, {
        'product_id': productId,
        'server_id': _string(variant['serverId']),
        'sku': _string(variant['skuCode']) ?? '',
        'sale_price': _num(variant['salePrice']),
        'is_deleted': _bool(variant['isDeleted']) ? 1 : 0,
        'created_at': _string(variant['createdAt']) ?? now,
        'updated_at': _string(variant['updatedAt']) ?? now,
      });

      final attributes = variant['attributes'];
      if (attributes is! List) {
        continue;
      }
      for (final attribute in attributes.whereType<Map>()) {
        await txn.insert(DbConstants.productVariantAttributes, {
          'variant_id': variantId,
          'name': _string(attribute['name']) ?? '',
          'value': _string(attribute['value']) ?? '',
          'is_deleted': 0,
          'created_at': now,
          'updated_at': now,
        });
      }
    }
  }

  Future<void> _replaceDownloadedPriceHistory(
    Transaction txn,
    int productId,
    Map<String, dynamic> record,
  ) async {
    final rows = record['priceHistory'];
    if (rows is! List) {
      return;
    }
    await txn.delete(
      DbConstants.productPriceHistory,
      where: 'product_id = ?',
      whereArgs: [productId],
    );
    for (final item in rows.whereType<Map>()) {
      final history = Map<String, dynamic>.from(item);
      final changedAt =
          _string(history['changedAt']) ??
          DateTime.now().toUtc().toIso8601String();
      await txn.insert(DbConstants.productPriceHistory, {
        'product_id': productId,
        'previous_price': _nullableNum(history['previousPrice']),
        'new_price': _num(history['newPrice']),
        'changed_at': changedAt,
      });
    }
  }

  Future<Set<int>> _dirtyImageProductIds(Database database) async {
    final rows = await database.query(
      DbConstants.productImages,
      columns: ['product_id'],
      where: '${SyncMetadata.isSync} = 0',
    );
    return rows.map((row) => _int(row['product_id'])).whereType<int>().toSet();
  }

  Future<bool> _hasDirtyImages(Database database, int productId) async {
    final rows = await database.query(
      DbConstants.productImages,
      columns: ['id'],
      where: 'product_id = ? AND ${SyncMetadata.isSync} = 0',
      whereArgs: [productId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Map<String, Object?>?> _productRow(
    Database database,
    int productId,
  ) async {
    final rows = await database.query(
      DbConstants.products,
      where: 'id = ?',
      whereArgs: [productId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> _findExisting(
    DatabaseExecutor executor,
    String serverId,
    Map<String, dynamic> record,
  ) async {
    final byServerId = await executor.query(
      DbConstants.products,
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (byServerId.isNotEmpty) {
      return byServerId.first;
    }

    final sku = _string(record['skuCode']);
    if (sku == null) {
      return null;
    }
    final bySku = await executor.query(
      DbConstants.products,
      where: 'sku = ?',
      whereArgs: [sku],
      limit: 1,
    );
    return bySku.isEmpty ? null : bySku.first;
  }

  Future<void> _hardDeleteNeverSynced(
    Database database,
    List<int> localIds,
  ) async {
    if (localIds.isEmpty) {
      return;
    }
    final placeholders = List.filled(localIds.length, '?').join(',');
    await database.delete(
      DbConstants.productImages,
      where: 'product_id IN ($placeholders)',
      whereArgs: localIds,
    );
    await database.delete(
      DbConstants.products,
      where: 'id IN ($placeholders)',
      whereArgs: localIds,
    );
  }

  Iterable<List<Map<String, Object?>>> _chunks(
    List<Map<String, Object?>> rows,
  ) sync* {
    for (var index = 0; index < rows.length; index += _batchSize) {
      yield rows.sublist(
        index,
        index + _batchSize > rows.length ? rows.length : index + _batchSize,
      );
    }
  }

  String _mimeType(String path) {
    final extension = p.extension(path).toLowerCase();
    return switch (extension) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      _ => 'image/jpeg',
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

  double _num(Object? value) {
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _nullableNum(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is double) {
      return value;
    }
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse(value.toString());
  }

  bool _bool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value.toInt() != 0;
    }
    return value?.toString().toLowerCase() == 'true';
  }
}

class _DownloadedProductImage {
  const _DownloadedProductImage({
    required this.localPath,
    this.serverId,
    this.remoteUrl,
    this.originalName,
    this.mimeType,
    this.size,
  });

  final String localPath;
  final String? serverId;
  final String? remoteUrl;
  final String? originalName;
  final String? mimeType;
  final int? size;
}
