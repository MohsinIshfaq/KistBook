import 'package:flutter_test/flutter_test.dart';
import 'package:kistbook/core/constants/app_enums.dart';
import 'package:kistbook/core/utils/dart_json.dart';
import 'package:kistbook/data/models/login_response_model.dart';
import 'package:kistbook/data/models/profile_response_model.dart';
import 'package:kistbook/data/models/register_response_model.dart';
import 'package:kistbook/data/models/user_model.dart';

void main() {
  group('DartJson', () {
    test('reads common primitive variants without casts', () {
      final json = DartJson({
        'id': '42',
        'price': '19.5',
        'active': 'true',
        'created_at': '2026-05-31T10:30:00Z',
        'items': [1, 'two'],
      });

      expect(json.intValue('id'), 42);
      expect(json.doubleValue('price'), 19.5);
      expect(json.boolValue('active'), isTrue);
      expect(json.asDate('created_at'), DateTime.utc(2026, 5, 31, 10, 30));
      expect(json.listValue('items'), [1, 'two']);
      expect(json.asString('missing'), isNull);
    });

    test('returns an empty map for incompatible map keys', () {
      expect(DartJson({1: 'unexpected'}).rawMap, isEmpty);
    });
  });

  group('UserModel', () {
    test('maps Laravel user fields safely', () {
      final user = UserModel.fromJson({
        'uuid': 'user-uuid',
        'phone': 3001234567,
        'email': null,
        'first_name': 'Test',
        'last_name': 'Owner',
        'access_level': 'owner',
        'is_active': 1,
      });

      expect(user.serverId, 'user-uuid');
      expect(user.phone, '3001234567');
      expect(user.email, isNull);
      expect(user.fullName, 'Test Owner');
      expect(user.role, UserRole.owner);
      expect(user.isActive, isTrue);
      expect(user.isEmpty, isFalse);
    });
  });

  group('LoginResponseModel', () {
    test('maps nested Laravel login response', () {
      final response = LoginResponseModel.fromJson({
        'message': 'Login successful.',
        'data': {
          'token': 'nested-token',
          'user': {
            'uuid': 'nested-user',
            'phone': '03001234567',
            'first_name': 'Nested',
            'last_name': 'User',
            'access_level': 'admin',
          },
        },
      });

      expect(response.isValid, isTrue);
      expect(response.token, 'nested-token');
      expect(response.user?.serverId, 'nested-user');
      expect(response.user?.role, UserRole.admin);
    });

    test('maps top-level access token and user response', () {
      final response = LoginResponseModel.fromJson({
        'access_token': 'top-level-token',
        'user': {'id': '9', 'name': 'Top Level User'},
      });

      expect(response.isValid, isTrue);
      expect(response.token, 'top-level-token');
      expect(response.user?.id, 9);
      expect(response.user?.fullName, 'Top Level User');
    });

    test('returns invalid model for incomplete payload', () {
      final response = LoginResponseModel.fromJson({
        'Message': 'Incomplete response',
        'data': 'unexpected',
      });

      expect(response.isValid, isFalse);
      expect(response.token, isEmpty);
      expect(response.user, isNull);
      expect(response.message, 'Incomplete response');
    });

    test('returns invalid model for malformed nested user map', () {
      final response = LoginResponseModel.fromJson({
        'token': 'token',
        'user': {1: 'unexpected'},
      });

      expect(response.isValid, isFalse);
      expect(response.user, isNull);
    });
  });

  group('RegisterResponseModel', () {
    test('maps owner signup with company safely', () {
      final response = RegisterResponseModel.fromJson({
        'token': 'signup-token',
        'user': {
          'id': '7',
          'company_id': '4',
          'name': 'Test Owner',
          'role': 'owner',
        },
        'company': {'id': '4', 'name': 'KistBook Demo Company'},
      });

      expect(response.isValid, isTrue);
      expect(response.user?.companyId, 4);
      expect(response.user?.role, UserRole.owner);
      expect(response.company?.id, 4);
      expect(response.company?.name, 'KistBook Demo Company');
    });

    test('rejects incomplete signup payload without throwing', () {
      final response = RegisterResponseModel.fromJson({
        'token': 'signup-token',
        'company': 'unexpected',
      });

      expect(response.isValid, isFalse);
      expect(response.user, isNull);
      expect(response.company, isNull);
    });
  });

  group('ProfileResponseModel', () {
    test('maps direct profile object', () {
      final response = ProfileResponseModel.fromJson({
        'uuid': 'direct-user',
        'name': 'Direct User',
        'phone': '03001234567',
      });

      expect(response.isValid, isTrue);
      expect(response.user?.serverId, 'direct-user');
    });

    test('maps user nested inside data', () {
      final response = ProfileResponseModel.fromJson({
        'data': {
          'user': {'id': 3, 'name': 'Nested Profile'},
        },
      });

      expect(response.isValid, isTrue);
      expect(response.user?.id, 3);
      expect(response.user?.fullName, 'Nested Profile');
    });

    test('maps top-level company and role', () {
      final response = ProfileResponseModel.fromJson({
        'user': {'id': 3, 'name': 'Owner Profile', 'role': 'owner'},
        'company': {'id': '9', 'name': 'Profile Company'},
        'role': 'owner',
      });

      expect(response.isValid, isTrue);
      expect(response.company?.id, 9);
      expect(response.company?.name, 'Profile Company');
      expect(response.role, 'owner');
    });

    test('returns invalid model for malformed profile response', () {
      final response = ProfileResponseModel.fromJson({
        'error': 'Profile payload was malformed.',
        'data': [],
      });

      expect(response.isValid, isFalse);
      expect(response.user, isNull);
      expect(response.message, 'Profile payload was malformed.');
    });
  });
}
