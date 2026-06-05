import '../../core/constants/api_urls.dart';
import '../../core/services/api_services.dart';
import '../../core/utils/dart_json.dart';

class AccessAssignmentRemoteDataSource {
  AccessAssignmentRemoteDataSource(this._apiServices);

  final ApiServices _apiServices;

  Future<AccessAssignmentSaveResult> replaceAssignments({
    required String userId,
    required List<String> customerIds,
    required List<String> planIds,
  }) async {
    final response = await _apiServices.sendRequest(
      method: ApiRequestMethod.put,
      endpoint: API.URL_ACCESS_ASSIGNMENTS,
      body: {'userId': userId, 'customerIds': customerIds, 'planIds': planIds},
    );

    return AccessAssignmentSaveResult.fromJson(response);
  }
}

class AccessAssignmentSaveResult {
  const AccessAssignmentSaveResult({
    required this.userId,
    required this.customerAccess,
    required this.planAccess,
  });

  final String userId;
  final List<AccessAssignmentRecord> customerAccess;
  final List<AccessAssignmentRecord> planAccess;

  factory AccessAssignmentSaveResult.fromJson(Map<String, dynamic> json) {
    final data = DartJson(json).jsonValue('data');

    return AccessAssignmentSaveResult(
      userId: data.stringValue('userId'),
      customerAccess: _records(
        data.rawValue('customerAccess'),
        targetKey: 'customerId',
      ),
      planAccess: _records(data.rawValue('planAccess'), targetKey: 'planId'),
    );
  }

  static List<AccessAssignmentRecord> _records(
    Object? raw, {
    required String targetKey,
  }) {
    if (raw is! List) {
      return const [];
    }

    return raw
        .whereType<Map>()
        .map((item) => AccessAssignmentRecord.fromJson(item, targetKey))
        .where((item) => item.isValid)
        .toList();
  }
}

class AccessAssignmentRecord {
  const AccessAssignmentRecord({
    required this.serverId,
    required this.userId,
    required this.targetId,
    required this.isDeleted,
    this.createdAt,
    this.updatedAt,
  });

  final String serverId;
  final String userId;
  final String targetId;
  final bool isDeleted;
  final String? createdAt;
  final String? updatedAt;

  bool get isValid =>
      serverId.isNotEmpty && userId.isNotEmpty && targetId.isNotEmpty;

  factory AccessAssignmentRecord.fromJson(
    Map<dynamic, dynamic> json,
    String targetKey,
  ) {
    final data = DartJson(json);

    return AccessAssignmentRecord(
      serverId: data.stringValue('serverId'),
      userId: data.stringValue('userId'),
      targetId: data.stringValue(targetKey),
      isDeleted: data.boolValue('isDeleted'),
      createdAt: data.asString('createdAt'),
      updatedAt: data.asString('updatedAt'),
    );
  }
}
