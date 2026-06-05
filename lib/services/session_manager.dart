import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/routes/app_routes.dart';
import '../core/constants/api_urls.dart';
import '../core/constants/app_enums.dart';
import '../core/utils/dart_json.dart';
import '../data/models/local_user_model.dart';
import '../data/models/company_model.dart';
import '../data/models/user_model.dart';

class SessionManager {
  SessionManager(this._preferences, {FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _userDataKey = 'userData';
  static const String _isLoggedInKey = 'is_logged_in';
  static const String _apiBaseUrlKey = 'api_base_url';
  static const String _apiTokenKey = 'api_token';
  static const String _loginResponseKey = 'login_response';
  static const String _companyDataKey = 'company_data';
  static const String _lastSyncDateKey = 'last_sync_date';
  static const String _rememberLoginKey = 'remember_login';
  static const String _rememberedPhoneKey = 'remembered_phone';

  final SharedPreferences _preferences;
  final FlutterSecureStorage _secureStorage;

  Map<String, dynamic> userData = {};
  Map<String, dynamic> loginResponseData = {};
  Map<String, dynamic> companyData = {};
  String _sessionToken = '';
  String _rememberedPhone = '';
  String userUuid = '';
  int userId = 0;
  int companyId = 0;
  String phone = '';
  String email = '';
  String firstName = '';
  String lastName = '';
  String fullName = '';
  UserRole role = UserRole.salesMan;

  Future<void> saveData(LocalUserModel user) async {
    final data = {
      'uuid': user.uuid,
      'phone': user.phone,
      'email': user.email,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'role': user.role.name,
    };
    await _saveUserData(data);
    await _preferences.setBool(_isLoggedInKey, true);
  }

  Future<void> saveAuthData({
    required String token,
    required UserModel user,
    CompanyModel? company,
    Map<String, dynamic>? loginResponse,
  }) async {
    _sessionToken = token.trim();
    if (_sessionToken.isEmpty || user.isEmpty) {
      return;
    }
    await _secureStorage.write(key: _apiTokenKey, value: _sessionToken);
    await _saveUserData(user.toJson());
    await updateCompanyData(company);
    if (loginResponse != null) {
      loginResponseData = DartJson(loginResponse).rawMap;
      await _secureStorage.write(
        key: _loginResponseKey,
        value: jsonEncode(loginResponseData),
      );
    } else {
      loginResponseData = {};
      await _secureStorage.delete(key: _loginResponseKey);
    }
    await _preferences.setBool(_isLoggedInKey, true);
    await _preferences.remove(_apiTokenKey);
    await _preferences.remove(_userDataKey);
  }

  Future<void> loadAuthData() async {
    await _migrateLegacyAuthData();
    _sessionToken = await _secureStorage.read(key: _apiTokenKey) ?? '';
    _rememberedPhone =
        await _secureStorage.read(key: _rememberedPhoneKey) ?? '';
    loginResponseData = _decodeSecureMap(
      await _secureStorage.read(key: _loginResponseKey),
    );
    companyData = _decodeSecureMap(
      await _secureStorage.read(key: _companyDataKey),
    );
    _populateCompanyFields(companyData);
    final dataStr = await _secureStorage.read(key: _userDataKey);
    if (dataStr == null || dataStr.trim().isEmpty) {
      await clearAuthData();
      return;
    }
    try {
      final decoded = DartJson(jsonDecode(dataStr)).rawMap;
      if (decoded.isEmpty) {
        await clearAuthData();
        return;
      }
      userData = decoded;
      _populateFields(decoded);
    } on FormatException {
      await clearAuthData();
    }
  }

  Future<void> loadData() => loadAuthData();

  Future<void> updateUserData(UserModel user) async {
    await _saveUserData(user.toJson());
  }

  Future<void> updateProfileData({
    required UserModel user,
    CompanyModel? company,
  }) async {
    await _saveUserData(user.toJson());
    await updateCompanyData(company);
  }

  Future<void> updateCompanyData(CompanyModel? company) async {
    if (company == null || company.isEmpty) {
      return;
    }
    companyData = company.toJson();
    _populateCompanyFields(companyData);
    await _secureStorage.write(
      key: _companyDataKey,
      value: jsonEncode(companyData),
    );
  }

  Future<void> _saveUserData(Map<String, dynamic> data) async {
    userData = DartJson(data).rawMap;
    _populateFields(userData);
    await _secureStorage.write(key: _userDataKey, value: jsonEncode(userData));
    await _preferences.remove(_userDataKey);
  }

  Future<void> _migrateLegacyAuthData() async {
    final secureToken = await _secureStorage.read(key: _apiTokenKey);
    final legacyToken = _preferences.getString(_apiTokenKey);
    if ((secureToken == null || secureToken.isEmpty) &&
        legacyToken != null &&
        legacyToken.isNotEmpty) {
      await _secureStorage.write(key: _apiTokenKey, value: legacyToken);
    }
    await _preferences.remove(_apiTokenKey);

    final secureUserData = await _secureStorage.read(key: _userDataKey);
    final legacyUserData = _preferences.getString(_userDataKey);
    if ((secureUserData == null || secureUserData.isEmpty) &&
        legacyUserData != null &&
        legacyUserData.isNotEmpty) {
      await _secureStorage.write(key: _userDataKey, value: legacyUserData);
    }
    await _preferences.remove(_userDataKey);

    final secureRememberedPhone = await _secureStorage.read(
      key: _rememberedPhoneKey,
    );
    final legacyRememberedPhone = _preferences.getString(_rememberedPhoneKey);
    if ((secureRememberedPhone == null || secureRememberedPhone.isEmpty) &&
        legacyRememberedPhone != null &&
        legacyRememberedPhone.isNotEmpty) {
      await _secureStorage.write(
        key: _rememberedPhoneKey,
        value: legacyRememberedPhone,
      );
    }
    await _preferences.remove(_rememberedPhoneKey);
  }

  void _populateFields(Map<String, dynamic> data) {
    final json = DartJson(data);
    userId = json.intValue('id');
    userUuid = json.asString('uuid') ?? json.asString('id') ?? '';
    if (companyId == 0) {
      companyId = json.asInt('company_id') ?? json.intValue('companyId');
    }
    phone = json.asString('phone') ?? json.stringValue('phoneNumber');
    email = json.stringValue('email');
    firstName = json.asString('first_name') ?? json.stringValue('firstName');
    lastName = json.asString('last_name') ?? json.stringValue('lastName');
    fullName = json.stringValue('name').trim();
    if (fullName.isEmpty) {
      fullName = '$firstName $lastName'.trim();
    }
    final storedRole =
        json.asString('role') ?? json.asString('access_level') ?? '';
    role = _roleFrom(storedRole);
  }

  void _populateCompanyFields(Map<String, dynamic> data) {
    companyId = DartJson(data).intValue('id');
  }

  UserRole _roleFrom(String value) {
    return switch (value.toLowerCase()) {
      'owner' => UserRole.owner,
      'admin' => UserRole.admin,
      'salesman' || 'sales_man' => UserRole.salesMan,
      _ => UserRole.salesMan,
    };
  }

  Future<void> clearAuthData() async {
    await _secureStorage.delete(key: _userDataKey);
    await _secureStorage.delete(key: _apiTokenKey);
    await _secureStorage.delete(key: _loginResponseKey);
    await _secureStorage.delete(key: _companyDataKey);
    await _preferences.remove(_userDataKey);
    await _preferences.remove(_apiTokenKey);
    await _preferences.remove(_lastSyncDateKey);
    await _preferences.setBool(_isLoggedInKey, false);
    userData = {};
    loginResponseData = {};
    companyData = {};
    _sessionToken = '';
    userUuid = '';
    userId = 0;
    companyId = 0;
    phone = '';
    email = '';
    firstName = '';
    lastName = '';
    fullName = '';
    role = UserRole.salesMan;
  }

  Future<void> clearSettings() => clearAuthData();

  bool get isLoggedIn =>
      (_preferences.getBool(_isLoggedInKey) ?? false) && userData.isNotEmpty;

  bool get hasApiSession => sessionToken.isNotEmpty;

  bool get canRestoreSession => isLoggedIn && hasApiSession;

  String get apiBaseUrl =>
      _preferences.getString(_apiBaseUrlKey) ?? API.baseUrl;

  String get sessionToken => _sessionToken;

  String get apiToken => sessionToken;

  String get lastSyncDate => _preferences.getString(_lastSyncDateKey) ?? '';

  Future<void> saveApiSession({required String token, String? baseUrl}) async {
    _sessionToken = token.trim();
    await _secureStorage.write(key: _apiTokenKey, value: _sessionToken);
    await _preferences.remove(_apiTokenKey);
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      await _preferences.setString(_apiBaseUrlKey, baseUrl.trim());
    }
  }

  bool get rememberLogin => _preferences.getBool(_rememberLoginKey) ?? true;

  String get rememberedPhone => _rememberedPhone;

  String get rememberedLogin => _rememberedPhone;

  bool get isOwner => role == UserRole.owner;

  bool get isSalesman => role == UserRole.salesMan;

  Future<void> saveRememberedLogin({
    required bool remember,
    required String phone,
  }) async {
    await _preferences.setBool(_rememberLoginKey, remember);
    if (remember) {
      _rememberedPhone = phone;
      await _secureStorage.write(key: _rememberedPhoneKey, value: phone);
    } else {
      _rememberedPhone = '';
      await _secureStorage.delete(key: _rememberedPhoneKey);
    }
    await _preferences.remove(_rememberedPhoneKey);
  }

  Future<void> saveLastSyncDate(String value) async {
    if (value.trim().isEmpty) {
      return;
    }
    await _preferences.setString(_lastSyncDateKey, value);
  }

  String get homeRoute => AppRoutes.dashboard;

  Map<String, dynamic> _decodeSecureMap(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const {};
    }
    try {
      return DartJson(jsonDecode(value)).rawMap;
    } on FormatException {
      return const {};
    }
  }
}
