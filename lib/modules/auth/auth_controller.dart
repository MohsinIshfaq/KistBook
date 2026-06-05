import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../core/services/api_services.dart';
import '../../core/utils/id_generator.dart';
import '../../core/widgets/banner_alert.dart';
import '../../data/database/db_helper.dart';
import '../../data/models/company_model.dart';
import '../../data/models/local_user_model.dart';
import '../../data/models/login_response_model.dart';
import '../../data/models/user_model.dart';
import '../../data/repositories/runtime_bootstrap_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/sync/sync_cursor_store.dart';
import '../../services/auth_api_service.dart';
import '../../services/background_service.dart';
import '../../services/session_manager.dart';

class AuthController extends GetxController {
  AuthController({
    required UserRepository userRepository,
    required SessionManager sessionManager,
    required AuthApiService authApiService,
    required DbHelper dbHelper,
    required SyncCursorStore syncCursorStore,
    required RuntimeBootstrapRepository runtimeBootstrapRepository,
  }) : _userRepository = userRepository,
       _sessionManager = sessionManager,
       _authApiService = authApiService,
       _dbHelper = dbHelper,
       _syncCursorStore = syncCursorStore,
       _runtimeBootstrapRepository = runtimeBootstrapRepository;

  final UserRepository _userRepository;
  final SessionManager _sessionManager;
  final AuthApiService _authApiService;
  final DbHelper _dbHelper;
  final SyncCursorStore _syncCursorStore;
  final RuntimeBootstrapRepository _runtimeBootstrapRepository;

  final RxBool isLoginLoading = false.obs;
  final RxBool isSignupLoading = false.obs;
  final RxBool isProfileLoading = false.obs;
  final RxBool isLogoutLoading = false.obs;
  final Rxn<UserModel> currentUser = Rxn<UserModel>();
  final RxString errorMessage = ''.obs;

  bool hasUsers = true;
  bool hasOwner = false;

  bool get isSubmitting => isLoginLoading.value || isSignupLoading.value;

  @override
  void onInit() {
    super.onInit();
    if (_sessionManager.userData.isNotEmpty) {
      currentUser.value = UserModel.fromJson(_sessionManager.userData);
    }
    loadState();
  }

  Future<void> loadState() async {
    hasUsers = await _userRepository.hasUsers();
    hasOwner = await _userRepository.hasOwner();
    update();
  }

  Future<LocalUserModel?> login({
    required String login,
    required String password,
    bool rememberMe = true,
  }) async {
    errorMessage.value = '';
    final normalizedLogin = login.trim();
    if (normalizedLogin.isEmpty || password.trim().isEmpty) {
      errorMessage.value = 'Email or phone number and password are required.';
      return null;
    }

    isLoginLoading.value = true;
    update();
    try {
      await _sessionManager.saveRememberedLogin(
        remember: rememberMe,
        phone: normalizedLogin,
      );
      final localUser = await _userRepository.findByLogin(normalizedLogin);
      if (localUser != null &&
          localUser.isActive &&
          localUser.password == password) {
        await _sessionManager.saveData(localUser);
        currentUser.value = UserModel.fromJson(_sessionManager.userData);
        await _connectRemoteAccount(localUser, password);
        await _completeLogin();
        return localUser;
      }

      final remote = await _authApiService.login(
        login: normalizedLogin,
        password: password,
      );
      if (!remote.isValid) {
        errorMessage.value =
            'The server returned incomplete login information. Please try again.';
        return null;
      }
      if (remote.user!.isActive == false) {
        errorMessage.value = 'This user account is inactive.';
        return null;
      }

      final existingRemoteUser =
          localUser ??
          await _userRepository.findByServerIdentity(remote.user!.serverId);
      final syncedUser = await _saveRemoteUser(
        remote,
        password: password,
        existing: existingRemoteUser,
      );
      await _sessionManager.saveData(syncedUser);
      await _saveRemoteSession(remote, syncedUser);
      await _completeLogin();
      return syncedUser;
    } on ApiException catch (error) {
      errorMessage.value = error.displayMessages.join('\n');
      return null;
    } catch (_) {
      errorMessage.value =
          'The server returned an invalid response. Please try again.';
      return null;
    } finally {
      isLoginLoading.value = false;
      update();
    }
  }

  Future<LocalUserModel?> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String companyName,
    String? companyPhone,
    String? companyAddress,
  }) async {
    errorMessage.value = '';
    if (name.trim().isEmpty ||
        email.trim().isEmpty ||
        phone.trim().isEmpty ||
        password.isEmpty ||
        companyName.trim().isEmpty) {
      errorMessage.value = 'Please complete all required signup fields.';
      return null;
    }
    if (password != passwordConfirmation) {
      errorMessage.value = 'Password and confirm password must match.';
      return null;
    }

    isSignupLoading.value = true;
    update();
    try {
      final remote = await _authApiService.registerOwner(
        name: name.trim(),
        email: email.trim().toLowerCase(),
        phone: phone.trim(),
        password: password,
        passwordConfirmation: passwordConfirmation,
        companyName: companyName.trim(),
        companyPhone: companyPhone?.trim(),
        companyAddress: companyAddress?.trim(),
      );
      if (!remote.isValid) {
        errorMessage.value =
            'The server returned incomplete account information. Please try again.';
        return null;
      }

      final existing = await _userRepository.findByPhone(phone.trim());
      final user = await _saveUserModel(
        remote.user!,
        password: password,
        existing: existing,
      );
      await _sessionManager.saveData(user);
      await _saveAuthSession(
        token: remote.token,
        user: remote.user!,
        company: remote.company,
        rawResponse: remote.rawResponse,
        localUser: user,
      );
      await _completeLogin();
      hasUsers = true;
      hasOwner = true;
      return user;
    } on ApiException catch (error) {
      errorMessage.value = error.displayMessages.join('\n');
      return null;
    } catch (_) {
      errorMessage.value =
          'The server returned an invalid response. Please try again.';
      return null;
    } finally {
      isSignupLoading.value = false;
      update();
    }
  }

  Future<void> fetchProfile() async {
    if (!_sessionManager.hasApiSession || isProfileLoading.value) {
      return;
    }

    isProfileLoading.value = true;
    errorMessage.value = '';
    update();
    try {
      final response = await _authApiService.getProfile();
      if (!response.isValid) {
        errorMessage.value =
            'The server returned incomplete profile information. Please try again.';
        showBannerAlert(
          type: BannerStyle.warning,
          title: 'Profile Refresh Failed'.tr,
          messages: [errorMessage.value],
        );
        return;
      }
      final user = response.user!;
      currentUser.value = user;
      await _sessionManager.updateProfileData(
        user: user,
        company: response.company,
      );
    } on ApiException catch (error) {
      errorMessage.value = error.message;
      if (error.isUnauthorized) {
        await _clearLocalSession();
        Get.offAllNamed(AppRoutes.login);
        showBannerAlert(
          type: BannerStyle.warning,
          title: 'Session Expired'.tr,
          messages: ['Your session has expired. Please log in again.'.tr],
        );
      } else {
        showBannerAlert(
          type: BannerStyle.warning,
          title: 'Profile Refresh Failed'.tr,
          messages: error.displayMessages,
        );
      }
    } catch (_) {
      errorMessage.value =
          'The server returned an invalid response. Please try again.';
      showBannerAlert(
        type: BannerStyle.warning,
        title: 'Profile Refresh Failed'.tr,
        messages: [errorMessage.value],
      );
    } finally {
      isProfileLoading.value = false;
      update();
    }
  }

  Future<void> logout() async {
    if (isLogoutLoading.value) {
      return;
    }
    isLogoutLoading.value = true;
    errorMessage.value = '';
    update();
    String? warning;
    try {
      if (_sessionManager.hasApiSession) {
        await _authApiService.logout();
      }
    } on ApiException catch (error) {
      if (!error.isUnauthorized) {
        warning = error.message;
      }
    } catch (_) {
      warning = 'The server returned an invalid response.';
    } finally {
      await _clearLocalSession(resetLocalDatabase: true);
      isLogoutLoading.value = false;
      update();
      Get.offAllNamed(AppRoutes.login);
    }

    if (warning != null) {
      showBannerAlert(
        type: BannerStyle.warning,
        title: 'Logged Out'.tr,
        messages: ['You were logged out on this device. $warning'],
      );
    }
  }

  Future<void> _connectRemoteAccount(
    LocalUserModel user,
    String password,
  ) async {
    try {
      final remote = await _authApiService.login(
        login: user.phone,
        password: password,
      );
      if (remote.isValid) {
        await _saveRemoteSession(remote, user);
      }
    } catch (_) {
      // Local login remains available while the server is unreachable.
    }
  }

  Future<LocalUserModel> _saveRemoteUser(
    LoginResponseModel remote, {
    required String password,
    LocalUserModel? existing,
  }) {
    return _saveUserModel(remote.user!, password: password, existing: existing);
  }

  Future<LocalUserModel> _saveUserModel(
    UserModel remoteUser, {
    required String password,
    LocalUserModel? existing,
  }) async {
    final now = DateTime.now();
    final remoteServerId = remoteUser.serverId;
    final names = _splitName(remoteUser.fullName);
    final user = LocalUserModel(
      id: existing?.id,
      uuid:
          existing?.uuid ??
          (remoteServerId.isNotEmpty
              ? remoteServerId
              : IdGenerator.localUuid()),
      phone: remoteUser.phone ?? '',
      email: remoteUser.email ?? '',
      password: password,
      firstName: remoteUser.firstName ?? names.$1,
      lastName: remoteUser.lastName ?? names.$2,
      role: remoteUser.role,
      isActive: remoteUser.isActive != false,
      isSync: true,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    final saved = await _userRepository.saveUser(user);
    return saved.copyWith(isSync: true);
  }

  Future<void> _saveRemoteSession(
    LoginResponseModel remote,
    LocalUserModel user,
  ) {
    return _saveAuthSession(
      token: remote.token,
      user: remote.user!,
      company: remote.company,
      rawResponse: remote.rawResponse,
      localUser: user,
    );
  }

  Future<void> _saveAuthSession({
    required String token,
    required UserModel user,
    required LocalUserModel localUser,
    CompanyModel? company,
    Map<String, dynamic>? rawResponse,
  }) async {
    if (token.trim().isEmpty || user.isEmpty) {
      return;
    }
    await _sessionManager.saveAuthData(
      token: token,
      user: user,
      company: company,
      loginResponse: rawResponse,
    );
    currentUser.value = user;
    if (localUser.id != null && user.serverId.isNotEmpty) {
      await _userRepository.markServerIdentity(
        userId: localUser.id!,
        serverId: user.serverId,
      );
    }
  }

  (String, String) _splitName(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) {
      return ('', '');
    }
    return (parts.first, parts.skip(1).join(' '));
  }

  Future<void> _completeLogin() async {
    if (_sessionManager.hasApiSession) {
      await _runtimeBootstrapRepository.bootstrap();
    }
    await Get.find<BackgroundService>().start();
    Get.offAllNamed(_sessionManager.homeRoute);
  }

  Future<void> _clearLocalSession({bool resetLocalDatabase = false}) async {
    final backgroundService = Get.find<BackgroundService>();
    if (resetLocalDatabase) {
      await backgroundService.stop(waitForSync: true);
      await _syncCursorStore.clearAll();
      await _dbHelper.resetDatabase();
    } else {
      backgroundService.dispose();
    }
    await _sessionManager.clearAuthData();
    currentUser.value = null;
  }
}
