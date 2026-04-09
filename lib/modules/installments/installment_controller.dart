import 'dart:math';

import 'package:get/get.dart';

import '../../core/utils/date_helper.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/product_model.dart';
import '../../data/models/purchase_plan_model.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/installment_repository.dart';
import '../../data/repositories/product_repository.dart';

class InstallmentController extends GetxController {
  InstallmentController({
    required InstallmentRepository installmentRepository,
    required CustomerRepository customerRepository,
    required ProductRepository productRepository,
  })  : _installmentRepository = installmentRepository,
        _customerRepository = customerRepository,
        _productRepository = productRepository;

  final InstallmentRepository _installmentRepository;
  final CustomerRepository _customerRepository;
  final ProductRepository _productRepository;

  List<DueInstallmentDetail> installments = [];
  List<CustomerModel> customers = [];
  List<ProductModel> products = [];
  bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading = true;
    update();
    customers = await _customerRepository.fetchCustomers();
    products = await _productRepository.fetchProducts();
    installments = await _installmentRepository.fetchActiveInstallments();
    isLoading = false;
    update();
  }

  Future<void> createPlan({
    required int customerId,
    required ProductModel? product,
    required String itemName,
    required double totalAmount,
    required double depositAmount,
    required double installmentAmount,
    required int frequencyDays,
    required DateTime startDate,
    required String notes,
  }) async {
    final financedAmount = max(0.0, totalAmount - depositAmount);
    final installmentCount = financedAmount <= 0
        ? 0
        : max(1, (financedAmount / installmentAmount).ceil());

    await _installmentRepository.createPlan(
      PurchasePlanModel(
        customerId: customerId,
        productId: product?.id,
        itemName: itemName,
        totalAmount: totalAmount,
        depositAmount: depositAmount,
        installmentAmount: installmentAmount,
        installmentCount: installmentCount,
        frequencyDays: frequencyDays,
        startDate: DateHelper.shiftFridayToSaturday(startDate),
        notes: notes,
        createdAt: DateTime.now(),
      ),
    );
    await loadData();
  }
}
