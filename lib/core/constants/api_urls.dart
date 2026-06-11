// ignore_for_file: non_constant_identifier_names

class API {
  API._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.107:8000',
  );
  static const String prefix = '/api/';
  static const String postfix = '';

  static const String _apiPrefixSegment = '/api';

  static String urlFormatter({String baseURL = baseUrl, required String api}) {
    final normalizedBaseUrl = normalizeBaseUrl(baseURL);
    final normalizedApi = api.trim().replaceFirst(RegExp(r'^/+'), '');
    return '$normalizedBaseUrl$prefix$normalizedApi$postfix';
  }

  static String normalizeBaseUrl(String value) {
    var normalized = value.trim().replaceFirst(RegExp(r'/+$'), '');
    if (normalized.endsWith(_apiPrefixSegment)) {
      normalized = normalized.substring(
        0,
        normalized.length - _apiPrefixSegment.length,
      );
    }
    return normalized.replaceFirst(RegExp(r'/+$'), '');
  }

  static String rebaseUrl({required String url, required String baseURL}) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      return urlFormatter(baseURL: baseURL, api: url);
    }
    if (!uri.path.startsWith(prefix)) {
      return url;
    }
    final api = uri.path.substring(prefix.length);
    return Uri.parse(
      urlFormatter(baseURL: baseURL, api: api),
    ).replace(query: uri.query.isEmpty ? null : uri.query).toString();
  }

  static final String URL_REGISTER = urlFormatter(api: 'auth/register');
  static final String URL_LOGIN = urlFormatter(api: 'auth/login');
  static final String URL_LOGOUT = urlFormatter(api: 'auth/logout');
  static final String URL_PROFILE = urlFormatter(api: 'auth/profile');
  static final String URL_BOOTSTRAP = urlFormatter(api: 'bootstrap');
  static final String URL_CREATE_COMPANY_USER = urlFormatter(
    api: 'company/users',
  );

  static final String URL_CUSTOMERS = urlFormatter(api: 'customers');
  static final String URL_PRODUCTS = urlFormatter(api: 'products');
  static final String URL_CATEGORIES = urlFormatter(api: 'categories');
  static final String URL_PLANS = urlFormatter(api: 'plans');
  static final String URL_INSTALLMENTS = urlFormatter(api: 'installments');
  static final String URL_PAYMENTS = urlFormatter(api: 'payments');
  static final String URL_DASHBOARD = urlFormatter(api: 'dashboard');

  static final String URL_ACCESS_CUSTOMER = urlFormatter(
    api: 'access/customer',
  );
  static final String URL_ACCESS_PLAN = urlFormatter(api: 'access/plan');
  static final String URL_ACCESS_ASSIGNMENTS = urlFormatter(
    api: 'access/assignments',
  );
  static final String URL_SYNC_UPLOAD = urlFormatter(api: 'sync/upload');
  static final String URL_SYNC_DOWNLOAD = urlFormatter(api: 'sync/download');
  static final String URL_CUSTOMER_SYNC = urlFormatter(api: 'customers/sync');
  static final String URL_PRODUCT_SYNC = urlFormatter(api: 'products/sync');
  static final String URL_INSTALLMENT_PLAN_SYNC = urlFormatter(
    api: 'installment-plans/sync',
  );

  static String URL_CUSTOMER_DETAIL(String customerId) {
    return urlFormatter(api: 'customers/$customerId');
  }

  static String URL_CUSTOMER_PLANS(String customerId) {
    return urlFormatter(api: 'customers/$customerId/plans');
  }

  static String URL_PRODUCT_DETAIL(String productId) {
    return urlFormatter(api: 'products/$productId');
  }

  static String URL_CATEGORY_DETAIL(String categoryId) {
    return urlFormatter(api: 'categories/$categoryId');
  }

  static String URL_PLAN_DETAIL(String planId) {
    return urlFormatter(api: 'plans/$planId');
  }

  static String URL_INSTALLMENT_DETAIL(String installmentId) {
    return urlFormatter(api: 'installments/$installmentId');
  }

  static String URL_PAYMENT_DETAIL(String paymentId) {
    return urlFormatter(api: 'payments/$paymentId');
  }

  static String URL_PRODUCT_IMAGE(String imagePath) {
    return productImageUrl(imagePath: imagePath);
  }

  static String productImageUrl({
    required String imagePath,
    String baseURL = baseUrl,
  }) {
    final normalizedPath = imagePath.trim();
    if (normalizedPath.isEmpty) return '';
    if (normalizedPath.startsWith('http')) return normalizedPath;

    final normalizedBaseUrl = normalizeBaseUrl(baseURL);
    final path = normalizedPath.replaceFirst(RegExp(r'^/+'), '');
    if (path.startsWith('storage/')) {
      return '$normalizedBaseUrl/$path';
    }
    return '$normalizedBaseUrl/storage/$path';
  }
}
