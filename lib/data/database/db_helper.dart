import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'db_constants.dart';
import '../models/customer_model.dart';
import '../models/installment_model.dart';
import '../models/payment_record_model.dart';
import '../models/product_model.dart';
import '../models/product_price_history_model.dart';
import '../models/purchase_plan_model.dart';

class DbHelper {
  Database? _database;

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    await database;
  }

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, DbConstants.databaseName);

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
      },
    );

    return _database!;
  }

  Future<void> _createSchema(Database db) async {
    final createQueries = [
      CustomerModel.createTableQuery,
      ProductModel.createTableQuery,
      ProductPriceHistoryModel.createTableQuery,
      PurchasePlanModel.createTableQuery,
      InstallmentModel.createTableQuery,
      PaymentRecordModel.createTableQuery,
    ];

    for (final query in createQueries) {
      await db.execute(query);
    }
  }
}
