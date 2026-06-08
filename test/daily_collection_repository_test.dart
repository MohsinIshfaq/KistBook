import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kistbook/core/constants/app_enums.dart';
import 'package:kistbook/data/database/db_constants.dart';
import 'package:kistbook/data/database/db_helper.dart';
import 'package:kistbook/data/database/sync_metadata.dart';
import 'package:kistbook/data/repositories/installment_repository.dart';
import 'package:kistbook/data/repositories/payment_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  test('payment repository records partial and overpaid collections', () async {
    final fixture = await _DailyCollectionFixture.create();
    final installmentId = await fixture.insertInstallment(amount: 10000);
    final repository = PaymentRepository(fixture.dbHelper);

    await repository.addPayment(
      installmentId: installmentId,
      amount: 4000,
      paidOn: DateTime(2026, 6, 5),
      note: 'Partial collection',
    );

    var installment = await fixture.installmentRow(installmentId);
    expect(installment?['paid_amount'], 4000);
    expect(installment?['status'], InstallmentRecordStatus.partial.name);
    expect(await fixture.paymentAmounts(), [4000]);

    await repository.addPayment(
      installmentId: installmentId,
      amount: 7000,
      paidOn: DateTime(2026, 6, 5),
      note: 'Over collection',
    );

    installment = await fixture.installmentRow(installmentId);
    expect(installment?['paid_amount'], 11000);
    expect(installment?['status'], InstallmentRecordStatus.paid.name);
    expect(await fixture.paymentAmounts(), [4000, 7000]);

    await fixture.dispose();
  });

  test(
    'reschedule keeps previous due date and moves current due date',
    () async {
      final fixture = await _DailyCollectionFixture.create();
      final scheduledDate = DateTime(2026, 6, 1);
      final installmentId = await fixture.insertInstallment(
        amount: 10000,
        scheduledDueDate: scheduledDate,
        currentDueDate: scheduledDate,
      );
      final repository = InstallmentRepository(fixture.dbHelper);

      await repository.rescheduleInstallment(
        installmentId: installmentId,
        targetDate: DateTime(2026, 6, 12),
        note: 'Customer requested Friday change',
      );

      final installment = await fixture.installmentRow(installmentId);
      expect(
        DateTime.parse(installment?['scheduled_due_date'] as String),
        scheduledDate,
      );
      expect(
        DateTime.parse(installment?['current_due_date'] as String),
        DateTime(2026, 6, 13),
      );
      expect(
        DateTime.parse(installment?['previous_due_date'] as String),
        scheduledDate,
      );
      expect(
        installment?['reschedule_note'],
        'Customer requested Friday change',
      );
      expect(installment?['rescheduled_at'], isNotNull);
      expect(installment?['status'], InstallmentRecordStatus.rescheduled.name);
      expect(installment?[SyncMetadata.isSync], 0);

      await fixture.dispose();
    },
  );

  test('daily collection rows can be held for manual save sync only', () async {
    final fixture = await _DailyCollectionFixture.create();
    final installmentId = await fixture.insertInstallment(amount: 10000);
    final paymentRepository = PaymentRepository(fixture.dbHelper);
    final installmentRepository = InstallmentRepository(fixture.dbHelper);

    await paymentRepository.addPayment(
      installmentId: installmentId,
      amount: 3000,
      paidOn: DateTime(2026, 6, 5),
      note: 'Manual save only',
      manualSyncOnly: true,
    );

    var installment = await fixture.installmentRow(installmentId);
    var payment = await fixture.latestPaymentRow();
    expect(installment?['manual_sync_only'], 1);
    expect(payment?['manual_sync_only'], 1);

    await installmentRepository.rescheduleInstallment(
      installmentId: installmentId,
      targetDate: DateTime(2026, 6, 10),
      note: 'Manual reschedule',
      manualSyncOnly: true,
    );

    installment = await fixture.installmentRow(installmentId);
    expect(installment?['manual_sync_only'], 1);

    await fixture.dispose();
  });
}

class _DailyCollectionFixture {
  _DailyCollectionFixture({
    required this.directory,
    required this.dbHelper,
    required this.customerId,
    required this.planId,
  });

  final Directory directory;
  final DbHelper dbHelper;
  final int customerId;
  final int planId;

  static Future<_DailyCollectionFixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'kistbook_daily_collection_',
    );
    final dbHelper = DbHelper(databasePath: p.join(directory.path, 'test.db'));
    await dbHelper.initialize();
    final db = await dbHelper.database;
    final now = DateTime(2026, 6, 1).toIso8601String();

    final customerId = await db.insert(
      DbConstants.customers,
      SyncMetadata.withLocalChange(DbConstants.customers, {
        'card_number': 'CARD-1',
        'name': 'Daily Customer',
        'phone': '03001234567',
        'cnic': '42101-0000000-1',
        'address': 'Lahore',
        'reference_name': '',
        'created_at': now,
      }),
    );
    final planId = await db.insert(
      DbConstants.plans,
      SyncMetadata.withLocalChange(DbConstants.plans, {
        'customer_id': customerId,
        'product_id': null,
        'quantity': 1,
        'unit_price': 10000,
        'product_ids_text': '',
        'product_selections_text': '[]',
        'item_name': 'Daily Product',
        'total_amount': 10000,
        'deposit_amount': 0,
        'installment_amount': 10000,
        'installment_count': 1,
        'frequency_days': 30,
        'start_date_iso': now,
        'notes': '',
        'created_at': now,
      }),
    );

    return _DailyCollectionFixture(
      directory: directory,
      dbHelper: dbHelper,
      customerId: customerId,
      planId: planId,
    );
  }

  Future<int> insertInstallment({
    required double amount,
    DateTime? scheduledDueDate,
    DateTime? currentDueDate,
  }) async {
    final db = await dbHelper.database;
    final dueDate = scheduledDueDate ?? DateTime(2026, 6, 5);
    return db.insert(
      DbConstants.installments,
      SyncMetadata.withLocalChange(DbConstants.installments, {
        'plan_id': planId,
        'sequence_number': 1,
        'scheduled_due_date': dueDate.toIso8601String(),
        'current_due_date': (currentDueDate ?? dueDate).toIso8601String(),
        'amount': amount,
        'paid_amount': 0,
        'status': InstallmentRecordStatus.pending.name,
      }),
    );
  }

  Future<Map<String, Object?>?> installmentRow(int id) async {
    final db = await dbHelper.database;
    final rows = await db.query(
      DbConstants.installments,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<double>> paymentAmounts() async {
    final db = await dbHelper.database;
    final rows = await db.query(DbConstants.payments, orderBy: 'id ASC');
    return rows.map((row) => (row['amount'] as num).toDouble()).toList();
  }

  Future<Map<String, Object?>?> latestPaymentRow() async {
    final db = await dbHelper.database;
    final rows = await db.query(DbConstants.payments, orderBy: 'id DESC');
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> dispose() async {
    final db = await dbHelper.database;
    await db.close();
    await directory.delete(recursive: true);
  }
}
