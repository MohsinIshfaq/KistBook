import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/constants/api_urls.dart';
import '../core/constants/app_enums.dart';
import '../data/database/db_constants.dart';
import '../data/database/db_helper.dart';
import '../data/database/sync_metadata.dart';
import 'product_image_storage.dart';
import 'session_manager.dart';

class SyncService {
  SyncService({
    required DbHelper dbHelper,
    required SessionManager sessionManager,
    http.Client? httpClient,
  }) : _dbHelper = dbHelper,
       _sessionManager = sessionManager,
       _httpClient = httpClient ?? http.Client();

  static const _uploadOrder = <String>[
    DbConstants.users,
    DbConstants.customers,
    DbConstants.products,
    DbConstants.productImages,
    DbConstants.plans,
    DbConstants.installments,
    DbConstants.payments,
    DbConstants.customerUserAccess,
    DbConstants.planUserAccess,
  ];

  final DbHelper _dbHelper;
  final SessionManager _sessionManager;
  final http.Client _httpClient;
  bool _isRunning = false;

  Future<bool> syncNow({bool silent = true}) async {
    if (_isRunning || _sessionManager.apiToken.isEmpty) {
      return false;
    }

    _isRunning = true;
    try {
      await _uploadPendingChanges();
      await _downloadServerChanges();
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Sync failed',
        name: 'KistBook.SyncService',
        error: error,
        stackTrace: stackTrace,
      );
      if (!silent) {
        rethrow;
      }
      return false;
    } finally {
      _isRunning = false;
    }
  }

  Future<void> _uploadPendingChanges() async {
    for (final tableName in _uploadOrder) {
      final database = await _dbHelper.database;
      final dirtyRows = await database.query(
        tableName,
        where: '${SyncMetadata.isSync} = 0',
        orderBy: 'id ASC',
      );
      if (dirtyRows.isEmpty) {
        continue;
      }

      final payload = <Map<String, Object?>>[];
      for (final row in dirtyRows) {
        final mapped = await _mapLocalRowForUpload(database, tableName, row);
        if (mapped != null) {
          payload.add(mapped);
        }
      }
      if (payload.isEmpty) {
        continue;
      }

      final responseData = await _postJson(API.URL_SYNC_UPLOAD, {
        'changes': {tableName: payload},
      });
      await _applyUploadMappings(
        tableName,
        responseData['mappings'] as Map<String, dynamic>? ?? const {},
      );
    }
  }

  Future<void> _downloadServerChanges() async {
    final lastSyncDate = _sessionManager.lastSyncDate;
    final responseData = await _getJson(API.URL_SYNC_DOWNLOAD, {
      if (lastSyncDate.isNotEmpty) 'last_sync_date': lastSyncDate,
    });
    final changes = responseData['changes'];
    if (changes is Map) {
      final database = await _dbHelper.database;
      for (final tableName in _uploadOrder) {
        final rows = changes[tableName];
        if (rows is! List) {
          continue;
        }
        for (final row in rows.whereType<Map>()) {
          await _applyDownloadedRecord(
            database,
            tableName,
            row.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
    }

    final serverTime = responseData['server_time']?.toString() ?? '';
    if (serverTime.isNotEmpty) {
      await _sessionManager.saveLastSyncDate(serverTime);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final response = await _httpClient
        .post(_apiUri(path), headers: _headers, body: jsonEncode(body))
        .timeout(const Duration(seconds: 30));
    return _decodeApiResponse(response);
  }

  Future<Map<String, dynamic>> _getJson(
    String path,
    Map<String, String> query,
  ) async {
    final response = await _httpClient
        .get(_apiUri(path, query), headers: _headers)
        .timeout(const Duration(seconds: 30));
    return _decodeApiResponse(response);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${_sessionManager.apiToken}',
  };

  Uri _apiUri(String url, [Map<String, String>? query]) {
    return Uri.parse(
      API.rebaseUrl(url: url, baseURL: _sessionManager.apiBaseUrl),
    ).replace(queryParameters: query == null || query.isEmpty ? null : query);
  }

  Map<String, dynamic> _decodeApiResponse(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(decoded['message']?.toString() ?? 'Sync API failed.');
    }
    final data = decoded['data'];
    if (data is Map<String, dynamic>) {
      return data;
    }
    return decoded;
  }

  Future<Map<String, Object?>?> _mapLocalRowForUpload(
    Database database,
    String tableName,
    Map<String, Object?> row,
  ) async {
    final payload = <String, Object?>{
      'local_id': row['id'],
      'server_id': _string(row, SyncMetadata.serverId),
      'is_deleted': _boolAsInt(row, SyncMetadata.isDeleted) == 1,
      'date_updated':
          _string(row, SyncMetadata.dateUpdated) ??
          _string(row, 'updated_at') ??
          DateTime.now().toUtc().toIso8601String(),
    };

    switch (tableName) {
      case DbConstants.users:
        payload.addAll({
          'uuid': _string(row, 'uuid'),
          'phone': _string(row, 'phone'),
          'email': _string(row, 'email'),
          'password': _string(row, 'password'),
          'first_name': _string(row, 'first_name'),
          'last_name': _string(row, 'last_name'),
          'access_level': _backendRole(_string(row, 'role')),
          'is_active': _boolAsInt(row, 'is_active') == 1,
        });
      case DbConstants.customers:
        payload.addAll({
          'card_no': _string(row, 'card_number'),
          'name': _string(row, 'name'),
          'phone': _string(row, 'phone'),
          'cnic': _string(row, 'cnic'),
          'address': _string(row, 'address'),
          'reference': _string(row, 'reference_name'),
        });
      case DbConstants.products:
        payload.addAll({
          'brand_name': _string(row, 'brand_name'),
          'product_name': _string(row, 'name'),
          'code': _string(row, 'sku'),
          'sales_price': row['sale_price'],
          'notes': _string(row, 'notes'),
          'categories': _decodeStringList(_string(row, 'categories_text')),
        });
      case DbConstants.productImages:
        final productUuid = await _serverIdForLocalId(
          database,
          DbConstants.products,
          row['product_id'],
        );
        if (productUuid == null &&
            _boolAsInt(row, SyncMetadata.isDeleted) == 0) {
          return null;
        }
        payload.addAll({
          'product_uuid': productUuid,
          'sort_order': row['sort_order'],
          'path': _string(row, 'image_path'),
        });
        await _attachImageData(payload, _string(row, 'image_path'));
      case DbConstants.plans:
        final productId = row['product_id'] ?? _firstProductId(row);
        final productUuid = await _serverIdForLocalId(
          database,
          DbConstants.products,
          productId,
        );
        final customerUuid = await _serverIdForLocalId(
          database,
          DbConstants.customers,
          row['customer_id'],
        );
        if ((productUuid == null || customerUuid == null) &&
            _boolAsInt(row, SyncMetadata.isDeleted) == 0) {
          return null;
        }
        payload.addAll({
          'customer_uuid': customerUuid,
          'product_uuid': productUuid,
          'quantity': row['quantity'],
          'unit_price': row['unit_price'],
          'total_amount': row['total_amount'],
          'deposit_amount': row['deposit_amount'],
          'installment_amount': row['installment_amount'],
          'installment_count': row['installment_count'],
          'frequency_days': row['frequency_days'],
          'start_date': _string(row, 'start_date_iso'),
          'notes': _string(row, 'notes'),
          'item_name': _string(row, 'item_name'),
          'status': 'active',
        });
      case DbConstants.installments:
        final planUuid = await _serverIdForLocalId(
          database,
          DbConstants.plans,
          row['plan_id'],
        );
        if (planUuid == null && _boolAsInt(row, SyncMetadata.isDeleted) == 0) {
          return null;
        }
        payload.addAll({
          'plan_uuid': planUuid,
          'sequence_number': row['sequence_number'],
          'scheduled_due_date': _string(row, 'scheduled_due_date'),
          'current_due_date': _string(row, 'current_due_date'),
          'amount': row['amount'],
          'paid_amount': row['paid_amount'],
          'status': _string(row, 'status'),
        });
      case DbConstants.payments:
        final customerUuid = await _serverIdForLocalId(
          database,
          DbConstants.customers,
          row['customer_id'],
        );
        final planUuid = await _serverIdForLocalId(
          database,
          DbConstants.plans,
          row['plan_id'],
        );
        final installmentUuid = await _serverIdForLocalId(
          database,
          DbConstants.installments,
          row['installment_id'],
        );
        if ((customerUuid == null ||
                planUuid == null ||
                installmentUuid == null) &&
            _boolAsInt(row, SyncMetadata.isDeleted) == 0) {
          return null;
        }
        payload.addAll({
          'operation_uuid': 'local-payment-${row['id']}',
          'customer_uuid': customerUuid,
          'plan_uuid': planUuid,
          'installment_uuid': installmentUuid,
          'amount': row['amount'],
          'paid_on': _string(row, 'paid_on'),
          'note': _string(row, 'note'),
          'source': 'mobile',
        });
      case DbConstants.customerUserAccess:
        final userUuid = await _serverIdForUserUuid(database, row['user_uuid']);
        final customerUuid = await _serverIdForLocalId(
          database,
          DbConstants.customers,
          row['customer_uuid'],
        );
        if ((userUuid == null || customerUuid == null) &&
            _boolAsInt(row, SyncMetadata.isDeleted) == 0) {
          return null;
        }
        payload.addAll({
          'uuid': _string(row, 'uuid'),
          'user_uuid': userUuid,
          'customer_uuid': customerUuid,
        });
      case DbConstants.planUserAccess:
        final userUuid = await _serverIdForUserUuid(database, row['user_uuid']);
        final planUuid = await _serverIdForLocalId(
          database,
          DbConstants.plans,
          row['plan_uuid'],
        );
        if ((userUuid == null || planUuid == null) &&
            _boolAsInt(row, SyncMetadata.isDeleted) == 0) {
          return null;
        }
        payload.addAll({
          'uuid': _string(row, 'uuid'),
          'user_uuid': userUuid,
          'plan_uuid': planUuid,
        });
    }

    return payload;
  }

  Future<void> _attachImageData(
    Map<String, Object?> payload,
    String? imagePath,
  ) async {
    if (imagePath == null || imagePath.isEmpty) {
      return;
    }
    final file = File(imagePath);
    if (!await file.exists()) {
      return;
    }
    final bytes = await file.readAsBytes();
    payload.addAll({
      'original_name': p.basename(imagePath),
      'mime_type': _mimeTypeForPath(imagePath),
      'size': bytes.length,
      'image_base64': base64Encode(bytes),
    });
  }

  Future<void> _applyUploadMappings(
    String tableName,
    Map<String, dynamic> mappings,
  ) async {
    final rows = mappings[tableName];
    if (rows is! List || rows.isEmpty) {
      return;
    }

    final database = await _dbHelper.database;
    final batch = database.batch();
    for (final row in rows.whereType<Map>()) {
      final localId = row['local_id'];
      final serverId = row['server_id']?.toString();
      if (localId == null || serverId == null || serverId.isEmpty) {
        continue;
      }
      batch.update(
        tableName,
        SyncMetadata.withServerChange(tableName, {
          SyncMetadata.serverId: serverId,
          SyncMetadata.dateUpdated:
              row['date_updated']?.toString() ??
              DateTime.now().toUtc().toIso8601String(),
          SyncMetadata.isDeleted: row['is_deleted'] == true ? 1 : 0,
        }),
        where: 'id = ?',
        whereArgs: [localId],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _applyDownloadedRecord(
    Database database,
    String tableName,
    Map<String, dynamic> record,
  ) async {
    final serverId =
        record['server_id']?.toString() ?? record['uuid']?.toString();
    if (serverId == null || serverId.isEmpty) {
      return;
    }

    final localValues = await _mapServerRecordToLocal(
      database,
      tableName,
      record,
    );
    if (localValues == null) {
      return;
    }

    final existing = await _findExistingLocalRow(
      database,
      tableName,
      serverId,
      localValues,
    );
    if (existing != null && _boolAsInt(existing, SyncMetadata.isSync) == 0) {
      developer.log(
        'Skipped remote $tableName/$serverId because local record has pending changes.',
        name: 'KistBook.SyncService',
      );
      return;
    }

    final values = SyncMetadata.withServerChange(tableName, {
      ...localValues,
      SyncMetadata.serverId: serverId,
      SyncMetadata.dateUpdated:
          record['date_updated']?.toString() ??
          record['updated_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String(),
      SyncMetadata.isDeleted: record['is_deleted'] == true ? 1 : 0,
    })..remove('id');

    if (existing == null) {
      if (values[SyncMetadata.isDeleted] == 1) {
        return;
      }
      await database.insert(tableName, values);
      return;
    }

    await database.update(
      tableName,
      values,
      where: 'id = ?',
      whereArgs: [existing['id']],
    );
  }

  Future<Map<String, Object?>?> _mapServerRecordToLocal(
    Database database,
    String tableName,
    Map<String, dynamic> record,
  ) async {
    switch (tableName) {
      case DbConstants.users:
        return {
          'uuid': record['uuid']?.toString() ?? record['server_id']?.toString(),
          'phone': record['phone']?.toString() ?? '',
          'email': record['email']?.toString() ?? '',
          'password': record['password']?.toString() ?? 'remote-login-only',
          'first_name': record['first_name']?.toString() ?? '',
          'last_name': record['last_name']?.toString() ?? '',
          'role': _localRole(
            record['role']?.toString() ?? record['access_level']?.toString(),
          ),
          'is_active': record['is_active'] == false ? 0 : 1,
        };
      case DbConstants.customers:
        return {
          'card_number': record['card_no']?.toString() ?? '',
          'name': record['name']?.toString() ?? '',
          'phone': record['phone']?.toString() ?? '',
          'cnic': record['cnic']?.toString() ?? '',
          'address': record['address']?.toString() ?? '',
          'reference_name': record['reference']?.toString() ?? '',
        };
      case DbConstants.products:
        return {
          'categories_text': jsonEncode(
            _decodeDynamicList(record['categories']),
          ),
          'brand_name': record['brand_name']?.toString() ?? '',
          'name': record['product_name']?.toString() ?? '',
          'sku': record['code']?.toString() ?? '',
          'sale_price': _num(record['sales_price']),
          'notes': record['notes']?.toString() ?? '',
        };
      case DbConstants.productImages:
        final productId = await _localIdForServerId(
          database,
          DbConstants.products,
          record['product_uuid'],
        );
        if (productId == null) {
          return null;
        }
        final localImagePath = await _localImagePathFor(record);
        if (localImagePath == null &&
            (record['is_deleted'] == false || record['is_deleted'] == null)) {
          return null;
        }
        return {
          'product_id': productId,
          'image_path': localImagePath ?? '',
          'sort_order': _int(record['sort_order']) ?? 0,
        };
      case DbConstants.plans:
        final customerId = await _localIdForServerId(
          database,
          DbConstants.customers,
          record['customer_uuid'],
        );
        final productId = await _localIdForServerId(
          database,
          DbConstants.products,
          record['product_uuid'],
        );
        if (customerId == null || productId == null) {
          return null;
        }
        final itemName =
            record['item_name']?.toString() ??
            record['product_name']?.toString() ??
            '';
        return {
          'customer_id': customerId,
          'product_id': productId,
          'quantity': _int(record['quantity']) ?? 1,
          'unit_price': _num(record['unit_price']),
          'product_ids_text': '$productId',
          'product_selections_text': jsonEncode([
            {
              'product_id': productId,
              'quantity': _int(record['quantity']) ?? 1,
            },
          ]),
          'item_name': itemName,
          'total_amount': _num(record['total_amount']),
          'deposit_amount': _num(record['deposit_amount']),
          'installment_amount': _num(record['installment_amount']),
          'installment_count': _int(record['installment_count']) ?? 0,
          'frequency_days': _int(record['frequency_days']) ?? 30,
          'start_date_iso': record['start_date']?.toString() ?? '',
          'notes': record['notes']?.toString() ?? '',
        };
      case DbConstants.installments:
        final planId = await _localIdForServerId(
          database,
          DbConstants.plans,
          record['plan_uuid'],
        );
        if (planId == null) {
          return null;
        }
        return {
          'plan_id': planId,
          'sequence_number': _int(record['sequence_number']) ?? 0,
          'scheduled_due_date': record['scheduled_due_date']?.toString() ?? '',
          'current_due_date': record['current_due_date']?.toString() ?? '',
          'amount': _num(record['amount']),
          'paid_amount': _num(record['paid_amount']),
          'status':
              record['status']?.toString() ??
              InstallmentRecordStatus.pending.name,
        };
      case DbConstants.payments:
        final customerId = await _localIdForServerId(
          database,
          DbConstants.customers,
          record['customer_uuid'],
        );
        final planId = await _localIdForServerId(
          database,
          DbConstants.plans,
          record['plan_uuid'],
        );
        final installmentId = await _localIdForServerId(
          database,
          DbConstants.installments,
          record['installment_uuid'],
        );
        if (customerId == null || planId == null || installmentId == null) {
          return null;
        }
        return {
          'customer_id': customerId,
          'plan_id': planId,
          'installment_id': installmentId,
          'amount': _num(record['amount']),
          'paid_on': record['paid_on']?.toString() ?? '',
          'note': record['note']?.toString() ?? '',
        };
      case DbConstants.customerUserAccess:
        final localUserUuid = await _localUserUuidForServerId(
          database,
          record['user_uuid'],
        );
        final localCustomerId = await _localIdForServerId(
          database,
          DbConstants.customers,
          record['customer_uuid'],
        );
        if (localUserUuid == null || localCustomerId == null) {
          return null;
        }
        return {
          'uuid': record['uuid']?.toString() ?? record['server_id']?.toString(),
          'user_uuid': localUserUuid,
          'customer_uuid': '$localCustomerId',
        };
      case DbConstants.planUserAccess:
        final localUserUuid = await _localUserUuidForServerId(
          database,
          record['user_uuid'],
        );
        final localPlanId = await _localIdForServerId(
          database,
          DbConstants.plans,
          record['plan_uuid'],
        );
        if (localUserUuid == null || localPlanId == null) {
          return null;
        }
        return {
          'uuid': record['uuid']?.toString() ?? record['server_id']?.toString(),
          'user_uuid': localUserUuid,
          'plan_uuid': '$localPlanId',
        };
    }
    return null;
  }

  Future<Map<String, Object?>?> _findExistingLocalRow(
    Database database,
    String tableName,
    String serverId,
    Map<String, Object?> values,
  ) async {
    final byServerId = await database.query(
      tableName,
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (byServerId.isNotEmpty) {
      return byServerId.first;
    }

    final fallback = switch (tableName) {
      DbConstants.users => ('phone', values['phone']),
      DbConstants.customers => ('cnic', values['cnic']),
      DbConstants.products => ('sku', values['sku']),
      DbConstants.productImages => ('image_path', values['image_path']),
      DbConstants.customerUserAccess => ('uuid', values['uuid']),
      DbConstants.planUserAccess => ('uuid', values['uuid']),
      _ => (null, null),
    };
    if (fallback.$1 == null ||
        fallback.$2 == null ||
        fallback.$2.toString().isEmpty) {
      return null;
    }
    final rows = await database.query(
      tableName,
      where: '${fallback.$1} = ?',
      whereArgs: [fallback.$2],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> _serverIdForLocalId(
    Database database,
    String tableName,
    Object? localId,
  ) async {
    final id = int.tryParse(localId?.toString() ?? '');
    if (id == null) {
      return null;
    }
    final rows = await database.query(
      tableName,
      columns: [SyncMetadata.serverId],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _string(rows.first, SyncMetadata.serverId);
  }

  Future<int?> _localIdForServerId(
    Database database,
    String tableName,
    Object? serverId,
  ) async {
    final uuid = serverId?.toString() ?? '';
    if (uuid.isEmpty) {
      return null;
    }
    final rows = await database.query(
      tableName,
      columns: ['id'],
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _int(rows.first['id']);
  }

  Future<String?> _serverIdForUserUuid(
    Database database,
    Object? userUuid,
  ) async {
    final uuid = userUuid?.toString() ?? '';
    if (uuid.isEmpty) {
      return null;
    }
    final rows = await database.query(
      DbConstants.users,
      columns: ['uuid', SyncMetadata.serverId],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return _string(rows.first, SyncMetadata.serverId) ??
        _string(rows.first, 'uuid');
  }

  Future<String?> _localUserUuidForServerId(
    Database database,
    Object? serverId,
  ) async {
    final uuid = serverId?.toString() ?? '';
    if (uuid.isEmpty) {
      return null;
    }
    final rows = await database.query(
      DbConstants.users,
      columns: ['uuid'],
      where: '${SyncMetadata.serverId} = ? OR uuid = ?',
      whereArgs: [uuid, uuid],
      limit: 1,
    );
    return rows.isEmpty ? null : _string(rows.first, 'uuid');
  }

  Future<String?> _localImagePathFor(Map<String, dynamic> record) async {
    final imageUrl =
        record['image_url']?.toString() ?? record['url']?.toString();
    if (imageUrl == null || imageUrl.isEmpty) {
      return record['path']?.toString();
    }
    final uri = _imageUri(imageUrl);
    final response = await _httpClient
        .get(
          uri,
          headers: {'Authorization': 'Bearer ${_sessionManager.apiToken}'},
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    return ProductImageStorage.saveBytes(
      bytes: response.bodyBytes,
      sourceName: record['original_name']?.toString() ?? uri.path,
    );
  }

  Uri _imageUri(String imageUrl) {
    return Uri.parse(
      API.productImageUrl(
        imagePath: imageUrl,
        baseURL: _sessionManager.apiBaseUrl,
      ),
    );
  }

  String? _string(Map<String, Object?> row, String key) {
    final value = row[key]?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  int _boolAsInt(Map<String, Object?> row, String key) {
    final value = row[key];
    if (value is bool) {
      return value ? 1 : 0;
    }
    if (value is num) {
      return value.toInt() == 0 ? 0 : 1;
    }
    return value?.toString() == 'true' ? 1 : 0;
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

  num _num(Object? value) {
    if (value is num) {
      return value;
    }
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  Object? _firstProductId(Map<String, Object?> row) {
    final selections = _decodeDynamicList(row['product_selections_text']);
    if (selections.isNotEmpty && selections.first is Map) {
      return (selections.first as Map)['product_id'];
    }
    final idsText = row['product_ids_text']?.toString() ?? '';
    return idsText
        .split(',')
        .map((item) => item.trim())
        .firstWhere((item) => item.isNotEmpty, orElse: () => '');
  }

  List<String> _decodeStringList(String? raw) {
    return _decodeDynamicList(raw)
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  List<Object?> _decodeDynamicList(Object? raw) {
    if (raw == null) {
      return const [];
    }
    if (raw is List) {
      return raw;
    }
    try {
      final decoded = jsonDecode(raw.toString());
      return decoded is List ? decoded : const [];
    } catch (_) {
      return const [];
    }
  }

  String _backendRole(String? role) {
    return role == UserRole.salesMan.name ? 'salesman' : (role ?? 'salesman');
  }

  String _localRole(String? role) {
    return role == 'salesman'
        ? UserRole.salesMan.name
        : (role ?? UserRole.salesMan.name);
  }

  String _mimeTypeForPath(String path) {
    return switch (p.extension(path).toLowerCase()) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.heic' => 'image/heic',
      '.jpeg' || '.jpg' => 'image/jpeg',
      _ => 'image/jpeg',
    };
  }
}
