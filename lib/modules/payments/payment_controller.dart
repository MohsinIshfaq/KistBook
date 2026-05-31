import 'package:get/get.dart';

import '../../data/models/dashboard_models.dart';
import '../../data/models/payment_record_model.dart';
import '../../data/repositories/installment_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../services/access_control_service.dart';
import '../../services/background_service.dart';

class PaymentController extends GetxController {
  PaymentController({
    required PaymentRepository paymentRepository,
    required InstallmentRepository installmentRepository,
    required AccessControlService accessControlService,
  }) : _paymentRepository = paymentRepository,
       _installmentRepository = installmentRepository,
       _accessControlService = accessControlService;

  final PaymentRepository _paymentRepository;
  final InstallmentRepository _installmentRepository;
  final AccessControlService _accessControlService;

  List<PaymentRecordModel> payments = [];
  List<DueInstallmentDetail> dueInstallments = [];
  bool isLoading = false;
  bool isSubmittingPayment = false;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading = true;
    update();
    payments = await _accessControlService.filterPayments(
      await _paymentRepository.fetchPayments(),
    );
    dueInstallments = await _accessControlService.filterDueInstallments(
      await _installmentRepository.fetchActiveInstallments(),
    );
    isLoading = false;
    update();
  }

  Future<void> addPayment({
    required int installmentId,
    required double amount,
    required DateTime paidOn,
    required String note,
  }) async {
    if (isSubmittingPayment) {
      return;
    }
    isSubmittingPayment = true;
    update();
    try {
      await _paymentRepository.addPayment(
        installmentId: installmentId,
        amount: amount,
        paidOn: paidOn,
        note: note,
      );
      _requestSync();
      await loadData();
    } finally {
      isSubmittingPayment = false;
      update();
    }
  }

  void _requestSync() {
    if (Get.isRegistered<BackgroundService>()) {
      Get.find<BackgroundService>().requestSync();
    }
  }
}
