import 'package:get/get.dart';

import '../../data/models/local_user_model.dart';
import '../../data/repositories/user_repository.dart';
import '../../services/background_service.dart';
import '../../services/session_manager.dart';

class AuthController extends GetxController {
  AuthController({
    required UserRepository userRepository,
    required SessionManager sessionManager,
  })  : _userRepository = userRepository,
        _sessionManager = sessionManager;

  final UserRepository _userRepository;
  final SessionManager _sessionManager;

  bool isSubmitting = false;
  bool hasUsers = true;

  @override
  void onInit() {
    super.onInit();
    loadState();
  }

  Future<void> loadState() async {
    hasUsers = await _userRepository.hasUsers();
    update();
  }

  Future<LocalUserModel?> login({
    required String phone,
    required String password,
  }) async {
    isSubmitting = true;
    update();
    final user = await _userRepository.findByPhone(phone);
    if (user == null || !user.isActive || user.password != password) {
      isSubmitting = false;
      update();
      return null;
    }
    await _sessionManager.saveData(user);
    await Get.find<BackgroundService>().start();
    isSubmitting = false;
    update();
    return user;
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
    await _sessionManager.saveData(user);
    await Get.find<BackgroundService>().start();
    hasUsers = true;
    isSubmitting = false;
    update();
    return user;
  }
}
