import '../database/db_constants.dart';
import '../database/db_helper.dart';
import '../models/plan_user_access_model.dart';
import 'generic_repository.dart';

class PlanUserAccessRepository extends GenericRepository<PlanUserAccessModel> {
  PlanUserAccessRepository(DbHelper dbHelper)
      : super(
          dbHelper: dbHelper,
          tableName: DbConstants.planUserAccess,
          fromMap: PlanUserAccessModel.fromMap,
        );

  Future<List<PlanUserAccessModel>> fetchForUser(String userUuid) {
    return findAllWhere('user_uuid', userUuid, orderBy: 'created_at DESC');
  }
}
