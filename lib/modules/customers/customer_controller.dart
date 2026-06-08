import 'dart:async';

import 'package:get/get.dart';

import '../../core/services/api_services.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/dashboard_models.dart';
import '../../data/repositories/customer_plan_refresh_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/installment_repository.dart';
import '../../services/access_control_service.dart';
import '../../services/background_service.dart';
import '../../services/sync_change_notifier.dart';

class CustomerController extends GetxController {
  CustomerController({
    required CustomerRepository customerRepository,
    required InstallmentRepository installmentRepository,
    required AccessControlService accessControlService,
    required CustomerPlanRefreshRepository planRefreshRepository,
  }) : _customerRepository = customerRepository,
       _installmentRepository = installmentRepository,
       _accessControlService = accessControlService,
       _planRefreshRepository = planRefreshRepository;

  final CustomerRepository _customerRepository;
  final InstallmentRepository _installmentRepository;
  final AccessControlService _accessControlService;
  final CustomerPlanRefreshRepository _planRefreshRepository;

  List<CustomerModel> customers = [];
  List<CustomerModel> filteredCustomers = [];
  CustomerProfile? profile;
  bool isLoading = false;
  bool isRefreshingProfile = false;
  String? profileRefreshError;
  String searchQuery = '';
  StreamSubscription<SyncResource>? _syncSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenForSyncChanges();
    loadCustomers();
  }

  @override
  void onClose() {
    _syncSubscription?.cancel();
    super.onClose();
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
    _requestSync();
    await loadCustomers();
  }

  Future<void> deleteCustomer(int customerId) async {
    await _customerRepository.deleteCustomer(customerId);
    _requestSync();
    await loadCustomers();
  }

  Future<void> loadProfile(int customerId, {bool refreshRemote = true}) async {
    isLoading = profile == null;
    profileRefreshError = null;
    update();
    profile = await _customerRepository.fetchCustomerProfile(customerId);
    isLoading = false;
    update();
    if (refreshRemote && profile != null) {
      unawaited(refreshProfilePlans(customerId));
    }
  }

  Future<void> refreshProfilePlans(int customerId) async {
    if (isRefreshingProfile) {
      return;
    }
    isRefreshingProfile = true;
    profileRefreshError = null;
    update();
    try {
      final result = await _planRefreshRepository.refreshCustomerPlans(
        customerId,
      );
      if (result.didRefresh) {
        profile = await _customerRepository.fetchCustomerProfile(customerId);
      }
    } on ApiException catch (error) {
      profileRefreshError = error.message;
    } catch (_) {
      profileRefreshError =
          'Unable to refresh plan details. Showing saved local data.'.tr;
    } finally {
      isRefreshingProfile = false;
      update();
    }
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

  void _requestSync() {
    if (Get.isRegistered<BackgroundService>()) {
      Get.find<BackgroundService>().requestSync();
    }
  }

  void _listenForSyncChanges() {
    if (!Get.isRegistered<SyncChangeNotifier>()) {
      return;
    }
    _syncSubscription = Get.find<SyncChangeNotifier>().stream.listen((
      resource,
    ) {
      if (resource == SyncResource.customers && !isLoading) {
        unawaited(loadCustomers());
      }
    });
  }
}
