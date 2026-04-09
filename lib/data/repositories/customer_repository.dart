import '../../data/database/db_constants.dart';
import '../../data/database/db_helper.dart';
import '../models/customer_model.dart';
import '../models/dashboard_models.dart';
import '../models/installment_model.dart';
import '../models/payment_record_model.dart';
import '../models/purchase_plan_model.dart';
import 'generic_repository.dart';
import 'sql_expression.dart';

class CustomerRepository extends GenericRepository<CustomerModel> {
  CustomerRepository(DbHelper dbHelper)
      : super(
          dbHelper: dbHelper,
          tableName: DbConstants.customers,
          fromMap: CustomerModel.fromMap,
        );

  Future<List<CustomerModel>> fetchCustomers() async {
    return getAll(orderBy: 'created_at DESC');
  }

  Future<CustomerModel> saveCustomer(CustomerModel customer) async {
    final saved = await save(customer);
    return saved.id == customer.id ? saved : customer.copyWith(id: saved.id);
  }

  Future<void> deleteCustomer(int customerId) async {
    final db = await super.db;
    await db.transaction((txn) async {
      final planRows = await txn.query(
        DbConstants.plans,
        columns: ['id'],
        where: 'customer_id = ?',
        whereArgs: [customerId],
      );
      for (final row in planRows) {
        final planId = row['id'] as int;
        await txn.delete(DbConstants.payments, where: 'plan_id = ?', whereArgs: [planId]);
        await txn.delete(
          DbConstants.installments,
          where: 'plan_id = ?',
          whereArgs: [planId],
        );
      }
      await txn.delete(DbConstants.plans, where: 'customer_id = ?', whereArgs: [customerId]);
      await txn.delete(DbConstants.customers, where: 'id = ?', whereArgs: [customerId]);
    });
  }

  Future<CustomerProfile?> fetchCustomerProfile(int customerId) async {
    final customer = await findOne(customerId);
    if (customer == null) {
      return null;
    }

    final db = await super.db;
    final plans = (await db.query(
      DbConstants.plans,
      where: SQLCondition('customer_id', '=', customerId).buildQuery(),
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    ))
        .map(PurchasePlanModel.fromMap)
        .toList();
    final payments = (await db.query(
      DbConstants.payments,
      where: SQLCondition('customer_id', '=', customerId).buildQuery(),
      whereArgs: [customerId],
      orderBy: 'paid_on DESC',
    ))
        .map(PaymentRecordModel.fromMap)
        .toList();
    final installments = <InstallmentModel>[];
    final history = <CustomerHistoryEntry>[];

    for (final plan in plans) {
      final rows = await db.query(
        DbConstants.installments,
        where: 'plan_id = ?',
        whereArgs: [plan.id],
        orderBy: 'sequence_number ASC',
      );
      installments.addAll(rows.map(InstallmentModel.fromMap));
      history.add(
        CustomerHistoryEntry(
          title: 'Purchase created',
          subtitle: plan.itemName,
          amount: plan.totalAmount,
          date: plan.createdAt,
          isCredit: false,
        ),
      );
      if (plan.depositAmount > 0) {
        history.add(
          CustomerHistoryEntry(
            title: 'Advance received',
            subtitle: plan.itemName,
            amount: plan.depositAmount,
            date: plan.createdAt,
            isCredit: true,
          ),
        );
      }
    }

    for (final payment in payments) {
      history.add(
        CustomerHistoryEntry(
          title: 'Installment payment',
          subtitle: payment.note.isEmpty ? 'Manual entry' : payment.note,
          amount: payment.amount,
          date: payment.paidOn,
          isCredit: true,
        ),
      );
    }

    history.sort((a, b) => b.date.compareTo(a.date));

    return CustomerProfile(
      customer: customer,
      plans: plans,
      installments: installments,
      payments: payments,
      history: history,
    );
  }
}
