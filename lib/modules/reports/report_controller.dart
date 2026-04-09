import 'package:get/get.dart';

import '../../data/models/dashboard_models.dart';
import '../../data/repositories/report_repository.dart';

class ReportController extends GetxController {
  ReportController({required ReportRepository reportRepository})
      : _reportRepository = reportRepository;

  final ReportRepository _reportRepository;

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
    dueItems = await _reportRepository.fetchDueInstallments();
    isLoading = false;
    update();
  }

  Future<void> generateReport() async {
    reportPath = await _reportRepository.generateDailyReport();
    await loadDueItems();
  }
}
