import 'package:get/get.dart';

import '../../core/constants/app_enums.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/local_user_model.dart';
import '../../data/models/purchase_plan_model.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/installment_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../core/utils/id_generator.dart';
import '../../services/background_service.dart';
import '../../services/auth_api_service.dart';

class UserController extends GetxController {
  UserController({
    required UserRepository userRepository,
    required CustomerRepository customerRepository,
    required InstallmentRepository installmentRepository,
    required AuthApiService authApiService,
  }) : _userRepository = userRepository,
       _customerRepository = customerRepository,
       _installmentRepository = installmentRepository,
       _authApiService = authApiService;

  final UserRepository _userRepository;
  final CustomerRepository _customerRepository;
  final InstallmentRepository _installmentRepository;
  final AuthApiService _authApiService;

  List<LocalUserModel> users = [];
  List<CustomerModel> customers = [];
  List<PurchasePlanModel> plans = [];
  Set<int> assignedCustomerIds = <int>{};
  Set<int> assignedPlanIds = <int>{};
  bool isLoading = false;

  @override
  void onInit() {
    super.onInit();
    loadUsers();
  }

  Future<void> loadUsers() async {
    isLoading = true;
    update();
    users = await _userRepository.fetchUsers();
    users = users.where((item) => item.role != UserRole.owner).toList();
    isLoading = false;
    update();
  }

  Future<void> loadFormData({LocalUserModel? user}) async {
    assignedCustomerIds = {};
    assignedPlanIds = {};
    update();
  }

  Future<void> loadAssignmentData({required LocalUserModel user}) async {
    isLoading = true;
    update();
    customers = await _customerRepository.fetchCustomers();
    plans = await _installmentRepository.fetchAllPlans();

    assignedCustomerIds = {};
    assignedPlanIds = {};
    final customerAccess = await _userRepository.fetchCustomerAccess(user.uuid);
    final planAccess = await _userRepository.fetchPlanAccess(user.uuid);
    assignedCustomerIds = customerAccess
        .map((item) => int.tryParse(item.customerUuid))
        .whereType<int>()
        .toSet();
    assignedPlanIds = planAccess
        .map((item) => int.tryParse(item.planUuid))
        .whereType<int>()
        .toSet();
    isLoading = false;
    update();
  }

  void toggleCustomer(int customerId) {
    if (assignedCustomerIds.contains(customerId)) {
      assignedCustomerIds.remove(customerId);
    } else {
      assignedCustomerIds.add(customerId);
    }
    update();
  }

  void togglePlan(int planId) {
    if (assignedPlanIds.contains(planId)) {
      assignedPlanIds.remove(planId);
    } else {
      assignedPlanIds.add(planId);
    }
    update();
  }

  void toggleAllPlansForCustomer(int customerId) {
    final customerPlanIds = plans
        .where((item) => item.customerId == customerId && item.id != null)
        .map((item) => item.id!)
        .toList();
    final allSelected =
        customerPlanIds.isNotEmpty &&
        customerPlanIds.every(assignedPlanIds.contains);
    if (allSelected) {
      assignedPlanIds.removeAll(customerPlanIds);
    } else {
      assignedPlanIds.addAll(customerPlanIds);
    }
    update();
  }

  Future<void> saveUser({
    LocalUserModel? existing,
    required String phone,
    required String email,
    required String password,
    required String passwordConfirmation,
    required String firstName,
    required String lastName,
  }) async {
    final existingPhoneUser = await _userRepository.findByPhone(phone);
    if (existingPhoneUser != null && existingPhoneUser.uuid != existing?.uuid) {
      throw StateError('Phone number already exists');
    }
    final existingEmailUser = await _userRepository.findByEmail(email);
    if (existingEmailUser != null && existingEmailUser.uuid != existing?.uuid) {
      throw StateError('Email address already exists');
    }
    isLoading = true;
    update();
    try {
      final now = DateTime.now();
      var uuid = existing?.uuid ?? IdGenerator.localUuid();
      var isSync = false;
      if (existing == null) {
        final remote = await _authApiService.createCompanyUser(
          name: '$firstName $lastName'.trim(),
          email: email,
          phone: phone,
          password: password,
          passwordConfirmation: passwordConfirmation,
        );
        uuid = remote.serverId.isEmpty ? uuid : remote.serverId;
        isSync = true;
      }
      final user = LocalUserModel(
        id: existing?.id,
        uuid: uuid,
        phone: phone,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        role: UserRole.salesMan,
        isActive: true,
        isSync: isSync,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      await _userRepository.saveUser(user);
      _requestSync();
      await loadUsers();
    } finally {
      isLoading = false;
      update();
    }
  }

  Future<void> deleteUser(int userId) async {
    await _userRepository.deleteUser(userId);
    _requestSync();
    await loadUsers();
  }

  String customerNameForPlan(PurchasePlanModel plan) {
    for (final customer in customers) {
      if (customer.id == plan.customerId) {
        return customer.name;
      }
    }
    return 'Customer ${plan.customerId}';
  }

  List<PurchasePlanModel> plansForCustomer(int customerId) {
    return plans.where((item) => item.customerId == customerId).toList();
  }

  bool isAllPlansAssignedForCustomer(int customerId) {
    final customerPlanIds = plansForCustomer(
      customerId,
    ).where((item) => item.id != null).map((item) => item.id!).toList();
    if (customerPlanIds.isEmpty) {
      return false;
    }
    return customerPlanIds.every(assignedPlanIds.contains);
  }

  Future<void> saveAssignmentsForUser(LocalUserModel user) async {
    await _userRepository.saveAssignments(
      userUuid: user.uuid,
      customerIds: assignedCustomerIds.toList(),
      planIds: assignedPlanIds.toList(),
    );
    _requestSync();
  }

  void _requestSync() {
    if (Get.isRegistered<BackgroundService>()) {
      Get.find<BackgroundService>().requestSync();
    }
  }
}
