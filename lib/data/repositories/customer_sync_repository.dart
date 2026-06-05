import 'package:sqflite/sqflite.dart';

import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../database/sync_metadata.dart';
import '../datasources/customer_remote_data_source.dart';
import '../sync/sync_batch_models.dart';
import '../sync/sync_cursor_store.dart';
import '../../services/sync_change_notifier.dart';

class CustomerSyncRepository {
  CustomerSyncRepository({
    required DbHelper dbHelper,
    required CustomerRemoteDataSource remoteDataSource,
    required SyncCursorStore cursorStore,
    SyncChangeNotifier? changeNotifier,
  }) : _dbHelper = dbHelper,
       _remoteDataSource = remoteDataSource,
       _cursorStore = cursorStore,
       _changeNotifier = changeNotifier;

  static const _batchSize = 10;
  static const _initialLastUpdatedAt = '2001-01-01T00:00:00.000Z';

  final DbHelper _dbHelper;
  final CustomerRemoteDataSource _remoteDataSource;
  final SyncCursorStore _cursorStore;
  final SyncChangeNotifier? _changeNotifier;

  Future<void> uploadPending() async {
    final database = await _dbHelper.database;
    final rows = await database.query(
      DbConstants.customers,
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
    await _uploadCreates(createRows);
    await _uploadUpdates(updateRows);
    await _uploadDeletes(deleteRows);
  }

  Future<void> downloadLatest() async {
    var cursor = await _cursorStore.read(SyncCursorStore.customers);
    while (true) {
      final result = await _remoteDataSource.download(
        lastUpdatedAt: cursor.lastUpdatedAt ?? _initialLastUpdatedAt,
        lastServerId: cursor.lastServerId,
        limit: _batchSize,
      );

      if (result.records.isEmpty) {
        return;
      }

      await applyDownloadedRecords(result.records);
      _changeNotifier?.notify(SyncResource.customers);
      final lastRecord = result.records.last;
      cursor = _nextCursor(result, lastRecord);
      if (_string(cursor.lastUpdatedAt) == null) {
        return;
      }
      await _cursorStore.save(SyncCursorStore.customers, cursor);
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

  Future<void> _uploadCreates(List<Map<String, Object?>> rows) async {
    for (final chunk in _chunks(rows)) {
      final result = await _remoteDataSource.create(
        chunk.map(_customerPayload).toList(),
      );
      await _applyUploadResult(chunk, result);
    }
  }

  Future<void> _uploadUpdates(List<Map<String, Object?>> rows) async {
    for (final chunk in _chunks(rows)) {
      final result = await _remoteDataSource.update(
        chunk.map(_customerPayload).toList(),
      );
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

  Map<String, Object?> _customerPayload(Map<String, Object?> row) {
    return <String, Object?>{
      if (_string(row[SyncMetadata.serverId]) != null)
        'serverId': _string(row[SyncMetadata.serverId]),
      'updatedAt':
          _string(row[SyncMetadata.dateUpdated]) ?? _string(row['updated_at']),
      'cardNumber': _string(row['card_number']) ?? '',
      'customerName': _string(row['name']) ?? '',
      'phoneNumber': _string(row['phone']) ?? '',
      'cnic': _string(row['cnic']) ?? '',
      'address': _string(row['address']) ?? '',
      'reference': _string(row['reference_name']) ?? '',
    };
  }

  Future<void> _applyUploadResult(
    List<Map<String, Object?>> rows,
    SyncUploadResult result,
  ) async {
    if (result.mappings.isEmpty) {
      return;
    }

    final database = await _dbHelper.database;
    final syncedByServerId = {
      for (final record in result.synced)
        if (_string(record['serverId']) != null)
          _string(record['serverId'])!: record,
    };

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
        await txn.update(
          DbConstants.customers,
          SyncMetadata.withServerChange(DbConstants.customers, {
            SyncMetadata.serverId: mapping.serverId,
            SyncMetadata.dateUpdated:
                _string(synced?['updatedAt']) ?? result.serverTime,
            SyncMetadata.isDeleted: _bool(synced?['isDeleted']) ? 1 : 0,
          }),
          where: 'id = ?',
          whereArgs: [localId],
        );
      }
    });
  }

  Future<void> applyDownloadedRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final database = await _dbHelper.database;
    await database.transaction((txn) async {
      for (final record in records) {
        await _applyDownloadedRecord(txn, record);
      }
    });
  }

  Future<void> _applyDownloadedRecord(
    Transaction txn,
    Map<String, dynamic> record,
  ) async {
    final serverId = _string(record['serverId']);
    if (serverId == null) {
      return;
    }

    final existing = await _findExisting(txn, serverId, record);
    if (existing != null && _bool(existing[SyncMetadata.isSync]) == false) {
      return;
    }

    final values = SyncMetadata.withServerChange(DbConstants.customers, {
      SyncMetadata.serverId: serverId,
      SyncMetadata.dateUpdated:
          _string(record['updatedAt']) ??
          DateTime.now().toUtc().toIso8601String(),
      SyncMetadata.isDeleted: _bool(record['isDeleted']) ? 1 : 0,
      'card_number': _string(record['cardNumber']) ?? '',
      'name': _string(record['customerName']) ?? '',
      'phone': _string(record['phoneNumber']) ?? '',
      'cnic': _string(record['cnic']) ?? '',
      'address': _string(record['address']) ?? '',
      'reference_name': _string(record['reference']) ?? '',
      'customer_image_url': _string(record['customerImage']),
    })..remove('id');

    if (existing == null) {
      if (_bool(record['isDeleted'])) {
        return;
      }
      await txn.insert(DbConstants.customers, values);
      return;
    }

    await txn.update(
      DbConstants.customers,
      values,
      where: 'id = ?',
      whereArgs: [existing['id']],
    );
  }

  Future<Map<String, Object?>?> _findExisting(
    DatabaseExecutor executor,
    String serverId,
    Map<String, dynamic> record,
  ) async {
    final byServerId = await executor.query(
      DbConstants.customers,
      where: '${SyncMetadata.serverId} = ?',
      whereArgs: [serverId],
      limit: 1,
    );
    if (byServerId.isNotEmpty) {
      return byServerId.first;
    }

    final cnic = _string(record['cnic']);
    if (cnic == null) {
      return null;
    }
    final byCnic = await executor.query(
      DbConstants.customers,
      where: 'cnic = ?',
      whereArgs: [cnic],
      limit: 1,
    );
    return byCnic.isEmpty ? null : byCnic.first;
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
      DbConstants.customers,
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
