import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../models/customer_user_access_model.dart';
import 'generic_repository.dart';

class CustomerUserAccessRepository extends GenericRepository<CustomerUserAccessModel> {
  CustomerUserAccessRepository(DbHelper dbHelper)
      : super(
          dbHelper: dbHelper,
          tableName: DbConstants.customerUserAccess,
          fromMap: CustomerUserAccessModel.fromMap,
        );

  Future<List<CustomerUserAccessModel>> fetchForUser(String userUuid) {
    return findAllWhere('user_uuid', userUuid, orderBy: 'created_at DESC');
  }
}
