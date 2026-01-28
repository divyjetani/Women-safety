// app/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'connectivity_service.dart';
import '../models/models.dart';
import 'package:mobile/conn_url.dart';
import 'package:mobile/models/bubble_model.dart';

class ApiService {
  static const String baseUrl = ApiUrls.baseUrl;

  // ✅ request timeout
  static const Duration _timeout = Duration(seconds: 12);

  // ✅ common headers (adds token automatically)
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

  // ✅ Handle Map response
  static Future<Map<String, dynamic>> _makeRequest(
      Future<http.Response> Function() request,
      ) async {
    try {
      final isConnected = await ConnectivityService.isConnected();
      if (!isConnected) {
        throw Exception('No internet connection');
      }

      final response = await request().timeout(_timeout);

      // ✅ decode safely (some APIs may return empty body)
      dynamic decoded;
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      } else {
        decoded = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) return decoded;

        // ✅ if response is List but method expects Map
        return {"data": decoded};
      } else {
        // ✅ try reading fastapi "detail"
        if (decoded is Map && decoded["detail"] != null) {
          throw Exception(decoded["detail"].toString());
        }
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ✅ Handle List response
  static Future<List<dynamic>> _makeListRequest(
      Future<http.Response> Function() request,
      ) async {
    try {
      final isConnected = await ConnectivityService.isConnected();
      if (!isConnected) {
        throw Exception('No internet connection');
      }

      final response = await request().timeout(_timeout);

      dynamic decoded;
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      } else {
        decoded = [];
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is List) return decoded;

        // ✅ sometimes API sends: { "data": [ ... ] }
        if (decoded is Map && decoded["data"] is List) {
          return decoded["data"];
        }

        return [];
      } else {
        if (decoded is Map && decoded["detail"] != null) {
          throw Exception(decoded["detail"].toString());
        }
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  // ==========================
  // ✅ AUTH
  // ==========================

  static Future<LoginResponse> login(String phone) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/login'),
        headers: await _headers(),
        body: jsonEncode({'phone': phone}),
      );
    });

    return LoginResponse.fromJson(jsonResponse);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userString = prefs.getString('user');

    if (userString != null) {
      final json = jsonDecode(userString);
      return User.fromJson(json);
    }

    return null;
  }

  static Future<void> saveCurrentUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user', jsonEncode(user.toJson()));

    // ✅ example token storage (replace with real backend token)
    await prefs.setString(
      'token',
      'token_${user.id}_${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token') != null;
  }

  // ==========================
  // ✅ SOS
  // ==========================

  static Future<SOSResponse> sendSOS({
    required int userId,
    required String location,
    String? message,
  }) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/sos'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          'user_id': userId,
          'location': location,
          'message': message,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    });

    return SOSResponse.fromJson(jsonResponse);
  }

  // ==========================
  // ✅ HOME APIs
  // ==========================

  static Future<SafetyStats> getSafetyStats(int userId) async {
    try {
      final jsonResponse = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/home/safety-stats?user_id=$userId'),
          headers: await _headers(withAuth: true),
        );
      });

      // ✅ cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_stats_$userId', jsonEncode(jsonResponse));

      return SafetyStats.fromJson(jsonResponse);
    } catch (e) {
      // ✅ fallback cached
      final prefs = await SharedPreferences.getInstance();
      final cachedStats = prefs.getString('cached_stats_$userId');

      if (cachedStats != null) {
        final json = jsonDecode(cachedStats);
        return SafetyStats.fromJson(json);
      }

      // ✅ default
      return SafetyStats(
        safetyScore: 85,
        safeZones: 8,
        alertsToday: 1,
        checkins: 15,
        sosUsed: 0,
      );
    }
  }

  static Future<List<RecentActivity>> getRecentActivity(int userId) async {
    try {
      final jsonList = await _makeListRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/home/recent-activity?user_id=$userId'),
          headers: await _headers(withAuth: true),
        );
      });

      // ✅ cache list
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_activity_$userId', jsonEncode(jsonList));

      return jsonList.map((e) => RecentActivity.fromJson(e)).toList();
    } catch (e) {
      // ✅ cached fallback
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_activity_$userId');

      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        return data.map((item) => RecentActivity.fromJson(item)).toList();
      }

      return [];
    }
  }

  // ==========================
  // ✅ THREAT REPORTS
  // ==========================

  static Future<List<ThreatReport>> getThreatReports() async {
    try {
      final jsonResponse = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/threat-reports'),
          headers: await _headers(withAuth: true),
        );
      });

      List<dynamic> data;

      // ✅ supports: {results: []} OR []
      if (jsonResponse.containsKey('results') && jsonResponse['results'] is List) {
        data = jsonResponse['results'];
      } else if (jsonResponse.containsKey('data') && jsonResponse['data'] is List) {
        data = jsonResponse['data'];
      } else {
        data = [];
      }

      // ✅ cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_threat_reports', jsonEncode(data));

      return data.map((item) => ThreatReport.fromJson(item)).toList();
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_threat_reports');

      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        return data.map((item) => ThreatReport.fromJson(item)).toList();
      }

      return [];
    }
  }

  // ==========================
  // ✅ PROFILE APIs
  // ==========================

  static Future<Map<String, dynamic>> getProfile(int userId) async {
    return await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/profile/$userId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String name,
    required String email,
  }) async {
    return await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/profile/$userId'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({"name": name, "email": email}),
      );
    });
  }

  static Future<Map<String, dynamic>> updateSettings({
    required int userId,
    required bool notifications,
    required bool locationSharing,
  }) async {
    return await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/profile/$userId/settings'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          "notifications": notifications,
          "locationSharing": locationSharing,
        }),
      );
    });
  }

  static Future<List<dynamic>> getEmergencyContacts(int userId) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/profile/$userId/emergency-contacts'),
        headers: await _headers(withAuth: true),
      );
    });

    return (jsonResponse["contacts"] ?? []) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> addEmergencyContact({
    required int userId,
    required String name,
    required String phone,
    bool isPrimary = false,
  }) async {
    return await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/profile/$userId/emergency-contacts'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          "name": name,
          "phone": phone,
          "isPrimary": isPrimary,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> deleteEmergencyContact({
    required int userId,
    required int contactId,
  }) async {
    return await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/profile/$userId/emergency-contacts/$contactId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> setPrimaryContact({
    required int userId,
    required int contactId,
  }) async {
    return await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/profile/$userId/emergency-contacts/$contactId/primary'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  // ==========================
  // ✅ NOTIFICATIONS APIs
  // ==========================

  static Future<List<dynamic>> getNotifications(int userId) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/notifications/$userId'),
        headers: await _headers(withAuth: true),
      );
    });

    return (jsonResponse["notifications"] ?? []) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> markNotificationRead({
    required int userId,
    required int notificationId,
  }) async {
    return await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/notifications/$userId/$notificationId/read'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  // ==========================
  // ✅ NEW: QUICK ACTION DETAILS (no Dio)
  // ==========================

  static Future<Map<String, dynamic>> getQuickActionDetails({
    required int userId,
    required String action,
  }) async {
    return await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/home/quick-action/$action?user_id=$userId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  // ==========================
  // ✅ NEW: GUARDIANS (no Dio)
  // ==========================

  static Future<List<dynamic>> getGuardians({
    required int userId,
  }) async {
    return await _makeListRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/guardians?user_id=$userId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  // ==========================
  // ✅ NEW: HISTORY (no Dio)
  // ==========================

  static Future<List<dynamic>> getHistory({
    required int userId,
  }) async {
    return await _makeListRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/history?user_id=$userId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  // ==========================
  // ✅ NEW: HELP & SUPPORT FAQs (no Dio)
  // ==========================

  static Future<List<dynamic>> getFaqs() async {
    return await _makeListRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/help/faqs'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> uploadRecording({
    required int userId,
    required String filePath,
    required String startLocation,
    required String endLocation,
    required String startedAt,
    required String endedAt,
    required int durationSeconds,
  }) async {
    return await _makeRequest(() async {
      final uri = Uri.parse('$baseUrl/recordings/upload');

      final request = http.MultipartRequest("POST", uri);

      request.fields["user_id"] = userId.toString();
      request.fields["start_location"] = startLocation;
      request.fields["end_location"] = endLocation;
      request.fields["started_at"] = startedAt;
      request.fields["ended_at"] = endedAt;
      request.fields["duration_seconds"] = durationSeconds.toString();

      request.files.add(await http.MultipartFile.fromPath("video", filePath));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception("Upload failed: ${response.statusCode} ${response.body}");
    });
  }

  static Future<Map<String, dynamic>> uploadDualRecording({
    required int userId,
    required String frontVideoPath,
    required String backVideoPath,
    required String startImagePath,
    required String endImagePath,
    required String startedAt,
    required String endedAt,
    required int durationSeconds,
    required String startLat,
    required String startLng,
    required String endLat,
    required String endLng,
  }) async {
    return await _makeRequest(() async {
      final uri = Uri.parse('$baseUrl/recordings/upload-dual');

      final request = http.MultipartRequest("POST", uri);

      request.fields["user_id"] = userId.toString();
      request.fields["started_at"] = startedAt;
      request.fields["ended_at"] = endedAt;
      request.fields["duration_seconds"] = durationSeconds.toString();

      request.fields["start_lat"] = startLat;
      request.fields["start_lng"] = startLng;
      request.fields["end_lat"] = endLat;
      request.fields["end_lng"] = endLng;

      request.files.add(await http.MultipartFile.fromPath("front_video", frontVideoPath));
      request.files.add(await http.MultipartFile.fromPath("back_video", backVideoPath));
      request.files.add(await http.MultipartFile.fromPath("start_image", startImagePath));
      request.files.add(await http.MultipartFile.fromPath("end_image", endImagePath));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception("Upload failed: ${response.statusCode} ${response.body}");
    });
  }

  static Future<Map<String, dynamic>> uploadAnonymousRecording({
    required int userId,
    required String frontVideoPath,
    required String backVideoPath,
    required String startImagePath,
    required String endImagePath,
    required String startedAt,
    required String endedAt,
    required int durationSeconds,
    required String startLat,
    required String startLng,
    required String endLat,
    required String endLng,
  }) async {
    final isConnected = await ConnectivityService.isConnected();
    if (!isConnected) throw Exception("No internet connection");

    final uri = Uri.parse('$baseUrl/recordings/upload-anonymous');
    final request = http.MultipartRequest("POST", uri);

    request.fields["user_id"] = userId.toString();
    request.fields["started_at"] = startedAt;
    request.fields["ended_at"] = endedAt;
    request.fields["duration_seconds"] = durationSeconds.toString();

    request.fields["start_lat"] = startLat;
    request.fields["start_lng"] = startLng;
    request.fields["end_lat"] = endLat;
    request.fields["end_lng"] = endLng;

    request.files.add(await http.MultipartFile.fromPath("front_video", frontVideoPath));
    request.files.add(await http.MultipartFile.fromPath("back_video", backVideoPath));
    request.files.add(await http.MultipartFile.fromPath("start_image", startImagePath));
    request.files.add(await http.MultipartFile.fromPath("end_image", endImagePath));

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception("Upload failed (${response.statusCode}): ${response.body}");
  }


  static Future<Map<String, dynamic>> uploadFakeCallRecording({
    required int userId,
    required String backVideoPath,
    required String startImagePath,
    required String endImagePath,
    required String startedAt,
    required String endedAt,
    required int durationSeconds,
    required String startLat,
    required String startLng,
    required String endLat,
    required String endLng,
  }) async {
    final isConnected = await ConnectivityService.isConnected();
    if (!isConnected) throw Exception("No internet connection");

    final uri = Uri.parse('$baseUrl/recordings/upload-fakecall');

    final request = http.MultipartRequest("POST", uri);

    request.fields["user_id"] = userId.toString();
    request.fields["started_at"] = startedAt;
    request.fields["ended_at"] = endedAt;
    request.fields["duration_seconds"] = durationSeconds.toString();

    request.fields["start_lat"] = startLat;
    request.fields["start_lng"] = startLng;
    request.fields["end_lat"] = endLat;
    request.fields["end_lng"] = endLng;

    request.files.add(await http.MultipartFile.fromPath("back_video", backVideoPath));
    request.files.add(await http.MultipartFile.fromPath("start_image", startImagePath));
    request.files.add(await http.MultipartFile.fromPath("end_image", endImagePath));

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) return jsonDecode(response.body);

    throw Exception("Upload failed (${response.statusCode}): ${response.body}");
  }

  static Future<Map<String, dynamic>> askAI({
    required int userId,
    required String question,
    required bool detailed,
  }) async {
    return await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/ai/ask'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": userId,
          "question": question,
          "detailed": detailed,
        }),
      );
    });
  }

  // ==========================
// ✅ BUBBLES / GROUPS
// ==========================

  static Future<CreateBubbleResponse> createBubble({
    required String name,
    required int icon,
    required int color,
  }) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/bubble/create'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          "name": name,
          "icon": icon,
          "color": color,
        }),
      );
    });

    return CreateBubbleResponse.fromJson(jsonResponse);
  }

  static Future<Map<String, dynamic>> joinBubble(String token) async {
    return await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/bubble/join/$token'),
        headers: await _headers(withAuth: true),
      );
    });
  }

}
