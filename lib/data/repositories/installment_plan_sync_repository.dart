import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../services/sync_change_notifier.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../database/sync_metadata.dart';
import '../datasources/installment_plan_remote_data_source.dart';
import '../models/purchase_plan_model.dart';
import '../sync/sync_batch_models.dart';
import '../sync/sync_cursor_store.dart';

class InstallmentPlanSyncRepository {
  InstallmentPlanSyncRepository({
    required DbHelper dbHelper,
    required InstallmentPlanRemoteDataSource remoteDataSource,
    required SyncCursorStore cursorStore,
    SyncChangeNotifier? changeNotifier,
  }) : _dbHelper = dbHelper,
       _remoteDataSource = remoteDataSource,
       _cursorStore = cursorStore,
       _changeNotifier = changeNotifier;

  static const _batchSize = 10;
  static const _initialLastUpdatedAt = '2001-01-01T00:00:00.000Z';

  final DbHelper _dbHelper;
  final InstallmentPlanRemoteDataSource _remoteDataSource;
  final SyncCursorStore _cursorStore;
  final SyncChangeNotifier? _changeNotifier;

  Future<void> uploadPending() async {
    final database = await _dbHelper.database;
    final rows = await database.query(
      DbConstants.plans,
      where: '${SyncMetadata.isSync} = 0',
      orderBy: 'id ASC',
    );
    if (rows.isEmpty) {
      return;
    }

    final createRows = <Map<String, Object?>>[];
    final updateRows = <Map<String, Object?>>[];
    final deleteRows = <Map<String, Object?>>[];
    final neverSyncedDeletes = <int>[];

    for (final row in rows) {
      final id = _int(row['id']);
      final serverId = _string(row[SyncMetadata.serverId]);
      final isDeleted = _bool(row[SyncMetadata.isDeleted]);
      if (id == null) {
        continue;
      }
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

    await _hardDeleteNeverSynced(database, neverSyncedDeletes);
    await _uploadCreates(database, createRows);
    await _uploadUpdates(database, updateRows);
    await _uploadDeletes(deleteRows);
  }

  Future<void> downloadLatest() async {
    var cursor = await _cursorStore.read(SyncCursorStore.installmentPlans);
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
      _changeNotifier?.notify(SyncResource.installmentPlans);

      final lastRecord = result.records.last;
      cursor = _nextCursor(result, lastRecord);
      if (_string(cursor.lastUpdatedAt) == null) {
        return;
      }
      await _cursorStore.save(SyncCursorStore.installmentPlans, cursor);
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
      final payloadRows = <Map<String, Object?>>[];
      for (final row in chunk) {
        final plan = await _planPayload(database, row);
        if (plan == null) {
          continue;
        }
        payload.add(plan);
        payloadRows.add(row);
      }
      if (payload.isEmpty) {
        continue;
      }
      final result = await _remoteDataSource.create(payload);
      await _applyUploadResult(payloadRows, result);
    }
  }

  Future<void> _uploadUpdates(
    Database database,
    List<Map<String, Object?>> rows,
  ) async {
    for (final chunk in _chunks(rows)) {
      final payload = <Map<String, Object?>>[];
      final payloadRows = <Map<String, Object?>>[];
      for (final row in chunk) {
        final plan = await _planPayload(database, row);
        if (plan == null) {
          continue;
        }
        payload.add(plan);
        payloadRows.add(row);
      }
      if (payload.isEmpty) {
        continue;
      }
      final result = await _remoteDataSource.update(payload);
      await _applyUploadResult(payloadRows, result);
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

  Future<Map<String, Object?>?> _planPayload(
    Database database,
    Map<String, Object?> row,
  ) async {
    final plan = PurchasePlanModel.fromMap(row);
    final customerServerId = await _serverIdForLocalId(
      database,
      DbConstants.customers,
      plan.customerId,
    );
    if (customerServerId == null) {
      return null;
    }

    final selectedProducts = <Map<String, Object?>>[];
    for (final selection in plan.productSelections) {
      final productServerId = await _serverIdForLocalId(
        database,
        DbConstants.products,
        selection.productId,
      );
      if (productServerId == null) {
        return null;
      }
      selectedProducts.add({
        'productId': productServerId,
        'quantity': selection.quantity,
        'agreedPrice': plan.unitPrice,
      });
    }
    if (selectedProducts.isEmpty && plan.primaryProductId != null) {
      final productServerId = await _serverIdForLocalId(
        database,
        DbConstants.products,
        plan.primaryProductId,
      );
      if (productServerId == null) {
        return null;
      }
      selectedProducts.add({
        'productId': productServerId,
        'quantity': plan.quantity,
        'agreedPrice': plan.unitPrice,
      });
    }
    if (selectedProducts.isEmpty) {
      return null;
    }

    return <String, Object?>{
      if (_string(row[SyncMetadata.serverId]) != null)
        'serverId': _string(row[SyncMetadata.serverId]),
      'updatedAt':
          _string(row[SyncMetadata.dateUpdated]) ?? _string(row['updated_at']),
      'customerId': customerServerId,
      'mode': 'common',
      'selectedProducts': selectedProducts,
      'commonDeposit': plan.depositAmount,
      'commonInstallmentAmount': plan.installmentAmount,
      'commonFrequencyInDays': plan.frequencyDays,
      'commonFirstDueDate': plan.startDate.toIso8601String(),
      if (plan.notes.trim().isNotEmpty) 'note': plan.notes.trim(),
    };
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
        final localId = _int(rows[mapping.index]['id']);
        if (localId == null || mapping.serverId.isEmpty) {
          continue;
        }
        final synced = syncedByServerId[mapping.serverId];
        if (synced == null) {
          await txn.update(
            DbConstants.plans,
            SyncMetadata.withServerChange(DbConstants.plans, {
              SyncMetadata.serverId: mapping.serverId,
              SyncMetadata.dateUpdated: result.serverTime,
            }),
            where: 'id = ?',
            whereArgs: [localId],
          );
          continue;
        }
        await _applyServerPlanRecord(
          txn,
          synced,
          preferredLocalId: localId,
          force: true,
        );
      }
    });
    _changeNotifier?.notify(SyncResource.installmentPlans);
  }

  Future<void> applyDownloadedRecords(
    List<Map<String, dynamic>> records,
  ) async {
    for (final record in records) {
      await applyDownloadedRecord(record);
    }
  }

  Future<void> applyDownloadedRecord(Map<String, dynamic> record) async {
    final database = await _dbHelper.database;
    await database.transaction((txn) async {
      await _applyServerPlanRecord(txn, record);
    });
  }

  Future<void> _applyServerPlanRecord(
    Transaction txn,
    Map<String, dynamic> record, {
    int? preferredLocalId,
    bool force = false,
  }) async {
    final serverId = _string(record['serverId']);
    if (serverId == null) {
      return;
    }

    final existing = preferredLocalId == null
        ? await _findExisting(txn, serverId)
        : await _planRowByLocalId(txn, preferredLocalId);
    if (!force && existing != null && !_bool(existing[SyncMetadata.isSync])) {
      return;
    }

    if (_bool(record['isDeleted'])) {
      if (existing == null) {
        return;
      }
      await txn.update(
        DbConstants.plans,
        SyncMetadata.withServerChange(DbConstants.plans, {
          SyncMetadata.serverId: serverId,
          SyncMetadata.isDeleted: 1,
          SyncMetadata.dateUpdated:
              _string(record['updatedAt']) ??
              DateTime.now().toUtc().toIso8601String(),
        }),
        where: 'id = ?',
        whereArgs: [existing['id']],
      );
      await txn.update(
        DbConstants.installments,
        SyncMetadata.withServerChange(DbConstants.installments, {
          SyncMetadata.isDeleted: 1,
        }),
        where: 'plan_id = ?',
        whereArgs: [existing['id']],
      );
      return;
    }

    final localValues = await _localPlanValues(txn, record, serverId, existing);
    if (localValues == null) {
      return;
    }

    final localId = existing == null
        ? await txn.insert(DbConstants.plans, localValues)
        : _int(existing['id']);
    if (localId == null) {
      return;
    }
    if (existing != null) {
      await txn.update(
        DbConstants.plans,
        localValues,
        where: 'id = ?',
        whereArgs: [localId],
      );
    }
    await _replaceSchedules(txn, localId, record, force: force);
  }

  Future<Map<String, Object?>?> _localPlanValues(
    DatabaseExecutor executor,
    Map<String, dynamic> record,
    String serverId,
    Map<String, Object?>? existing,
  ) async {
    final customerId = await _localIdForServerId(
      executor,
      DbConstants.customers,
      record['customerId'],
    );
    if (customerId == null) {
      return null;
    }

    final products = _listOfMaps(record['selectedProducts']);
    final selections = <PlanProductSelection>[];
    var quantity = 0;
    var productId = _int(existing?['product_id']);
    var itemName = '';
    for (final product in products) {
      final localProductId = await _localIdForServerId(
        executor,
        DbConstants.products,
        product['productId'],
      );
      if (localProductId == null) {
        return null;
      }
      productId ??= localProductId;
      final itemQuantity = (_int(product['quantity']) ?? 1).clamp(1, 999999);
      quantity += itemQuantity;
      selections.add(
        PlanProductSelection(productId: localProductId, quantity: itemQuantity),
      );
      final label = _string(product['itemName']);
      if (itemName.isEmpty && label != null) {
        itemName = label;
      }
    }

    if (selections.isEmpty || productId == null) {
      return null;
    }

    final totalAmount = _num(record['totalAmount']);
    final unitPrice = products.isNotEmpty
        ? _num(products.first['agreedPrice'])
        : totalAmount / quantity.clamp(1, 999999);
    final dateUpdated =
        _string(record['updatedAt']) ??
        DateTime.now().toUtc().toIso8601String();

    return SyncMetadata.withServerChange(DbConstants.plans, {
      SyncMetadata.serverId: serverId,
      SyncMetadata.dateUpdated: dateUpdated,
      SyncMetadata.isDeleted: 0,
      'customer_id': customerId,
      'product_id': productId,
      'quantity': quantity.clamp(1, 999999),
      'unit_price': unitPrice,
      'product_ids_text': selections.map((item) => item.productId).join(','),
      'product_selections_text': jsonEncode(
        selections.map((item) => item.toMap()).toList(),
      ),
      'item_name': itemName,
      'total_amount': totalAmount,
      'deposit_amount': _num(record['commonDeposit']),
      'installment_amount': _num(record['commonInstallmentAmount']),
      'installment_count': _int(record['installmentCount']) ?? 0,
      'frequency_days': _int(record['commonFrequencyInDays']) ?? 30,
      'start_date_iso':
          _string(record['commonFirstDueDate']) ??
          DateTime.now().toUtc().toIso8601String(),
      'notes': _string(record['note']) ?? '',
      'created_at': _string(record['createdAt']) ?? dateUpdated,
      'updated_at': dateUpdated,
    })..remove('id');
  }

  Future<void> _replaceSchedules(
    Transaction txn,
    int planId,
    Map<String, dynamic> record, {
    required bool force,
  }) async {
    final schedules = _listOfMaps(record['schedules']);
    if (schedules.isEmpty) {
      return;
    }

    final keptServerIds = <String>[];
    for (final schedule in schedules) {
      final serverId = _string(schedule['serverId']);
      if (serverId == null) {
        continue;
      }
      keptServerIds.add(serverId);
      final existing =
          await _installmentByServerId(txn, serverId) ??
          await _installmentBySequence(
            txn,
            planId,
            _int(schedule['sequenceNumber']) ?? 0,
          );
      if (!force && existing != null && !_bool(existing[SyncMetadata.isSync])) {
        continue;
      }
      final dateUpdated =
          _string(schedule['updatedAt']) ??
          DateTime.now().toUtc().toIso8601String();
      final values = SyncMetadata.withServerChange(DbConstants.installments, {
        SyncMetadata.serverId: serverId,
        SyncMetadata.dateUpdated: dateUpdated,
        SyncMetadata.isDeleted: _bool(schedule['isDeleted']) ? 1 : 0,
        'plan_id': planId,
        'sequence_number': _int(schedule['sequenceNumber']) ?? 0,
        'scheduled_due_date':
            _string(schedule['scheduledDueDate']) ?? dateUpdated,
        'current_due_date': _string(schedule['currentDueDate']) ?? dateUpdated,
        'previous_due_date': _string(schedule['previousDueDate']),
        'amount': _num(schedule['amount']),
        'paid_amount': _num(schedule['paidAmount']),
        'status': _string(schedule['status']) ?? 'pending',
        'reschedule_note': _string(schedule['rescheduleNote']) ?? '',
        'rescheduled_at': _string(schedule['rescheduledAt']),
        'created_at': _string(schedule['createdAt']) ?? dateUpdated,
        'updated_at': dateUpdated,
      })..remove('id');

      if (existing == null) {
        await txn.insert(DbConstants.installments, values);
      } else {
        await txn.update(
          DbConstants.installments,
          values,
          where: 'id = ?',
          whereArgs: [existing['id']],
        );
      }
    }

    if (keptServerIds.isEmpty) {
      return;
    }
    final placeholders = List.filled(keptServerIds.length, '?').join(',');
    await txn.update(
      DbConstants.installments,
      SyncMetadata.withServerChange(DbConstants.installments, {
        SyncMetadata.isDeleted: 1,
      }),
      where:
          'plan_id = ? AND ${SyncMetadata.isSync} = 1 AND ${SyncMetadata.serverId} IS NOT NULL AND ${SyncMetadata.serverId} NOT IN ($placeholders)',
      whereArgs: [planId, ...keptServerIds],
    );
  }

  Future<Map<String, Object?>?> _findExisting(
    DatabaseExecutor executor,
    String serverId,
  ) async {
    final rows = await executor.query(
      DbConstants.plans,
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> _planRowByLocalId(
    DatabaseExecutor executor,
    int localId,
  ) async {
    final rows = await executor.query(
      DbConstants.plans,
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> _installmentByServerId(
    DatabaseExecutor executor,
    String serverId,
  ) async {
    final rows = await executor.query(
      DbConstants.installments,
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> _installmentBySequence(
    DatabaseExecutor executor,
    int planId,
    int sequence,
  ) async {
    final rows = await executor.query(
      DbConstants.installments,
      where: 'plan_id = ? AND sequence_number = ?',
      whereArgs: [planId, sequence],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<String?> _serverIdForLocalId(
    DatabaseExecutor executor,
    String tableName,
    Object? localId,
  ) async {
    final id = _int(localId);
    if (id == null) {
      return null;
    }
    final rows = await executor.query(
      tableName,
      columns: [SyncMetadata.serverId],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _string(rows.first[SyncMetadata.serverId]);
  }

  Future<int?> _localIdForServerId(
    DatabaseExecutor executor,
    String tableName,
    Object? serverId,
  ) async {
    final uuid = _string(serverId);
    if (uuid == null) {
      return null;
    }
    final rows = await executor.query(
      tableName,
      columns: ['id'],
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    return rows.isEmpty ? null : _int(rows.first['id']);
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
      DbConstants.installments,
      where: 'plan_id IN ($placeholders)',
      whereArgs: localIds,
    );
    await database.delete(
      DbConstants.plans,
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

  List<Map<String, dynamic>> _listOfMaps(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .toList();
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

  bool _bool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    final normalized = value?.toString().toLowerCase();
    return normalized == 'true' || normalized == '1';
  }
}
