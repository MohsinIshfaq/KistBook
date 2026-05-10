import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../app/routes/app_routes.dart';
import '../core/constants/app_enums.dart';
import '../data/models/local_user_model.dart';

class SessionManager {
  SessionManager(this._preferences);

  static const String _userDataKey = 'userData';
  static const String _isLoggedInKey = 'is_logged_in';

  final SharedPreferences _preferences;

  Map<String, dynamic> userData = {};
  String userUuid = '';
  String phone = '';
  String firstName = '';
  String lastName = '';
  String fullName = '';
  UserRole role = UserRole.salesMan;

  Future<void> saveData(LocalUserModel user) async {
    final data = {
      'uuid': user.uuid,
      'phone': user.phone,
      'first_name': user.firstName,
      'last_name': user.lastName,
      'role': user.role.name,
    };
    userData = data;
    await _preferences.setString(_userDataKey, jsonEncode(data));
    await _preferences.setBool(_isLoggedInKey, true);
    _populateFields(data);
  }

  Future<void> loadData() async {
    final dataStr = _preferences.getString(_userDataKey);
    if (dataStr == null) {
      return;
    }
    final data = jsonDecode(dataStr) as Map<String, dynamic>;
    userData = data;
    _populateFields(data);
  }

  void _populateFields(Map<String, dynamic> data) {
    userUuid = data['uuid']?.toString() ?? '';
    phone = data['phone']?.toString() ?? '';
    firstName = data['first_name']?.toString() ?? '';
    lastName = data['last_name']?.toString() ?? '';
    fullName = '$firstName $lastName'.trim();
    role = UserRole.values.firstWhere(
      (item) => item.name == (data['role']?.toString() ?? ''),
      orElse: () => UserRole.salesMan,
    );
  }

  Future<void> clearSettings() async {
    await _preferences.remove(_userDataKey);
    await _preferences.setBool(_isLoggedInKey, false);
    userData = {};
    userUuid = '';
    phone = '';
    firstName = '';
    lastName = '';
    fullName = '';
    role = UserRole.salesMan;
  }

  bool get isLoggedIn => _preferences.getBool(_isLoggedInKey) ?? false;

  String get homeRoute => AppRoutes.dashboard;
}
