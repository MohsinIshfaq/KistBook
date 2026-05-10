import 'dart:math';

import 'package:get/get.dart';

import '../../core/utils/date_helper.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/models/purchase_plan_model.dart';
import '../../data/models/product_model.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/installment_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../services/access_control_service.dart';

class InstallmentController extends GetxController {
  InstallmentController({
    required InstallmentRepository installmentRepository,
    required CustomerRepository customerRepository,
    required ProductRepository productRepository,
    required AccessControlService accessControlService,
  })  : _installmentRepository = installmentRepository,
        _customerRepository = customerRepository,
        _productRepository = productRepository,
        _accessControlService = accessControlService;

  final InstallmentRepository _installmentRepository;
  final CustomerRepository _customerRepository;
  final ProductRepository _productRepository;
  final AccessControlService _accessControlService;

  List<DueInstallmentDetail> installments = [];
  List<CustomerModel> customers = [];
  List<ProductModel> products = [];
  Map<int, CustomerPaymentInsight> customerInsights = {};
  bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  Future<void> loadData() async {
    isLoading = true;
    update();
    customers = await _accessControlService.filterCustomers(
      await _customerRepository.fetchCustomers(),
    );
    products = await _productRepository.fetchProducts();
    installments = await _accessControlService.filterDueInstallments(
      await _installmentRepository.fetchActiveInstallments(),
    );
    customerInsights = await _customerRepository.fetchCustomerPaymentInsights();
    isLoading = false;
    update();
  }

  Future<void> createPlan({
    required int customerId,
    required List<CreatePlanProductInput> products,
    required String notes,
  }) async {
    for (final productInput in products) {
      final financedAmount = max(0.0, productInput.totalAmount - productInput.depositAmount);
      final installmentCount = financedAmount <= 0
          ? 0
          : max(1, (financedAmount / productInput.installmentAmount).ceil());

      await _installmentRepository.createPlan(
        PurchasePlanModel(
          customerId: customerId,
          productId: productInput.product.id,
          quantity: productInput.quantity,
          unitPrice: productInput.product.salePrice,
          productIds: [productInput.product.id!],
          productSelections: [
            PlanProductSelection(
              productId: productInput.product.id!,
              quantity: productInput.quantity,
            ),
          ],
          itemName: productInput.itemName,
          totalAmount: productInput.totalAmount,
          depositAmount: productInput.depositAmount,
          installmentAmount: productInput.installmentAmount,
          installmentCount: installmentCount,
          frequencyDays: productInput.frequencyDays,
          startDate: DateHelper.shiftFridayToSaturday(productInput.startDate),
          notes: notes,
          createdAt: DateTime.now(),
        ),
      );
    }
    await loadData();
  }

  Future<InstallmentPlanSummary?> updatePlan(PurchasePlanModel plan) async {
    await _installmentRepository.updatePlanConfiguration(plan);
    await loadData();
    if (plan.id == null) {
      return null;
    }
    return _installmentRepository.fetchPlanSummary(plan.id!);
  }
}

class CreatePlanProductInput {
  const CreatePlanProductInput({
    required this.product,
    required this.quantity,
    required this.itemName,
    required this.totalAmount,
    required this.depositAmount,
    required this.installmentAmount,
    required this.frequencyDays,
    required this.startDate,
  });

  final ProductModel product;
  final int quantity;
  final String itemName;
  final double totalAmount;
  final double depositAmount;
  final double installmentAmount;
  final int frequencyDays;
  final DateTime startDate;
}
