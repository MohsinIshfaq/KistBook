import '../../core/utils/dart_json.dart';

class SyncCursor {
  const SyncCursor({this.lastUpdatedAt, this.lastServerId});

  final String? lastUpdatedAt;
  final String? lastServerId;

  bool get isEmpty =>
      (lastUpdatedAt == null || lastUpdatedAt!.isEmpty) &&
      (lastServerId == null || lastServerId!.isEmpty);
}

class SyncMapping {
  const SyncMapping({required this.index, required this.serverId});

  final int index;
  final String serverId;

  factory SyncMapping.fromJson(Map<String, dynamic> json) {
    final reader = DartJson(json);
    return SyncMapping(
      index: reader.intValue('index'),
      serverId: reader.stringValue('serverId'),
    );
  }
}

class SyncFailure {
  const SyncFailure({
    required this.index,
    this.serverId,
    this.localId,
    this.errors = const [],
  });

  final int index;
  final String? serverId;
  final String? localId;
  final List<String> errors;

  factory SyncFailure.fromJson(Map<String, dynamic> json) {
    final reader = DartJson(json);
    final errors = <String>[];
    for (final value in reader.mapValue('errors').values) {
      if (value is List) {
        errors.addAll(value.map((item) => item.toString()));
      } else if (value != null) {
        errors.add(value.toString());
      }
    }
    return SyncFailure(
      index: reader.intValue('index'),
      serverId: reader.asString('serverId'),
      localId: reader.asString('localId'),
      errors: errors.where((item) => item.trim().isNotEmpty).toList(),
    );
  }
}

class SyncConflict {
  const SyncConflict({
    required this.index,
    this.serverId,
    this.reason = '',
    this.serverRecord,
  });

  final int index;
  final String? serverId;
  final String reason;
  final Map<String, dynamic>? serverRecord;

  factory SyncConflict.fromJson(Map<String, dynamic> json) {
    final reader = DartJson(json);
    return SyncConflict(
      index: reader.intValue('index'),
      serverId: reader.asString('serverId'),
      reason: reader.stringValue('reason'),
      serverRecord: reader.mapValue('serverRecord'),
    );
  }
}

class SyncUploadResult {
  const SyncUploadResult({
    required this.mappings,
    required this.synced,
    required this.failed,
    required this.conflicts,
    required this.serverTime,
  });

  final List<SyncMapping> mappings;
  final List<Map<String, dynamic>> synced;
  final List<SyncFailure> failed;
  final List<SyncConflict> conflicts;
  final String serverTime;

  factory SyncUploadResult.fromJson(Map<String, dynamic> json) {
    final reader = DartJson(json);
    return SyncUploadResult(
      mappings: reader
          .listValue('mappings')
          .whereType<Map>()
          .map((item) => SyncMapping.fromJson(_stringKeyMap(item)))
          .toList(),
      synced: reader
          .listValue('synced')
          .whereType<Map>()
          .map(_stringKeyMap)
          .toList(),
      failed: reader
          .listValue('failed')
          .whereType<Map>()
          .map((item) => SyncFailure.fromJson(_stringKeyMap(item)))
          .toList(),
      conflicts: reader
          .listValue('conflicts')
          .whereType<Map>()
          .map((item) => SyncConflict.fromJson(_stringKeyMap(item)))
          .toList(),
      serverTime: reader.stringValue('serverTime'),
    );
  }
}

class SyncDownloadResult {
  const SyncDownloadResult({
    required this.records,
    required this.serverTime,
    required this.hasMore,
    this.nextCursor,
  });

  final List<Map<String, dynamic>> records;
  final String serverTime;
  final bool hasMore;
  final SyncCursor? nextCursor;

  factory SyncDownloadResult.fromJson(Map<String, dynamic> json) {
    final reader = DartJson(json);
    final nextCursor = reader.mapValue('nextCursor');
    return SyncDownloadResult(
      records: reader
          .listValue('data')
          .whereType<Map>()
          .map(_stringKeyMap)
          .toList(),
      serverTime: reader.stringValue('serverTime'),
      hasMore: reader.boolValue('hasMore'),
      nextCursor: nextCursor.isEmpty
          ? null
          : SyncCursor(
              lastUpdatedAt: DartJson(nextCursor).asString('lastUpdatedAt'),
              lastServerId: DartJson(nextCursor).asString('lastServerId'),
            ),
    );
  }
}

Map<String, dynamic> _stringKeyMap(Map<dynamic, dynamic> value) {
  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    result[entry.key.toString()] = entry.value;
  }
  return result;
}
