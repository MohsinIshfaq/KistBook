import 'package:get/get.dart';

import '../../core/services/api_services.dart';
import '../../data/database/db_helper.dart';
import '../../data/datasources/customer_remote_data_source.dart';
import '../../data/datasources/installment_plan_remote_data_source.dart';
import '../../data/datasources/product_remote_data_source.dart';
import '../../data/datasources/runtime_bootstrap_remote_data_source.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/customer_plan_refresh_repository.dart';
import '../../data/repositories/customer_sync_repository.dart';
import '../../data/repositories/customer_user_access_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/installment_plan_sync_repository.dart';
import '../../data/repositories/installment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/plan_user_access_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/product_sync_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../data/repositories/runtime_bootstrap_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/sync/sync_cursor_store.dart';
import '../../domain/usecases/customer_sync_use_case.dart';
import '../../domain/usecases/installment_plan_sync_use_case.dart';
import '../../domain/usecases/product_sync_use_case.dart';
import '../../services/access_control_service.dart';
import '../../services/auth_api_service.dart';
import '../../services/background_service.dart';
import '../../services/notification_service.dart';
import '../../services/session_manager.dart';
import '../../services/sync_change_notifier.dart';
import '../../services/sync_service.dart';
import '../../modules/auth/auth_controller.dart';
import '../../modules/settings/settings_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(DbHelper(), permanent: true);
    Get.put(CustomerRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(
      CustomerUserAccessRepository(Get.find<DbHelper>()),
      permanent: true,
    );
    Get.put(ProductRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(UserRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(InstallmentRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(PaymentRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(PlanUserAccessRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(DashboardRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(ReportRepository(Get.find<DbHelper>()), permanent: true);
    Get.put(NotificationService(), permanent: true);
    Get.find<SessionManager>();
    Get.put(
      ApiServices(sessionManager: Get.find<SessionManager>()),
      permanent: true,
    );
    Get.put(AuthRepository(Get.find<ApiServices>()), permanent: true);
    Get.put(AuthApiService(Get.find<AuthRepository>()), permanent: true);
    Get.put(SyncCursorStore(), permanent: true);
    Get.put(SyncChangeNotifier(), permanent: true);
    Get.put(CustomerRemoteDataSource(Get.find<ApiServices>()), permanent: true);
    Get.put(ProductRemoteDataSource(Get.find<ApiServices>()), permanent: true);
    Get.put(
      InstallmentPlanRemoteDataSource(Get.find<ApiServices>()),
      permanent: true,
    );
    Get.put(
      RuntimeBootstrapRemoteDataSource(Get.find<ApiServices>()),
      permanent: true,
    );
    Get.put(
      CustomerSyncRepository(
        dbHelper: Get.find<DbHelper>(),
        remoteDataSource: Get.find<CustomerRemoteDataSource>(),
        cursorStore: Get.find<SyncCursorStore>(),
        changeNotifier: Get.find<SyncChangeNotifier>(),
      ),
      permanent: true,
    );
    Get.put(
      ProductSyncRepository(
        dbHelper: Get.find<DbHelper>(),
        remoteDataSource: Get.find<ProductRemoteDataSource>(),
        cursorStore: Get.find<SyncCursorStore>(),
        changeNotifier: Get.find<SyncChangeNotifier>(),
      ),
      permanent: true,
    );
    Get.put(
      InstallmentPlanSyncRepository(
        dbHelper: Get.find<DbHelper>(),
        remoteDataSource: Get.find<InstallmentPlanRemoteDataSource>(),
        cursorStore: Get.find<SyncCursorStore>(),
        changeNotifier: Get.find<SyncChangeNotifier>(),
      ),
      permanent: true,
    );
    Get.put(
      CustomerPlanRefreshRepository(
        customerRepository: Get.find<CustomerRepository>(),
        remoteDataSource: Get.find<CustomerRemoteDataSource>(),
        productSyncRepository: Get.find<ProductSyncRepository>(),
        installmentPlanSyncRepository:
            Get.find<InstallmentPlanSyncRepository>(),
      ),
      permanent: true,
    );
    Get.put(
      RuntimeBootstrapRepository(
        dbHelper: Get.find<DbHelper>(),
        remoteDataSource: Get.find<RuntimeBootstrapRemoteDataSource>(),
        customerSyncRepository: Get.find<CustomerSyncRepository>(),
        productSyncRepository: Get.find<ProductSyncRepository>(),
        installmentPlanSyncRepository:
            Get.find<InstallmentPlanSyncRepository>(),
        changeNotifier: Get.find<SyncChangeNotifier>(),
      ),
      permanent: true,
    );
    Get.put(
      CustomerSyncUseCase(Get.find<CustomerSyncRepository>()),
      permanent: true,
    );
    Get.put(
      ProductSyncUseCase(Get.find<ProductSyncRepository>()),
      permanent: true,
    );
    Get.put(
      InstallmentPlanSyncUseCase(Get.find<InstallmentPlanSyncRepository>()),
      permanent: true,
    );
    Get.put(
      SyncService(
        dbHelper: Get.find<DbHelper>(),
        sessionManager: Get.find<SessionManager>(),
        customerSyncUseCase: Get.find<CustomerSyncUseCase>(),
        productSyncUseCase: Get.find<ProductSyncUseCase>(),
        installmentPlanSyncUseCase: Get.find<InstallmentPlanSyncUseCase>(),
      ),
      permanent: true,
    );
    Get.put(
      AccessControlService(
        sessionManager: Get.find<SessionManager>(),
        customerAccessRepository: Get.find<CustomerUserAccessRepository>(),
        planAccessRepository: Get.find<PlanUserAccessRepository>(),
        dbHelper: Get.find<DbHelper>(),
      ),
      permanent: true,
    );
    Get.find<SettingsController>().load();
    Get.put(
      BackgroundService(
        reportRepository: Get.find<ReportRepository>(),
        notificationService: Get.find<NotificationService>(),
        syncService: Get.find<SyncService>(),
      ),
      permanent: true,
    );
    Get.lazyPut(
      () => AuthController(
        userRepository: Get.find<UserRepository>(),
        sessionManager: Get.find<SessionManager>(),
        authApiService: Get.find<AuthApiService>(),
        dbHelper: Get.find<DbHelper>(),
        syncCursorStore: Get.find<SyncCursorStore>(),
        runtimeBootstrapRepository: Get.find<RuntimeBootstrapRepository>(),
      ),
      fenix: true,
    );
  }
}
