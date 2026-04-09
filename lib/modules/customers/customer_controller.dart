import 'package:get/get.dart';

import '../../data/models/customer_model.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/installment_repository.dart';

class CustomerController extends GetxController {
  CustomerController({
    required CustomerRepository customerRepository,
    required InstallmentRepository installmentRepository,
  })  : _customerRepository = customerRepository,
        _installmentRepository = installmentRepository;

  final CustomerRepository _customerRepository;
  final InstallmentRepository _installmentRepository;

  List<CustomerModel> customers = [];
  CustomerProfile? profile;
  bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    isLoading = true;
    update();
    await _installmentRepository.reconcileInstallments();
    customers = await _customerRepository.fetchCustomers();
    isLoading = false;
    update();
  }

  Future<void> saveCustomer(CustomerModel customer) async {
    await _customerRepository.saveCustomer(customer);
    await loadCustomers();
  }

  Future<void> deleteCustomer(int customerId) async {
    await _customerRepository.deleteCustomer(customerId);
    await loadCustomers();
  }

  Future<void> loadProfile(int customerId) async {
    isLoading = true;
    update();
    profile = await _customerRepository.fetchCustomerProfile(customerId);
    isLoading = false;
    update();
  }
}
