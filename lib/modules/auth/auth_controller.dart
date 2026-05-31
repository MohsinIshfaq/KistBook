import 'package:get/get.dart';

import '../../core/constants/app_enums.dart';
import '../../data/models/local_user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/auth_api_service.dart';
import '../../services/background_service.dart';
import '../../services/session_manager.dart';

class AuthController extends GetxController {
  AuthController({
    required UserRepository userRepository,
    required SessionManager sessionManager,
    required AuthApiService authApiService,
  }) : _userRepository = userRepository,
       _sessionManager = sessionManager,
       _authApiService = authApiService;

  final UserRepository _userRepository;
  final SessionManager _sessionManager;
  final AuthApiService _authApiService;

  bool isSubmitting = false;
  bool hasUsers = true;
  bool hasOwner = false;

  @override
  void onInit() {
    super.onInit();
    loadState();
  }

  Future<void> loadState() async {
    hasUsers = await _userRepository.hasUsers();
    hasOwner = await _userRepository.hasOwner();
    update();
  }

  Future<LocalUserModel?> login({
    required String phone,
    required String password,
  }) async {
    isSubmitting = true;
    update();
    final user = await _userRepository.findByPhone(phone);
    if (user != null && user.isActive && user.password == password) {
      await _sessionManager.saveData(user);
      await _connectRemoteAccount(user, password);
      await Get.find<BackgroundService>().start();
      isSubmitting = false;
      update();
      return user;
    }

    final remote = await _authApiService.login(
      phone: phone,
      password: password,
    );
    if (remote == null || !remote.isActive) {
      isSubmitting = false;
      update();
      return null;
    }

    final syncedUser = await _saveRemoteUser(
      remote,
      password: password,
      existing: user,
    );
    await _sessionManager.saveData(syncedUser);
    await Get.find<BackgroundService>().start();
    isSubmitting = false;
    update();
    return syncedUser;
  }

  Future<void> logout() async {
    Get.find<BackgroundService>().dispose();
    await _sessionManager.clearSettings();
  }

  Future<LocalUserModel?> registerOwner({
    required String phone,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    isSubmitting = true;
    update();
    if (await _userRepository.hasOwner()) {
      hasUsers = true;
      hasOwner = true;
      isSubmitting = false;
      update();
      return null;
    }
    final existing = await _userRepository.findByPhone(phone);
    if (existing != null) {
      isSubmitting = false;
      update();
      return null;
    }
    final user = await _userRepository.createOwner(
      phone: phone,
      password: password,
      firstName: firstName,
      lastName: lastName,
    );
    final remote =
        await _authApiService.registerOwner(
          phone: phone,
          password: password,
          firstName: firstName,
          lastName: lastName,
        ) ??
        await _authApiService.login(phone: phone, password: password);
    if (remote != null) {
      await _saveRemoteSession(remote, user);
    }
    await _sessionManager.saveData(user);
    await Get.find<BackgroundService>().start();
    hasUsers = true;
    hasOwner = true;
    isSubmitting = false;
    update();
    return user;
  }

  Future<void> _connectRemoteAccount(
    LocalUserModel user,
    String password,
  ) async {
    final remote =
        await _authApiService.login(phone: user.phone, password: password) ??
        (user.role == UserRole.owner
            ? await _authApiService.registerOwner(
                phone: user.phone,
                password: password,
                firstName: user.firstName,
                lastName: user.lastName,
              )
            : null);
    if (remote == null) {
      return;
    }
    await _saveRemoteSession(remote, user);
  }

  Future<LocalUserModel> _saveRemoteUser(
    AuthApiResult remote, {
    required String password,
    LocalUserModel? existing,
  }) async {
    final now = DateTime.now();
    final user = LocalUserModel(
      id: existing?.id,
      uuid: existing?.uuid ?? remote.serverId,
      phone: remote.phone,
      password: password,
      firstName: remote.firstName,
      lastName: remote.lastName,
      role: remote.role,
      isActive: remote.isActive,
      isSync: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final saved = await _userRepository.saveUser(user);
    await _saveRemoteSession(remote, saved);
    return saved.copyWith(isSync: true);
  }

  Future<void> _saveRemoteSession(
    AuthApiResult remote,
    LocalUserModel user,
  ) async {
    await _sessionManager.saveApiSession(token: remote.token);
    if (user.id != null && remote.serverId.isNotEmpty) {
      await _userRepository.markServerIdentity(
        userId: user.id!,
        serverId: remote.serverId,
      );
    }
  }
}
