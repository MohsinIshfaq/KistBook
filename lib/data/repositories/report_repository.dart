import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../core/utils/date_helper.dart';
import '../../modules/reports/pdf_generator.dart';
import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../models/customer_model.dart';
import '../models/dashboard_models.dart';
import '../models/installment_model.dart';
import '../models/product_model.dart';
import '../models/purchase_plan_model.dart';

class ReportRepository {
  ReportRepository(this._dbHelper);

  final DbHelper _dbHelper;

  Future<Database> get _db async => _dbHelper.database;

  Future<List<DueInstallmentDetail>> fetchDueInstallments({DateTime? date}) async {
    final db = await _db;
    final targetDate = DateHelper.startOfDay(date ?? DateTime.now());
    final customerRows = await db.query(DbConstants.customers);
    final productRows = await db.query(DbConstants.products);
    final planRows = await db.query(DbConstants.plans);
    final installmentRows = await db.query(DbConstants.installments);

    final customers = {
      for (final row in customerRows) (row['id'] as int): CustomerModel.fromMap(row),
    };
    final products = {
      for (final row in productRows) (row['id'] as int): ProductModel.fromMap(row),
    };
    final plans = {
      for (final row in planRows) (row['id'] as int): PurchasePlanModel.fromMap(row),
    };

    final dueItems = <DueInstallmentDetail>[];
    for (final row in installmentRows) {
      final installment = InstallmentModel.fromMap(row);
      if (installment.isPaid ||
          DateHelper.startOfDay(installment.currentDueDate) != targetDate) {
        continue;
      }
      final plan = plans[installment.planId];
      final customer = plan == null ? null : customers[plan.customerId];
      if (plan == null || customer == null) {
        continue;
      }
      dueItems.add(
        DueInstallmentDetail(
          customer: customer,
          plan: plan,
          installment: installment,
          product: plan.productId == null ? null : products[plan.productId!],
        ),
      );
    }
    return dueItems;
  }

  Future<String> generateDailyReport({DateTime? date}) async {
    final targetDate = DateHelper.startOfDay(date ?? DateTime.now());
    final dueItems = await fetchDueInstallments(date: targetDate);
    final bytes = await PdfGenerator.buildDueInstallmentReport(
      date: targetDate,
      dueItems: dueItems,
    );
    final directory = await getApplicationDocumentsDirectory();
    final reportsDir = Directory(p.join(directory.path, 'reports'));
    await reportsDir.create(recursive: true);
    final path = p.join(
      reportsDir.path,
      'due_report_${targetDate.toIso8601String().split('T').first}.pdf',
    );
    await File(path).writeAsBytes(bytes);
    return path;
  }
}
