import 'package:shared_preferences/shared_preferences.dart';

import 'sync_batch_models.dart';

class SyncCursorStore {
  static const customers = 'customers';
  static const products = 'products';
  static const installmentPlans = 'installment_plans';
  static const _currentVersion = 4;
  static const _versionKey = 'sync_cursor_version';

  static String _updatedAtKey(String resource) =>
      'sync_cursor_${resource}_updated_at';
  static String _serverIdKey(String resource) =>
      'sync_cursor_${resource}_server_id';

  Future<SyncCursor> read(String resource) async {
    final preferences = await SharedPreferences.getInstance();
    await _migrateIfNeeded(preferences);
    return SyncCursor(
      lastUpdatedAt: preferences.getString(_updatedAtKey(resource)),
      lastServerId: preferences.getString(_serverIdKey(resource)),
    );
  }

  Future<void> save(String resource, SyncCursor cursor) async {
    final preferences = await SharedPreferences.getInstance();
    await _migrateIfNeeded(preferences);
    final updatedAt = cursor.lastUpdatedAt?.trim() ?? '';
    final serverId = cursor.lastServerId?.trim() ?? '';

    if (updatedAt.isEmpty) {
      await preferences.remove(_updatedAtKey(resource));
    } else {
      await preferences.setString(_updatedAtKey(resource), updatedAt);
    }

    if (serverId.isEmpty) {
      await preferences.remove(_serverIdKey(resource));
    } else {
      await preferences.setString(_serverIdKey(resource), serverId);
    }
  }

  Future<void> clearAll() async {
    final preferences = await SharedPreferences.getInstance();
    for (final resource in [customers, products, installmentPlans]) {
      await preferences.remove(_updatedAtKey(resource));
      await preferences.remove(_serverIdKey(resource));
    }
    await preferences.remove(_versionKey);
  }

  Future<void> _migrateIfNeeded(SharedPreferences preferences) async {
    final version = preferences.getInt(_versionKey) ?? 0;
    if (version >= _currentVersion) {
      return;
    }

    for (final resource in [customers, products, installmentPlans]) {
      await preferences.remove(_updatedAtKey(resource));
      await preferences.remove(_serverIdKey(resource));
    }
    await preferences.setInt(_versionKey, _currentVersion);
  }
}
