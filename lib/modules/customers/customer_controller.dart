import 'package:get/get.dart';

import '../../data/models/customer_model.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/installment_repository.dart';
import '../../services/access_control_service.dart';

class CustomerController extends GetxController {
  CustomerController({
    required CustomerRepository customerRepository,
    required InstallmentRepository installmentRepository,
    required AccessControlService accessControlService,
  })  : _customerRepository = customerRepository,
        _installmentRepository = installmentRepository,
        _accessControlService = accessControlService;

  final CustomerRepository _customerRepository;
  final InstallmentRepository _installmentRepository;
  final AccessControlService _accessControlService;

  List<CustomerModel> customers = [];
  List<CustomerModel> filteredCustomers = [];
  CustomerProfile? profile;
  bool isLoading = false;
  String searchQuery = '';

  @override
  void onInit() {
    super.onInit();
    loadCustomers();
  }

  Future<void> loadCustomers() async {
    isLoading = true;
    update();
    await _installmentRepository.reconcileInstallments();
    customers = await _accessControlService.filterCustomers(
      await _customerRepository.fetchCustomers(),
    );
    _applyFilters();
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

  void setSearchQuery(String value) {
    searchQuery = value.trim();
    _applyFilters();
    update();
  }

  void clearSearch() {
    searchQuery = '';
    _applyFilters();
    update();
  }

  void _applyFilters() {
    if (searchQuery.isEmpty) {
      filteredCustomers = List<CustomerModel>.from(customers);
      return;
    }

    final query = searchQuery.toLowerCase();
    filteredCustomers = customers.where((customer) {
      final name = customer.name.toLowerCase();
      final cardNumber = customer.cardNumber.toLowerCase();
      return name.contains(query) || cardNumber.contains(query);
    }).toList();
  }
}
