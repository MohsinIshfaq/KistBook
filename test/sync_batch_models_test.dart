import 'package:flutter_test/flutter_test.dart';
import 'package:kistbook/data/sync/sync_batch_models.dart';

void main() {
  test('SyncUploadResult parses mappings, failures, and conflicts', () {
    final result = SyncUploadResult.fromJson({
      'serverTime': '2026-06-04T10:00:00.000Z',
      'mappings': [
        {'index': 0, 'serverId': 'server-1'},
      ],
      'synced': [
        {'serverId': 'server-1', 'productName': 'Reno 13'},
      ],
      'failed': [
        {
          'index': 1,
          'errors': {
            'salesPrice': ['The sales price field is required.'],
          },
        },
      ],
      'conflicts': [
        {
          'index': 2,
          'serverId': 'server-2',
          'reason': 'The server product is newer than the uploaded record.',
          'serverRecord': {'serverId': 'server-2'},
        },
      ],
    });

    expect(result.serverTime, '2026-06-04T10:00:00.000Z');
    expect(result.mappings.single.serverId, 'server-1');
    expect(result.synced.single['productName'], 'Reno 13');
    expect(result.failed.single.errors.single, contains('sales price'));
    expect(result.conflicts.single.serverRecord?['serverId'], 'server-2');
  });

  test('SyncDownloadResult parses cursor metadata', () {
    final result = SyncDownloadResult.fromJson({
      'serverTime': '2026-06-04T10:00:00.000Z',
      'hasMore': true,
      'nextCursor': {
        'lastUpdatedAt': '2026-06-04T09:59:00.000Z',
        'lastServerId': 'server-10',
      },
      'data': [
        {'serverId': 'server-10'},
      ],
    });

    expect(result.hasMore, isTrue);
    expect(result.records.single['serverId'], 'server-10');
    expect(result.nextCursor?.lastServerId, 'server-10');
  });
}
