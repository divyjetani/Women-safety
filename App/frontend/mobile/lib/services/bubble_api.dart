// App/frontend/mobile/lib/services/bubble_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/conn_url.dart';
import 'package:mobile/models/bubble_model.dart';

class BubbleAPI {
  static const String baseUrl = ApiUrls.baseUrl;
  static const Duration _timeout = Duration(seconds: 10);

  static Future<Map<String, String>> _headers({bool withAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (withAuth) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  // ✅ create bubble - 6-digit code generation
  static Future<Bubble> createBubble({
    required String name,
    required int icon,
    required int color,
    required int adminId,
    required String adminName,
  }) async {
    try {
      final headers = await _headers();
      final response = await http.post(
        Uri.parse('$baseUrl/bubble/create'),
        headers: headers,
        body: jsonEncode({
          'name': name,
          'icon': icon,
          'color': color,
          'admin_id': adminId,
          'admin_name': adminName,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Bubble.fromJson(json['bubble']);
      } else {
        throw Exception('Failed to create bubble: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ✅ join bubble - enter 6-digit code
  static Future<Bubble> joinBubble({
    required String code,
    required int userId,
    required String userName,
  }) async {
    try {
      final headers = await _headers();
      final response = await http.post(
        Uri.parse('$baseUrl/bubble/join'),
        headers: headers,
        body: jsonEncode({
          'code': code,
          'user_id': userId,
          'name': userName,
        }),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Bubble.fromJson(json['bubble']);
      } else if (response.statusCode == 404) {
        throw Exception('Invalid bubble code');
      } else {
        throw Exception('Failed to join bubble: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<Bubble> getBubble(String code) async {
    try {
      final headers = await _headers();
      final response = await http.get(
        Uri.parse('$baseUrl/bubble/$code'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Bubble.fromJson(json['bubble']);
      } else if (response.statusCode == 404) {
        throw Exception('Bubble not found');
      } else {
        throw Exception('Failed to fetch bubble: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<List<Bubble>> getUserBubbles(int userId) async {
    try {
      final headers = await _headers();
      final response = await http.get(
        Uri.parse('$baseUrl/bubble/list/$userId'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final bubbles = (json['bubbles'] as List)
            .map((b) => Bubble.fromJson(b))
            .toList();
        return bubbles;
      } else {
        throw Exception('Failed to fetch bubbles: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> shareLocation({
    required int userId,
    required double lat,
    required double lng,
    required int battery,
    bool incognito = false,
  }) async {
    try {
      final headers = await _headers();
      final response = await http.post(
        Uri.parse('$baseUrl/bubble/share-location'),
        headers: headers,
        body: jsonEncode({
          'user_id': userId,
          'lat': lat,
          'lng': lng,
          'battery': battery,
          'incognito': incognito,
        }),
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to share location: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ✅ delete bubble (admin only)
  static Future<void> deleteBubble({
    required String code,
    required int adminId,
  }) async {
    try {
      final headers = await _headers();
      final response = await http.delete(
        Uri.parse('$baseUrl/bubble/$code?admin_id=$adminId'),
        headers: headers,
      ).timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('Failed to delete bubble: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
