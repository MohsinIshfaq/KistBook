import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kistbook/core/constants/app_enums.dart';
import 'package:kistbook/data/database/db_constants.dart';
import 'package:kistbook/data/database/db_helper.dart';
import 'package:kistbook/data/database/sync_metadata.dart';
import 'package:kistbook/data/models/local_user_model.dart';
import 'package:kistbook/data/repositories/user_repository.dart';
import 'package:path/path.dart' as p;

void main() {
  test('plan assigned to one salesman cannot be assigned to another', () async {
    final fixture = await _UserAssignmentFixture.create();
    final salesOne = await fixture.insertSalesman('Sales One');
    final salesTwo = await fixture.insertSalesman('Sales Two');
    final planId = await fixture.insertPlan();
    await fixture.repository.saveAssignments(
      userUuid: salesOne.uuid,
      customerIds: const [],
      planIds: [planId],
    );

    final assignees = await fixture.repository.fetchActivePlanAssignees(
      exceptUserUuid: salesTwo.uuid,
    );

    expect(assignees[planId], salesOne.uuid);
    await expectLater(
      fixture.repository.saveAssignments(
        userUuid: salesTwo.uuid,
        customerIds: const [],
        planIds: [planId],
      ),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('already assigned'),
        ),
      ),
    );
    await fixture.dispose();
  });
}

class _UserAssignmentFixture {
  _UserAssignmentFixture({
    required this.directory,
    required this.dbHelper,
    required this.repository,
  });

  final Directory directory;
  final DbHelper dbHelper;
  final UserRepository repository;

  static Future<_UserAssignmentFixture> create() async {
    final directory = await Directory.systemTemp.createTemp(
      'kistbook_user_assignment_',
    );
    final dbHelper = DbHelper(databasePath: p.join(directory.path, 'test.db'));
    await dbHelper.initialize();
    return _UserAssignmentFixture(
      directory: directory,
      dbHelper: dbHelper,
      repository: UserRepository(dbHelper),
    );
  }

  Future<LocalUserModel> insertSalesman(String name) async {
    final parts = name.split(' ');
    final user = LocalUserModel(
      uuid: 'local-${name.toLowerCase().replaceAll(' ', '-')}',
      phone:
          '0300${name.hashCode.abs().toString().padLeft(7, '0').substring(0, 7)}',
      email: '${name.toLowerCase().replaceAll(' ', '.')}@example.com',
      password: 'password',
      firstName: parts.first,
      lastName: parts.length > 1 ? parts.last : '',
      role: UserRole.salesMan,
      isActive: true,
      isSync: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    return repository.saveUser(user);
  }

  Future<int> insertPlan() async {
    final db = await dbHelper.database;
    final customerId = await db.insert(
      DbConstants.customers,
      SyncMetadata.withServerChange(DbConstants.customers, {
        'card_number': 'CARD-1',
        'name': 'Customer',
        'phone': '03001234567',
        'cnic': '42101-0000000-1',
        'address': 'Lahore',
        'reference_name': '',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    final productId = await db.insert(
      DbConstants.products,
      SyncMetadata.withServerChange(DbConstants.products, {
        'categories_text': '[]',
        'brand_name': '',
        'name': 'Product',
        'sku': '',
        'sale_price': 10000,
        'notes': '',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
    return db.insert(
      DbConstants.plans,
      SyncMetadata.withServerChange(DbConstants.plans, {
        'customer_id': customerId,
        'product_id': productId,
        'quantity': 1,
        'unit_price': 10000,
        'product_ids_text': '$productId',
        'product_selections_text': '[{"product_id":$productId,"quantity":1}]',
        'item_name': 'Product x1',
        'total_amount': 10000,
        'deposit_amount': 1000,
        'installment_amount': 3000,
        'installment_count': 3,
        'frequency_days': 30,
        'start_date_iso': '2026-06-01T00:00:00.000Z',
        'notes': '',
        'created_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  Future<void> dispose() async {
    final db = await dbHelper.database;
    await db.close();
    await directory.delete(recursive: true);
  }
}
