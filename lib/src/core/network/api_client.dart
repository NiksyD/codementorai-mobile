import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  final String message;
  final int? statusCode;
  final dynamic data;

  @override
  String toString() =>
      'ApiException: $message (statusCode: ${statusCode ?? 'N/A'})';
}

class ApiClient {
  const ApiClient({
    http.Client? httpClient,
    String? baseUrl,
  })  : _client = httpClient,
        _customBaseUrl = baseUrl;

  final http.Client? _client;
  final String? _customBaseUrl;

  String get baseUrl {
    final String? custom = _customBaseUrl;
    if (custom != null && custom.isNotEmpty) {
      return custom;
    }
    return dotenv.env['API_BASE_URL'] ?? 'https://codementorai-ejkd.onrender.com';
  }

  /// Base URL for web fallback API routes (e.g. Next.js server on Vercel)
  String get webBaseUrl {
    return dotenv.env['WEB_API_URL'] ?? 'https://codementoraihub.vercel.app';
  }

  http.Client get client => _client ?? http.Client();

  /// Automatically retrieves the active Supabase JWT access token.
  String? get _sessionToken {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }

  Map<String, String> _buildHeaders({Map<String, String>? customHeaders}) {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final String? token = _sessionToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }

    return headers;
  }

  Uri _resolveUri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final String cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final String cleanEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';

    final String fullUrl = '$cleanBase$cleanEndpoint';
    final Uri uri = Uri.parse(fullUrl);

    if (queryParams == null || queryParams.isEmpty) {
      return uri;
    }

    final Map<String, String> stringParams = queryParams.map(
      (String key, dynamic value) => MapEntry<String, String>(key, value.toString()),
    );

    return uri.replace(queryParameters: <String, String>{
      ...uri.queryParameters,
      ...stringParams,
    });
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final Uri uri = _resolveUri(endpoint, queryParams);
    try {
      final http.Response response = await client
          .get(uri, headers: _buildHeaders(customHeaders: headers))
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  /// Performs a GET request to the web fallback API (e.g. Next.js on Vercel)
  Future<dynamic> getWeb(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final String cleanBase = webBaseUrl.endsWith('/')
        ? webBaseUrl.substring(0, webBaseUrl.length - 1)
        : webBaseUrl;
    final String cleanEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';
    final Uri rawUri = Uri.parse('$cleanBase$cleanEndpoint');
    final Uri uri = (queryParams != null && queryParams.isNotEmpty)
        ? rawUri.replace(
            queryParameters: queryParams.map(
              (String key, dynamic value) =>
                  MapEntry<String, String>(key, value.toString()),
            ),
          )
        : rawUri;

    try {
      final http.Response response = await client
          .get(uri, headers: _buildHeaders(customHeaders: headers))
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final Uri uri = _resolveUri(endpoint, queryParams);
    try {
      final http.Response response = await client
          .post(
            uri,
            headers: _buildHeaders(customHeaders: headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final Uri uri = _resolveUri(endpoint, queryParams);
    try {
      final http.Response response = await client
          .put(
            uri,
            headers: _buildHeaders(customHeaders: headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final Uri uri = _resolveUri(endpoint, queryParams);
    try {
      final http.Response response = await client
          .patch(
            uri,
            headers: _buildHeaders(customHeaders: headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  Future<dynamic> delete(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final Uri uri = _resolveUri(endpoint, queryParams);
    try {
      final http.Response response = await client
          .delete(
            uri,
            headers: _buildHeaders(customHeaders: headers),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(timeout);

      return _handleResponse(response);
    } catch (e) {
      _handleError(e);
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic responseData;
    try {
      if (response.body.isNotEmpty) {
        responseData = jsonDecode(response.body);
      }
    } catch (_) {
      responseData = response.body;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return responseData;
    }

    String message = 'Request failed with status: ${response.statusCode}';
    if (responseData is Map && responseData['message'] != null) {
      message = responseData['message'].toString();
    } else if (responseData is Map && responseData['error'] != null) {
      message = responseData['error'].toString();
    }

    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      data: responseData,
    );
  }

  Never _handleError(dynamic error) {
    if (error is ApiException) {
      throw error;
    }
    throw ApiException(message: error.toString());
  }
}
