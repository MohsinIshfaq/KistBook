import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:kistbook/core/services/api_services.dart';
import 'package:kistbook/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'ApiServices sends PUT and DELETE requests with query and bearer token',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final client = _RecordingClient();
      final api = ApiServices(
        sessionManager: _FakeSessionManager(preferences),
        httpClient: client,
      );

      await api.sendRequest(
        method: ApiRequestMethod.put,
        endpoint: 'http://127.0.0.1:8000/api/products/sync',
        queryParameters: {'limit': '10'},
        body: {
          'products': [
            {'serverId': 'server-product', 'salesPrice': 1000},
          ],
        },
      );
      await api.sendRequest(
        method: ApiRequestMethod.delete,
        endpoint: 'http://127.0.0.1:8000/api/customers/sync',
        body: {
          'customers': [
            {'serverId': 'server-customer'},
          ],
        },
      );

      expect(client.requests, hasLength(2));
      expect(client.requests.first.method, 'PUT');
      expect(client.requests.first.url.queryParameters['limit'], '10');
      expect(
        client.requests.first.headers['Authorization'],
        'Bearer test-token',
      );
      expect(jsonDecode(client.requests.first.body)['products'], isA<List>());
      expect(client.requests.last.method, 'DELETE');
      expect(jsonDecode(client.requests.last.body)['customers'], isA<List>());
    },
  );
}

class _FakeSessionManager extends SessionManager {
  _FakeSessionManager(super.preferences)
    : super(secureStorage: const FlutterSecureStorage());

  @override
  String get sessionToken => 'test-token';

  @override
  String get apiBaseUrl => 'http://127.0.0.1:8000';
}

class _RecordingClient extends http.BaseClient {
  final requests = <http.Request>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = request is http.Request ? request.body : '';
    requests.add(
      http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..body = body,
    );
    return http.StreamedResponse(
      Stream.value(utf8.encode('{"success":true}')),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}
