import 'package:sqflite/sqflite.dart';

import '../database/db_helper.dart';
import '../models/base_model.dart';
import 'sql_expression.dart';

typedef FromMap<T extends BaseModel> = T Function(Map<String, Object?> map);

class GenericRepository<T extends BaseModel> {
  GenericRepository({
    required DbHelper dbHelper,
    required this.tableName,
    required this.fromMap,
  }) : _dbHelper = dbHelper;

  final DbHelper _dbHelper;
  final String tableName;
  final FromMap<T> fromMap;

  Future<Database> get db async => _dbHelper.database;

  Future<int> insert(T item) async {
    final database = await db;
    return database.insert(tableName, item.toMap()..remove('id'));
  }

  Future<int> update(T item) async {
    final database = await db;
    return database.update(
      tableName,
      item.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<T> save(T item) async {
    if (item.id == null) {
      final insertedId = await insert(item);
      final stored = await findOne(insertedId);
      if (stored == null) {
        throw StateError('Failed to reload $tableName after insert.');
      }
      return stored;
    }
    await update(item);
    return item;
  }

  Future<void> insertOrUpdateByKey(T item) async {
    final database = await db;
    final key = item.uniqueKey;
    final value = item.uniqueKeyValue;

    if (value == null) {
      await database.insert(
        tableName,
        item.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return;
    }

    final updated = await database.update(
      tableName,
      item.toMap()..remove('id'),
      where: '$key = ?',
      whereArgs: [value],
    );

    if (updated == 0) {
      await database.insert(
        tableName,
        item.toMap()..remove('id'),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> insertOrUpdateAll(List<T> items) async {
    if (items.isEmpty) {
      return;
    }

    final database = await db;
    await database.transaction((txn) async {
      final batch = txn.batch();
      for (final item in items) {
        final value = item.uniqueKeyValue;
        if (value == null) {
          batch.insert(
            tableName,
            item.toMap()..remove('id'),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          continue;
        }

        batch.insert(
          tableName,
          item.toMap()..remove('id'),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<int> delete(int id) async {
    final database = await db;
    return database.delete(tableName, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteAllByIds(List<int> ids) async {
    if (ids.isEmpty) {
      return 0;
    }

    final database = await db;
    final placeholders = List.filled(ids.length, '?').join(',');
    return database.delete(
      tableName,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> deleteByExpression({required SQLExpression where}) async {
    final database = await db;
    await database.delete(
      tableName,
      where: where.buildQuery(),
      whereArgs: where.values,
    );
  }

  Future<List<T>> getAll({String? orderBy}) async {
    final database = await db;
    final rows = await database.query(tableName, orderBy: orderBy);
    return rows.map(fromMap).toList();
  }

  Future<List<T>> findAllWhere(String key, Object? value, {String? orderBy}) async {
    final database = await db;
    final rows = await database.query(
      tableName,
      where: '$key = ?',
      whereArgs: [value],
      orderBy: orderBy,
    );
    return rows.map(fromMap).toList();
  }

  Future<List<T>> getByExpression({
    required SQLExpression where,
    int? limit,
    String? orderBy,
  }) async {
    final database = await db;
    final rows = await database.query(
      tableName,
      where: where.buildQuery(),
      whereArgs: where.values,
      limit: limit,
      orderBy: orderBy,
    );
    return rows.map(fromMap).toList();
  }

  Future<T?> getOneByExpression(SQLExpression where) async {
    final result = await getByExpression(where: where, limit: 1);
    return result.isEmpty ? null : result.first;
  }

  Future<T?> findOne(int id) async {
    final database = await db;
    final rows = await database.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : fromMap(rows.first);
  }

  Future<T?> findOneBy(String key, Object? value) async {
    final database = await db;
    final rows = await database.query(
      tableName,
      where: '$key = ?',
      whereArgs: [value],
      limit: 1,
    );
    return rows.isEmpty ? null : fromMap(rows.first);
  }
}
