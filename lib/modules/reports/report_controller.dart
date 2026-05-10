import 'package:get/get.dart';

import '../../data/models/dashboard_models.dart';
import '../../data/repositories/report_repository.dart';
import '../../services/access_control_service.dart';

class ReportController extends GetxController {
  ReportController({
    required ReportRepository reportRepository,
    required AccessControlService accessControlService,
  })  : _reportRepository = reportRepository,
        _accessControlService = accessControlService;

  final ReportRepository _reportRepository;
  final AccessControlService _accessControlService;

  List<DueInstallmentDetail> dueItems = [];
  String? reportPath;
  bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    loadDueItems();
  }

  Future<void> loadDueItems() async {
    isLoading = true;
    update();
    dueItems = await _accessControlService.filterDueInstallments(
      await _reportRepository.fetchDueInstallments(),
    );
    isLoading = false;
    update();
  }

  Future<void> generateReport() async {
    reportPath = await _reportRepository.generateDailyReport();
    await loadDueItems();
  }
}
