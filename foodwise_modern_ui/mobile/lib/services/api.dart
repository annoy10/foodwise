import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

class Api {
  static const _configuredBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static String get base => _configuredBase.isNotEmpty
      ? _configuredBase
      : (kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000');
  String? token;

  Future<dynamic> request(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$base$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    late http.Response response;
    final data = body == null ? null : jsonEncode(body);
    if (method == 'PUT') {
      response = await http.put(uri, headers: headers, body: data);
    } else if (method == 'POST') {
      response = await http.post(uri, headers: headers, body: data);
    } else if (method == 'DELETE') {
      response = await http.delete(uri, headers: headers);
    } else {
      response = await http.get(uri, headers: headers);
    }
    final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    if (response.statusCode >= 400) {
      throw Exception(decoded is Map ? decoded['detail'] : 'Request failed (${response.statusCode})');
    }
    return decoded;
  }

  Future<void> login(String email, String password) async {
    final result = await request('POST', '/auth/login', body: {'email': email, 'password': password});
    token = result['access_token'] as String;
  }

  Future<void> register(String name, String email, String password) async {
    await request('POST', '/auth/register', body: {'name': name, 'email': email, 'password': password});
    await login(email, password);
  }

  Future<List<dynamic>> foods() async => (await request('GET', '/foods')) as List<dynamic>;

  Future<Map<String, dynamic>> summary(String date) async =>
      (await request('GET', '/meals/summary?on=$date')) as Map<String, dynamic>;

  Future<void> addFood(String name, double calories, double protein, double carbs, double fat) async {
    await request('POST', '/foods', body: {
      'name': name, 'calories': calories, 'protein': protein, 'carbs': carbs, 'fat': fat,
    });
  }

  Future<List<dynamic>> meals(String date) async =>
      (await request('GET', '/meals?on=$date')) as List<dynamic>;

  Future<void> deleteMeal(int id) async {
    await request('DELETE', '/meals/$id');
  }

  Future<void> addMeal(int foodId, String mealType, double grams, String date) async {
    await request('POST', '/meals', body: {
      'food_id': foodId, 'meal_type': mealType, 'quantity_grams': grams, 'eaten_on': date
    });
  }
  Future<Map<String, dynamic>> rangeReport(String start, String end) async =>
      (await request('GET', '/reports/summary?start_date=$start&end_date=$end')) as Map<String, dynamic>;
  Future<Map<String, dynamic>> goals() async => (await request('GET', '/goals')) as Map<String, dynamic>;
  Future<void> saveGoals(Map<String, dynamic> data) async => await request('PUT', '/goals', body: data);
  Future<Map<String, dynamic>> profile() async => (await request('GET', '/profile')) as Map<String, dynamic>;
  Future<void> saveProfile(Map<String, dynamic> data) async => await request('PUT', '/profile', body: data);
  Future<Map<String, dynamic>> water(String on) async => (await request('GET', '/water?on=$on')) as Map<String, dynamic>;
  Future<void> addWater(String on, int ml) async => await request('POST', '/water', body: {'consumed_on':on,'amount_ml':ml});
  Future<void> deleteWater(int id) async => await request('DELETE', '/water/$id');
  Future<List<dynamic>> favorites() async => (await request('GET', '/favorites')) as List<dynamic>;
  Future<void> favorite(int id) async => await request('POST', '/favorites/$id');
  Future<void> unfavorite(int id) async => await request('DELETE', '/favorites/$id');
  Future<void> editMeal(int id,int foodId,String type,double grams,String date) async => await request('PUT', '/meals/$id',body: {'food_id':foodId,'meal_type':type,'quantity_grams':grams,'eaten_on':date});
  Future<Map<String, dynamic>> askRag(String message) async =>
      Map<String, dynamic>.from(await request('POST', '/chat', body: {'message': message}));
  String pdfUrl(String start,String end) => '$base/reports/pdf?start_date=$start&end_date=$end';

}
