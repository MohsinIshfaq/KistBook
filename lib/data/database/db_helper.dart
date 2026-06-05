import 'dart:io';
import 'dart:async';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_constants.dart';
import 'sync_metadata.dart';
import '../models/customer_model.dart';
import '../models/customer_user_access_model.dart';
import '../models/installment_model.dart';
import '../models/local_user_model.dart';
import '../models/payment_record_model.dart';
import '../models/plan_user_access_model.dart';
import '../models/product_image_model.dart';
import '../models/product_model.dart';
import '../models/product_price_history_model.dart';
import '../models/product_variant_attribute_model.dart';
import '../models/product_variant_model.dart';
import '../models/purchase_plan_model.dart';

class DbHelper {
  DbHelper({String? databasePath}) : _databasePath = databasePath;

  final String? _databasePath;
  Database? _database;
  Future<void> _writeQueue = Future<void>.value();

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await database;
  }

  Future<void> resetDatabase() async {
    await _writeQueue.catchError((_) {});
    final path = await _databaseFilePath();
    final existing = _database;
    _database = null;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    await databaseFactory.deleteDatabase(path);
    await database;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final path = await _databaseFilePath();

    _database = await openDatabase(
      path,
      version: DbConstants.databaseVersion,
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS ${DbConstants.products} (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              sku TEXT NOT NULL,
              sale_price REAL NOT NULL,
              notes TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute(
            'ALTER TABLE ${DbConstants.plans} ADD COLUMN product_id INTEGER',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE ${DbConstants.products} ADD COLUMN brand_name TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE ${DbConstants.products} ADD COLUMN updated_at TEXT",
          );
          await db.execute(ProductPriceHistoryModel.createTableQuery);
          await db.execute(
            "UPDATE ${DbConstants.products} SET updated_at = created_at WHERE updated_at IS NULL",
          );
          await db.execute('''
            INSERT INTO ${DbConstants.productPriceHistory} (product_id, previous_price, new_price, changed_at)
            SELECT id, NULL, sale_price, COALESCE(updated_at, created_at)
            FROM ${DbConstants.products}
            WHERE id NOT IN (
              SELECT product_id FROM ${DbConstants.productPriceHistory}
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE ${DbConstants.plans} ADD COLUMN product_ids_text TEXT NOT NULL DEFAULT ''",
          );
          await db.execute('''
            UPDATE ${DbConstants.plans}
            SET product_ids_text = CASE
              WHEN product_id IS NULL THEN ''
              ELSE CAST(product_id AS TEXT)
            END
          ''');
        }
        if (oldVersion < 5) {
          await db.execute(
            "ALTER TABLE ${DbConstants.plans} ADD COLUMN product_selections_text TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute('''
            UPDATE ${DbConstants.plans}
            SET product_selections_text = CASE
              WHEN product_id IS NULL THEN '[]'
              ELSE '[{"product_id":' || product_id || ',"quantity":1}]'
            END
            WHERE product_ids_text = ''
          ''');
          await db.execute('''
            UPDATE ${DbConstants.plans}
            SET product_selections_text =
              '[{"product_id":' ||
              REPLACE(product_ids_text, ',', ',"quantity":1},{"product_id":') ||
              ',"quantity":1}]'
            WHERE product_ids_text != ''
          ''');
        }
        if (oldVersion < 6) {
          await db.execute(
            "ALTER TABLE ${DbConstants.plans} ADD COLUMN quantity INTEGER NOT NULL DEFAULT 1",
          );
          await db.execute(
            "ALTER TABLE ${DbConstants.plans} ADD COLUMN unit_price REAL NOT NULL DEFAULT 0",
          );
          await db.execute('''
            UPDATE ${DbConstants.plans}
            SET unit_price = CASE
              WHEN quantity > 0 THEN total_amount / quantity
              ELSE total_amount
            END
          ''');
        }
        if (oldVersion < 7) {
          await db.execute(
            "ALTER TABLE ${DbConstants.products} ADD COLUMN category TEXT NOT NULL DEFAULT '${ProductModel.defaultCategory}'",
          );
          await db.execute('''
            UPDATE ${DbConstants.products}
            SET category = '${ProductModel.defaultCategory}'
            WHERE TRIM(COALESCE(category, '')) = ''
          ''');
        }
        if (oldVersion < 8) {
          await db.execute(
            "ALTER TABLE ${DbConstants.products} ADD COLUMN categories_text TEXT NOT NULL DEFAULT '[]'",
          );
          await db.execute('''
            UPDATE ${DbConstants.products}
            SET categories_text = CASE
              WHEN TRIM(COALESCE(category, '')) = '' THEN '["${ProductModel.defaultCategory}"]'
              ELSE '["' || REPLACE(TRIM(category), '"', '') || '"]'
            END
            WHERE TRIM(COALESCE(categories_text, '')) = '' OR categories_text = '[]'
          ''');
        }
        if (oldVersion < 9) {
          await db.execute(LocalUserModel.createTableQuery);
          await db.execute(CustomerUserAccessModel.createTableQuery);
          await db.execute(PlanUserAccessModel.createTableQuery);
        }
        if (oldVersion < 10) {
          await db.execute(
            "ALTER TABLE ${DbConstants.customers} ADD COLUMN card_number TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 11) {
          await db.execute(ProductImageModel.createTableQuery);
          await db.execute(ProductImageModel.createProductIndexQuery);
        }
        if (oldVersion < 12) {
          await _ensureSyncMetadata(db);
        }
        if (oldVersion < 13) {
          await _addColumnIfMissing(
            db,
            DbConstants.users,
            "email TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 14) {
          await _applyCustomerProductApiSchema(db);
        }
      },
    );

    return _database!;
  }

  Future<String> _databaseFilePath() async {
    return _databasePath ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          DbConstants.databaseName,
        );
  }

  Future<void> _createSchema(Database db) async {
    final createQueries = [
      CustomerModel.createTableQuery,
      ProductModel.createTableQuery,
      ProductImageModel.createTableQuery,
      ProductImageModel.createProductIndexQuery,
      ProductVariantModel.createTableQuery,
      ProductVariantModel.createProductIndexQuery,
      ProductVariantAttributeModel.createTableQuery,
      ProductVariantAttributeModel.createVariantIndexQuery,
      ProductPriceHistoryModel.createTableQuery,
      LocalUserModel.createTableQuery,
      CustomerUserAccessModel.createTableQuery,
      PlanUserAccessModel.createTableQuery,
      PurchasePlanModel.createTableQuery,
      InstallmentModel.createTableQuery,
      PaymentRecordModel.createTableQuery,
    ];

    for (final query in createQueries) {
      await db.execute(query);
    }
    await _ensureSyncMetadata(db);
    await _applyCustomerProductApiSchema(db);
  }

  Future<void> _applyCustomerProductApiSchema(Database db) async {
    await _addColumnIfMissing(
      db,
      DbConstants.customers,
      'customer_image_url TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbConstants.customers,
      'customer_image_path TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbConstants.customers,
      'customer_image_original_name TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbConstants.customers,
      'customer_image_mime_type TEXT',
    );
    await _addColumnIfMissing(
      db,
      DbConstants.customers,
      'customer_image_size INTEGER',
    );
    await _addColumnIfMissing(db, DbConstants.productImages, 'remote_url TEXT');
    await _addColumnIfMissing(
      db,
      DbConstants.productImages,
      'original_name TEXT',
    );
    await _addColumnIfMissing(db, DbConstants.productImages, 'mime_type TEXT');
    await _addColumnIfMissing(
      db,
      DbConstants.productImages,
      'image_size INTEGER',
    );
    await db.execute(
      ProductVariantModel.createTableQuery.replaceFirst(
        'CREATE TABLE',
        'CREATE TABLE IF NOT EXISTS',
      ),
    );
    await db.execute(ProductVariantModel.createProductIndexQuery);
    await db.execute(
      ProductVariantAttributeModel.createTableQuery.replaceFirst(
        'CREATE TABLE',
        'CREATE TABLE IF NOT EXISTS',
      ),
    );
    await db.execute(ProductVariantAttributeModel.createVariantIndexQuery);
  }

  Future<void> _ensureSyncMetadata(Database db) async {
    for (final tableName in SyncMetadata.syncableTables) {
      final exists = await _tableExists(db, tableName);
      if (!exists) {
        continue;
      }

      await _addColumnIfMissing(db, tableName, 'server_id TEXT');
      await _addColumnIfMissing(
        db,
        tableName,
        "created_at TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        tableName,
        "date_updated TEXT NOT NULL DEFAULT ''",
      );
      await _addColumnIfMissing(
        db,
        tableName,
        'is_sync INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        tableName,
        'is_deleted INTEGER NOT NULL DEFAULT 0',
      );
      await _addColumnIfMissing(
        db,
        tableName,
        "updated_at TEXT NOT NULL DEFAULT ''",
      );

      final now = DateTime.now().toUtc().toIso8601String();
      await db.update(tableName, {
        'created_at': now,
        'date_updated': now,
        'updated_at': now,
      }, where: "TRIM(COALESCE(date_updated, '')) = ''");
    }
  }

  Future<bool> _tableExists(Database db, String tableName) async {
    final rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      [tableName],
    );
    return rows.isNotEmpty;
  }

  Future<void> _addColumnIfMissing(
    Database db,
    String tableName,
    String definition,
  ) async {
    final columnName = definition.split(' ').first;
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any((column) => column['name'] == columnName);
    if (exists) {
      return;
    }
    await db.execute('ALTER TABLE $tableName ADD COLUMN $definition');
  }

  Future<T> synchronizedWrite<T>(Future<T> Function(Database db) action) {
    final completer = Completer<T>();
    _writeQueue = _writeQueue.catchError((_) {}).then((_) async {
      try {
        final instance = await database;
        final result = await _runWithLockRetry(() => action(instance));
        completer.complete(result);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<T> synchronizedTransaction<T>(
    Future<T> Function(Transaction txn) action, {
    bool exclusive = false,
  }) {
    return synchronizedWrite(
      (db) => db.transaction(action, exclusive: exclusive),
    );
  }

  Future<T> _runWithLockRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 4,
  }) async {
    var attempt = 0;
    while (true) {
      attempt += 1;
      try {
        return await action();
      } catch (error) {
        final isLocked =
            error is DatabaseException &&
            error.toString().toLowerCase().contains('database is locked');
        if (!isLocked || attempt >= maxAttempts) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 120 * attempt));
      }
    }
  }
}
