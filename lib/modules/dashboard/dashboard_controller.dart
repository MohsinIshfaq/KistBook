import 'dart:async';

import 'package:get/get.dart';

import '../../core/widgets/app_loading_overlay.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/report_repository.dart';
import '../../services/access_control_service.dart';
import '../auth/auth_controller.dart';

class DashboardController extends GetxController {
  DashboardController({
    required DashboardRepository dashboardRepository,
    required ReportRepository reportRepository,
    required AccessControlService accessControlService,
    required AuthController authController,
  }) : _dashboardRepository = dashboardRepository,
       _reportRepository = reportRepository,
       _accessControlService = accessControlService,
       _authController = authController;

  final DashboardRepository _dashboardRepository;
  final ReportRepository _reportRepository;
  final AccessControlService _accessControlService;
  final AuthController _authController;

  DashboardSnapshot? snapshot;
  bool isLoading = false;
  String? reportPath;

  @override
  void onInit() {
    super.onInit();
    loadDashboard();
  }

  @override
  void onReady() {
    super.onReady();
    unawaited(
      AppLoadingOverlay.runFromGet(
        message: 'Loading profile...',
        task: _authController.fetchProfile,
      ),
    );
  }

  Future<void> loadDashboard() async {
    isLoading = true;
    update();
    snapshot = await _accessControlService.filterSnapshot(
      await _dashboardRepository.fetchSnapshot(),
    );
    isLoading = false;
    update();
  }

  Future<void> generateTodayReport() async {
    reportPath = await _reportRepository.generateDailyReport();
    update();
  }
}
