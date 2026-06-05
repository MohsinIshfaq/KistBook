import 'package:get/get.dart';

import '../../core/constants/app_enums.dart';
import '../../data/models/customer_model.dart';
import '../../data/models/local_user_model.dart';
import '../../data/models/purchase_plan_model.dart';
import '../../data/datasources/access_assignment_remote_data_source.dart';
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
    required AccessAssignmentRemoteDataSource accessAssignmentRemoteDataSource,
  }) : _userRepository = userRepository,
       _customerRepository = customerRepository,
       _installmentRepository = installmentRepository,
       _authApiService = authApiService,
       _accessAssignmentRemoteDataSource = accessAssignmentRemoteDataSource;

  final UserRepository _userRepository;
  final CustomerRepository _customerRepository;
  final InstallmentRepository _installmentRepository;
  final AuthApiService _authApiService;
  final AccessAssignmentRemoteDataSource _accessAssignmentRemoteDataSource;

  List<LocalUserModel> users = [];
  List<CustomerModel> customers = [];
  List<PurchasePlanModel> plans = [];
  Set<int> assignedCustomerIds = <int>{};
  Set<int> assignedPlanIds = <int>{};
  Map<int, String> planAssigneesByPlanId = {};
  LocalUserModel? assignmentUser;
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
    assignmentUser = user;
    users = await _userRepository.fetchUsers();
    users = users.where((item) => item.role != UserRole.owner).toList();
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
    planAssigneesByPlanId = await _userRepository.fetchActivePlanAssignees(
      exceptUserUuid: user.uuid,
    );
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
    if (isPlanAssignedToAnotherUser(planId)) {
      return;
    }
    if (assignedPlanIds.contains(planId)) {
      assignedPlanIds.remove(planId);
    } else {
      assignedPlanIds.add(planId);
    }
    update();
  }

  void toggleAllPlansForCustomer(int customerId) {
    final customerPlanIds = plansForCustomer(
      customerId,
    ).where((item) => item.id != null).map((item) => item.id!).toList();
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
    return plans
        .where(
          (item) =>
              item.customerId == customerId &&
              (item.id == null || !isPlanAssignedToAnotherUser(item.id!)),
        )
        .toList();
  }

  int hiddenAssignedPlanCountForCustomer(int customerId) {
    return plans
        .where(
          (item) =>
              item.customerId == customerId &&
              item.id != null &&
              isPlanAssignedToAnotherUser(item.id!),
        )
        .length;
  }

  bool isPlanAssignedToAnotherUser(int planId) {
    return planAssigneesByPlanId.containsKey(planId);
  }

  String? planAssignedUserName(int planId) {
    final userUuid = planAssigneesByPlanId[planId];
    if (userUuid == null) {
      return null;
    }
    for (final user in users) {
      if (user.uuid == userUuid) {
        return user.fullName;
      }
    }
    return 'another salesman';
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
    final blockedPlanIds = assignedPlanIds
        .where(isPlanAssignedToAnotherUser)
        .toList();
    if (blockedPlanIds.isNotEmpty) {
      final names = blockedPlanIds
          .map((planId) => planAssignedUserName(planId) ?? 'another salesman')
          .toSet()
          .join(', ');
      throw StateError(
        'Selected plan is already assigned to $names. Remove it from that user first.',
      );
    }
    isLoading = true;
    update();
    try {
      final customerIds = assignedCustomerIds.toList();
      final planIds = assignedPlanIds.toList();
      final result = await _accessAssignmentRemoteDataSource.replaceAssignments(
        userId: await _userRepository.serverIdForUserUuid(user.uuid),
        customerIds: await _userRepository.customerServerIdsForLocalIds(
          customerIds,
        ),
        planIds: await _userRepository.planServerIdsForLocalIds(planIds),
      );
      await _userRepository.replaceAssignmentsFromServer(
        userUuid: user.uuid,
        customerAccess: result.customerAccess,
        planAccess: result.planAccess,
      );
      assignedCustomerIds = customerIds.toSet();
      assignedPlanIds = planIds.toSet();
      planAssigneesByPlanId = await _userRepository.fetchActivePlanAssignees(
        exceptUserUuid: user.uuid,
      );
    } finally {
      isLoading = false;
      update();
    }
  }

  void _requestSync() {
    if (Get.isRegistered<BackgroundService>()) {
      Get.find<BackgroundService>().requestSync();
    }
  }
}
