import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kistbook/data/database/db_constants.dart';
import 'package:kistbook/data/database/db_helper.dart';
import 'package:kistbook/data/sync/sync_batch_models.dart';
import 'package:kistbook/data/sync/sync_cursor_store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

void main() {
  test('database reset removes local rows and recreates schema', () async {
    final directory = await Directory.systemTemp.createTemp(
      'kistbook_db_reset_',
    );
    final dbHelper = DbHelper(databasePath: p.join(directory.path, 'test.db'));
    await dbHelper.initialize();

    final database = await dbHelper.database;
    await database.insert(DbConstants.customers, {
      'card_number': 'CARD-1',
      'name': 'Local Customer',
      'phone': '03001234567',
      'cnic': '42101-1111111-1',
      'address': 'Lahore',
      'reference_name': '',
      'created_at': '2026-06-04T10:00:00.000Z',
      'updated_at': '2026-06-04T10:00:00.000Z',
      'date_updated': '2026-06-04T10:00:00.000Z',
      'is_sync': 1,
      'is_deleted': 0,
    });

    expect(
      Sqflite.firstIntValue(
        await database.rawQuery(
          'SELECT COUNT(*) FROM ${DbConstants.customers}',
        ),
      ),
      1,
    );

    await dbHelper.resetDatabase();
    final resetDatabase = await dbHelper.database;

    expect(
      Sqflite.firstIntValue(
        await resetDatabase.rawQuery(
          'SELECT COUNT(*) FROM ${DbConstants.customers}',
        ),
      ),
      0,
    );
    expect(
      await resetDatabase.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
        [DbConstants.products],
      ),
      isNotEmpty,
    );

    await resetDatabase.close();
    await directory.delete(recursive: true);
  });

  test('cursor clear removes customer and product cursors', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SyncCursorStore();
    await store.save(
      SyncCursorStore.customers,
      const SyncCursor(lastUpdatedAt: '2026-06-04T10:00:00.000Z'),
    );
    await store.save(
      SyncCursorStore.products,
      const SyncCursor(
        lastUpdatedAt: '2026-06-04T10:10:00.000Z',
        lastServerId: 'product-server-id',
      ),
    );

    await store.clearAll();

    expect((await store.read(SyncCursorStore.customers)).lastUpdatedAt, isNull);
    final productCursor = await store.read(SyncCursorStore.products);
    expect(productCursor.lastUpdatedAt, isNull);
    expect(productCursor.lastServerId, isNull);
  });
}
