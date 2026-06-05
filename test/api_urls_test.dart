import 'package:flutter_test/flutter_test.dart';
import 'package:kistbook/core/constants/api_urls.dart';

void main() {
  group('API URLs', () {
    test('formats auth and resource URLs with the API prefix', () {
      expect(API.URL_LOGIN, '${API.baseUrl}/api/auth/login');
      expect(API.URL_PROFILE, '${API.baseUrl}/api/auth/profile');
      expect(API.URL_CREATE_COMPANY_USER, '${API.baseUrl}/api/company/users');
      expect(API.URL_CUSTOMERS, '${API.baseUrl}/api/customers');
      expect(API.URL_CUSTOMER_SYNC, '${API.baseUrl}/api/customers/sync');
      expect(API.URL_PRODUCT_SYNC, '${API.baseUrl}/api/products/sync');
      expect(API.URL_BOOTSTRAP, '${API.baseUrl}/api/bootstrap');
      expect(
        API.URL_ACCESS_ASSIGNMENTS,
        '${API.baseUrl}/api/access/assignments',
      );
      expect(
        API.URL_INSTALLMENT_PLAN_SYNC,
        '${API.baseUrl}/api/installment-plans/sync',
      );
      expect(
        API.URL_CUSTOMER_DETAIL('customer-uuid'),
        '${API.baseUrl}/api/customers/customer-uuid',
      );
    });

    test('supports Android emulator and legacy API base overrides', () {
      expect(
        API.urlFormatter(baseURL: 'http://10.0.2.2:8000', api: 'auth/login'),
        'http://10.0.2.2:8000/api/auth/login',
      );
      expect(
        API.rebaseUrl(
          url: API.URL_LOGOUT,
          baseURL: 'http://192.168.1.8:8000/api/',
        ),
        'http://192.168.1.8:8000/api/auth/logout',
      );
    });

    test('formats product images safely', () {
      expect(API.URL_PRODUCT_IMAGE(''), isEmpty);
      expect(
        API.URL_PRODUCT_IMAGE('products/image.jpg'),
        '${API.baseUrl}/storage/products/image.jpg',
      );
      expect(
        API.URL_PRODUCT_IMAGE('/storage/products/image.jpg'),
        '${API.baseUrl}/storage/products/image.jpg',
      );
      expect(
        API.URL_PRODUCT_IMAGE('https://cdn.example.com/image.jpg'),
        'https://cdn.example.com/image.jpg',
      );
    });
  });
}
