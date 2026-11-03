
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class Api {
  static const String _configuredBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  // Local Supabase DB connection is currently failing.
  // Use the working Render backend by default.
  static String get base => _configuredBase.isNotEmpty
      ? _configuredBase
      : 'https://foodwise-1-bksq.onrender.com';

  static const FlutterSecureStorage _storage =
  FlutterSecureStorage();

  static const String _accessKey = 'foodwise_access_token';
  static const String _refreshKey = 'foodwise_refresh_token';

  String? token;

  Future<bool>? _refreshInFlight;

  // ==========================================
  // TOKEN STORAGE
  // ==========================================

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    final access = data['access_token'];
    final refresh = data['refresh_token'];

    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw Exception('Invalid login response: tokens missing');
    }

    await _storage.write(
      key: _refreshKey,
      value: refresh,
    );

    await _storage.write(
      key: _accessKey,
      value: access,
    );

    token = access;
  }

  Future<void> _clearTokens() async {
    token = null;

    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
  }

  // ==========================================
  // HTTP HELPERS
  // ==========================================

  Future<http.Response> _send(
      String method,
      String path, {
        Map<String, dynamic>? body,
        String? accessToken,
      }) async {
    final uri = Uri.parse('$base$path');

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final data = body == null ? null : jsonEncode(body);

    switch (method.toUpperCase()) {
      case 'POST':
        return http
            .post(uri, headers: headers, body: data)
            .timeout(const Duration(seconds: 30));

      case 'PUT':
        return http
            .put(uri, headers: headers, body: data)
            .timeout(const Duration(seconds: 30));

      case 'DELETE':
        return http
            .delete(uri, headers: headers)
            .timeout(const Duration(seconds: 30));

      default:
        return http
            .get(uri, headers: headers)
            .timeout(const Duration(seconds: 30));
    }
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;

    try {
      return jsonDecode(response.body);
    } on FormatException {
      throw Exception(
        'Invalid server response (${response.statusCode})',
      );
    }
  }

  dynamic _checkResponse(http.Response response) {
    final decoded = _decode(response);

    if (response.statusCode >= 400) {
      String message = 'Request failed (${response.statusCode})';

      if (decoded is Map && decoded['detail'] != null) {
        message = decoded['detail'].toString();
      }

      throw Exception(message);
    }

    return decoded;
  }

  // ==========================================
  // REFRESH TOKEN
  // ==========================================

  Future<bool> _performRefresh() async {
    final savedRefresh = await _storage.read(
      key: _refreshKey,
    );

    if (savedRefresh == null || savedRefresh.isEmpty) {
      return false;
    }

    final response = await _send(
      'POST',
      '/auth/refresh',
      body: {
        'refresh_token': savedRefresh,
      },
    );

    if (response.statusCode == 401 ||
        response.statusCode == 403) {
      await _clearTokens();
      return false;
    }

    final result = _checkResponse(response);

    if (result is! Map) {
      throw Exception('Invalid refresh response');
    }

    await _saveTokens(
      Map<String, dynamic>.from(result),
    );

    return true;
  }

  // Prevent multiple simultaneous refresh requests.
  Future<bool> _refreshSession() async {
    final existing = _refreshInFlight;

    if (existing != null) {
      return existing;
    }

    final future = _performRefresh();
    _refreshInFlight = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshInFlight, future)) {
        _refreshInFlight = null;
      }
    }
  }

  // ==========================================
  // RESTORE LOGIN ON APP START
  // ==========================================

  Future<bool> restoreSession() async {
    try {
      token = await _storage.read(key: _accessKey);

      final savedRefresh = await _storage.read(
        key: _refreshKey,
      );

      if (savedRefresh == null || savedRefresh.isEmpty) {
        token = null;
        return false;
      }

      // Validate session and rotate refresh token.
      return await _refreshSession();
    } catch (e) {
      debugPrint('Restore session failed: $e');

      // On temporary network errors, keep saved credentials.
      // An existing access token may still be usable.
      return token != null && token!.isNotEmpty;
    }
  }

  // ==========================================
  // REQUEST WITH AUTOMATIC TOKEN REFRESH
  // ==========================================

  Future<dynamic> request(
      String method,
      String path, {
        Map<String, dynamic>? body,
      }) async {
    final usedToken = token;

    var response = await _send(
      method,
      path,
      body: body,
      accessToken: usedToken,
    );

    final isAuthEndpoint = path.startsWith('/auth/login') ||
        path.startsWith('/auth/register') ||
        path.startsWith('/auth/refresh') ||
        path.startsWith('/auth/logout');

    if (response.statusCode == 401 &&
        !isAuthEndpoint &&
        usedToken != null) {
      // Another request may already have refreshed the token.
      bool canRetry = token != null && token != usedToken;

      if (!canRetry) {
        canRetry = await _refreshSession();
      }

      if (canRetry && token != null) {
        response = await _send(
          method,
          path,
          body: body,
          accessToken: token,
        );
      }
    }

    return _checkResponse(response);
  }

  // ==========================================
  // LOGIN
  // ==========================================

  Future<void> login(
      String email,
      String password,
      ) async {
    final response = await _send(
      'POST',
      '/auth/login',
      body: {
        'email': email,
        'password': password,
      },
    );

    final result = _checkResponse(response);

    if (result is! Map) {
      throw Exception('Invalid login response');
    }

    await _saveTokens(
      Map<String, dynamic>.from(result),
    );
  }

  // ==========================================
  // REGISTER
  // ==========================================

  Future<void> register(
      String name,
      String email,
      String password,
      ) async {
    await request(
      'POST',
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
      },
    );

    // Login automatically after registration.
    await login(email, password);
  }

  // ==========================================
  // LOGOUT
  // ==========================================

  Future<void> logout() async {
    final savedRefresh = await _storage.read(
      key: _refreshKey,
    );

    // Remove local credentials immediately.
    await _clearTokens();

    if (savedRefresh == null || savedRefresh.isEmpty) {
      return;
    }

    try {
      await _send(
        'POST',
        '/auth/logout',
        body: {
          'refresh_token': savedRefresh,
        },
      );
    } catch (e) {
      debugPrint('Remote logout failed: $e');
    }
  }

  // ==========================================
  // FOOD
  // ==========================================

  Future<List<dynamic>> foods() async =>
      (await request('GET', '/foods')) as List<dynamic>;

  Future<void> addFood(
      String name,
      double calories,
      double protein,
      double carbs,
      double fat,
      ) async {
    await request(
      'POST',
      '/foods',
      body: {
        'name': name,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      },
    );
  }

  // ==========================================
  // MEALS
  // ==========================================

  Future<List<dynamic>> meals(String date) async =>
      (await request('GET', '/meals?on=$date'))
      as List<dynamic>;

  Future<void> deleteMeal(int id) async {
    await request('DELETE', '/meals/$id');
  }

  Future<void> addMeal(
      int foodId,
      String mealType,
      double grams,
      String date,
      ) async {
    await request(
      'POST',
      '/meals',
      body: {
        'food_id': foodId,
        'meal_type': mealType,
        'quantity_grams': grams,
        'eaten_on': date,
      },
    );
  }

  Future<void> editMeal(
      int id,
      int foodId,
      String type,
      double grams,
      String date,
      ) async {
    await request(
      'PUT',
      '/meals/$id',
      body: {
        'food_id': foodId,
        'meal_type': type,
        'quantity_grams': grams,
        'eaten_on': date,
      },
    );
  }

  // ==========================================
  // SUMMARY AND REPORTS
  // ==========================================

  Future<Map<String, dynamic>> summary(
      String date,
      ) async =>
      (await request(
        'GET',
        '/meals/summary?on=$date',
      )) as Map<String, dynamic>;

  Future<Map<String, dynamic>> rangeReport(
      String start,
      String end,
      ) async =>
      (await request(
        'GET',
        '/reports/summary?start_date=$start&end_date=$end',
      )) as Map<String, dynamic>;

  String pdfUrl(String start, String end) =>
      '$base/reports/pdf?start_date=$start&end_date=$end';

  // ==========================================
  // GOALS
  // ==========================================

  Future<Map<String, dynamic>> goals() async =>
      (await request('GET', '/goals'))
      as Map<String, dynamic>;

  Future<void> saveGoals(
      Map<String, dynamic> data,
      ) async {
    await request('PUT', '/goals', body: data);
  }

  // ==========================================
  // PROFILE
  // ==========================================

  Future<Map<String, dynamic>> profile() async =>
      (await request('GET', '/profile'))
      as Map<String, dynamic>;

  Future<void> saveProfile(
      Map<String, dynamic> data,
      ) async {
    await request('PUT', '/profile', body: data);
  }

  // ==========================================
  // WATER
  // ==========================================

  Future<Map<String, dynamic>> water(
      String on,
      ) async =>
      (await request('GET', '/water?on=$on'))
      as Map<String, dynamic>;

  Future<void> addWater(
      String on,
      int ml,
      ) async {
    await request(
      'POST',
      '/water',
      body: {
        'consumed_on': on,
        'amount_ml': ml,
      },
    );
  }

  Future<void> deleteWater(int id) async {
    await request('DELETE', '/water/$id');
  }

  // ==========================================
  // FAVORITES
  // ==========================================

  Future<List<dynamic>> favorites() async =>
      (await request('GET', '/favorites'))
      as List<dynamic>;

  Future<void> favorite(int id) async {
    await request('POST', '/favorites/$id');
  }

  Future<void> unfavorite(int id) async {
    await request('DELETE', '/favorites/$id');
  }

  // ==========================================
  // CHATBOT / RAG
  // ==========================================

  Future<Map<String, dynamic>> askRag(
      String message,
      ) async =>
      Map<String, dynamic>.from(
        await request(
          'POST',
          '/chat',
          body: {
            'message': message,
          },
        ),
      );
}
