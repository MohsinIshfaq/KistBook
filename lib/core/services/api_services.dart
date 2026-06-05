import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_urls.dart';
import '../utils/dart_json.dart';
import '../../services/session_manager.dart';

enum ApiRequestMethod { get, post, put, delete }

class ApiServices {
  ApiServices({required SessionManager sessionManager, http.Client? httpClient})
    : _sessionManager = sessionManager,
      _httpClient = httpClient ?? http.Client();

  final SessionManager _sessionManager;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> sendRequest({
    required ApiRequestMethod method,
    required String endpoint,
    Map<String, Object?>? body,
    Map<String, String>? queryParameters,
    bool useBearerToken = true,
  }) async {
    if (useBearerToken && _sessionManager.sessionToken.isEmpty) {
      throw const ApiException(
        message: 'Your session has expired. Please log in again.',
        statusCode: HttpStatus.unauthorized,
      );
    }

    try {
      final response = switch (method) {
        ApiRequestMethod.get =>
          await _httpClient
              .get(
                _apiUri(endpoint, queryParameters),
                headers: _headers(useBearerToken),
              )
              .timeout(const Duration(seconds: 12)),
        ApiRequestMethod.post =>
          await _httpClient
              .post(
                _apiUri(endpoint, queryParameters),
                headers: _headers(useBearerToken),
                body: jsonEncode(body ?? const <String, Object?>{}),
              )
              .timeout(const Duration(seconds: 12)),
        ApiRequestMethod.put =>
          await _httpClient
              .put(
                _apiUri(endpoint, queryParameters),
                headers: _headers(useBearerToken),
                body: jsonEncode(body ?? const <String, Object?>{}),
              )
              .timeout(const Duration(seconds: 12)),
        ApiRequestMethod.delete =>
          await _httpClient
              .delete(
                _apiUri(endpoint, queryParameters),
                headers: _headers(useBearerToken),
                body: jsonEncode(body ?? const <String, Object?>{}),
              )
              .timeout(const Duration(seconds: 12)),
      };

      return _decodeResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        message: 'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        message:
            'No internet connection. Please check your network and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect to the server. Please try again.',
      );
    } on FormatException {
      throw const ApiException(
        message: 'The server returned an invalid response. Please try again.',
      );
    }
  }

  Future<List<int>> downloadBytes({
    required String url,
    bool useBearerToken = true,
  }) async {
    if (useBearerToken && _sessionManager.sessionToken.isEmpty) {
      throw const ApiException(
        message: 'Your session has expired. Please log in again.',
        statusCode: HttpStatus.unauthorized,
      );
    }

    try {
      final response = await _httpClient
          .get(_apiUri(url, null), headers: _downloadHeaders(useBearerToken))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          message: 'Unable to download the requested file.',
          statusCode: response.statusCode,
        );
      }
      return response.bodyBytes;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        message: 'The server took too long to respond. Please try again.',
      );
    } on SocketException {
      throw const ApiException(
        message:
            'No internet connection. Please check your network and try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect to the server. Please try again.',
      );
    }
  }

  Map<String, String> _headers(bool useBearerToken) => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (useBearerToken)
      'Authorization': 'Bearer ${_sessionManager.sessionToken}',
  };

  Map<String, String> _downloadHeaders(bool useBearerToken) => {
    if (useBearerToken)
      'Authorization': 'Bearer ${_sessionManager.sessionToken}',
  };

  Uri _apiUri(String url, Map<String, String>? queryParameters) {
    return Uri.parse(
      API.rebaseUrl(url: url, baseURL: _sessionManager.apiBaseUrl),
    ).replace(
      queryParameters: queryParameters == null || queryParameters.isEmpty
          ? null
          : queryParameters,
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    final decoded = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final payload = DartJson(decoded).rawMap;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        message: _errorMessage(payload, response.statusCode),
        statusCode: response.statusCode,
        errors: _validationErrors(DartJson(payload).rawValue('errors')),
      );
    }

    return payload;
  }

  String _errorMessage(Map<String, dynamic> payload, int statusCode) {
    final json = DartJson(payload);
    final message =
        json.asString('message') ??
        json.asString('Message') ??
        json.asString('error');
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return switch (statusCode) {
      HttpStatus.unauthorized =>
        'Your session has expired. Please log in again.',
      HttpStatus.unprocessableEntity =>
        'Please review the entered information and try again.',
      _ => 'Unable to complete the request. Please try again.',
    };
  }

  List<String> _validationErrors(Object? rawErrors) {
    final errors = DartJson(rawErrors).rawMap;
    if (errors.isEmpty) {
      return const [];
    }
    return errors.values
        .expand<String>((value) {
          if (value is List) {
            return value.map((item) => item.toString());
          }
          return [value.toString()];
        })
        .where((message) => message.trim().isNotEmpty)
        .toList();
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.errors = const [],
  });

  final String message;
  final int? statusCode;
  final List<String> errors;

  bool get isUnauthorized => statusCode == HttpStatus.unauthorized;

  List<String> get displayMessages => errors.isEmpty ? [message] : errors;

  @override
  String toString() => message;
}
