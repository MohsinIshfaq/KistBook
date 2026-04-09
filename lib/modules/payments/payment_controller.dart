import 'package:get/get.dart';

import '../../data/models/dashboard_models.dart';
import '../../data/models/payment_record_model.dart';
import '../../data/repositories/installment_repository.dart';
import '../../data/repositories/payment_repository.dart';

class PaymentController extends GetxController {
  PaymentController({
    required PaymentRepository paymentRepository,
    required InstallmentRepository installmentRepository,
  })  : _paymentRepository = paymentRepository,
        _installmentRepository = installmentRepository;

  final PaymentRepository _paymentRepository;
  final InstallmentRepository _installmentRepository;

  List<PaymentRecordModel> payments = [];
  List<DueInstallmentDetail> dueInstallments = [];
  bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading = true;
    update();
    payments = await _paymentRepository.fetchPayments();
    dueInstallments = await _installmentRepository.fetchActiveInstallments();
    isLoading = false;
    update();
  }

  Future<void> addPayment({
    required int installmentId,
    required double amount,
    required DateTime paidOn,
    required String note,
  }) async {
    await _paymentRepository.addPayment(
      installmentId: installmentId,
      amount: amount,
      paidOn: paidOn,
      note: note,
    );
    await loadData();
  }
}
