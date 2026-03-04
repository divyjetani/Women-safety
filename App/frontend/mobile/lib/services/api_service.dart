// App/frontend/mobile/lib/services/api_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'connectivity_service.dart';
import '../models/models.dart';
import 'package:mobile/conn_url.dart';
import 'package:mobile/models/bubble_model.dart';
import 'background_location_service.dart';

class ApiService {
  static const String baseUrl = ApiUrls.baseUrl;

  static String _absoluteUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) {
      return '$baseUrl$value';
    }
    return '$baseUrl/$value';
  }

  static const Duration _timeout = Duration(seconds: 12);
  static const Duration _aiTimeout = Duration(seconds: 120);

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

  static Future<Map<String, dynamic>> _makeRequest(
      Future<http.Response> Function() request,
      {Duration? timeout}
      ) async {
    try {
      final isConnected = await ConnectivityService.isConnected();
      if (!isConnected) {
        throw Exception('No internet connection');
      }

      final response = await request().timeout(timeout ?? _timeout);

      // ✅ decode safely (some apis may return empty body)
      dynamic decoded;
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      } else {
        decoded = {};
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is Map<String, dynamic>) return decoded;

        // ✅ if response is list but method expects map
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

  static Future<List<dynamic>> _makeListRequest(
      Future<http.Response> Function() request,
      {Duration? timeout}
      ) async {
    try {
      final isConnected = await ConnectivityService.isConnected();
      if (!isConnected) {
        throw Exception('No internet connection');
      }

      final response = await request().timeout(timeout ?? _timeout);

      dynamic decoded;
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      } else {
        decoded = [];
      }

      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (decoded is List) return decoded;

        // ✅ sometimes api sends: { "data": [ ... ] }
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


  static Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: await _headers(),
        body: jsonEncode({'email': email, 'password': password}),
      );
    });

    return LoginResponse.fromJson(jsonResponse);
  }

  static Future<LoginResponse> register({
    required String email,
    required String phone,
    required String password,
    required String gender,
    required String birthdate,
    required String faceImage,
    required bool aadharVerified,
    required List<String> emergencyContacts,
    String username = '',
    bool isPremium = false,
  }) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: await _headers(),
        body: jsonEncode({
          'username': username,
          'email': email,
          'phone': phone,
          'password': password,
          'gender': gender,
          'birthdate': birthdate,
          'face_image': faceImage,
          'aadhar_verified': aadharVerified,
          'emergency_contacts': emergencyContacts,
          'is_premium': isPremium,
        }),
      );
    });

    return LoginResponse.fromJson(jsonResponse);
  }

  static Future<AuthMessageResponse> forgotPassword(String email) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/auth/forgot-password'),
        headers: await _headers(),
        body: jsonEncode({'email': email}),
      );
    });

    return AuthMessageResponse.fromJson(jsonResponse);
  }

  static Future<AuthMessageResponse> resetPassword({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/auth/reset-password'),
        headers: await _headers(),
        body: jsonEncode({
          'email': email,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );
    });

    return AuthMessageResponse.fromJson(jsonResponse);
  }

  static Future<void> logout() async {
    try {
      await BackgroundLocationService.stopBackgroundLocationSharing();
    } catch (_) {
      // ignore - service may already be stopped or unavailable
    }

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

    // if account changed, drop profile/contact caches from previous sessions.
    final previousUserId = prefs.getInt('cached_user_id');
    if (previousUserId != null && previousUserId != user.id) {
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith('cached_profile_') || key.startsWith('cached_contacts_')) {
          await prefs.remove(key);
        }
      }
    }

    await prefs.setString('user', jsonEncode(user.toJson()));
    await prefs.setInt('cached_user_id', user.id);
    await prefs.setString(
      'cached_user_name',
      user.username.trim().isNotEmpty ? user.username.trim() : user.email,
    );
    await prefs.setString('cached_user_email', user.email);

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


  static Future<SOSResponse> sendSOS({
    required int userId,
    required String location,
    double? lat,
    double? lng,
    int? battery,
    String triggerType = 'manual',
    String? triggerReason,
    String? bubbleCode,
    String? cameraFrontImage,
    String? cameraBackImage,
    String? audio10sUrl,
    String? message,
  }) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/sos'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          'user_id': userId,
          'location': location,
          'lat': lat,
          'lng': lng,
          'battery': battery,
          'trigger_type': triggerType,
          'trigger_reason': triggerReason,
          'message': message,
          'bubble_code': bubbleCode,
          'camera_front_image': cameraFrontImage,
          'camera_back_image': cameraBackImage,
          'audio_10s_url': audio10sUrl,
          'timestamp': DateTime.now().toIso8601String(),
        }),
      );
    });

    return SOSResponse.fromJson(jsonResponse);
  }

  static Future<Map<String, dynamic>> startAutomaticSosPending({
    required int userId,
    required String reason,
    required String location,
    double? lat,
    double? lng,
    int? battery,
    String? bubbleCode,
    String? cameraFrontImage,
    String? cameraBackImage,
    String? audio10sUrl,
    String? message,
  }) async {
    return await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/sos/automatic/pending'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          'user_id': userId,
          'reason': reason,
          'location': location,
          'lat': lat,
          'lng': lng,
          'battery': battery,
          'bubble_code': bubbleCode,
          'camera_front_image': cameraFrontImage,
          'camera_back_image': cameraBackImage,
          'audio_10s_url': audio10sUrl,
          'message': message,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> cancelAutomaticSos({
    required String pendingId,
    required int userId,
    String? reason,
  }) async {
    return await _makeRequest(() async {
      return await http.patch(
        Uri.parse('$baseUrl/sos/automatic/$pendingId/cancel'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          'user_id': userId,
          'reason': reason,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> getAutomaticSosStatus({
    required String pendingId,
  }) async {
    return await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/sos/automatic/$pendingId'),
        headers: await _headers(withAuth: true),
      );
    });
  }


  static Future<SafetyStats> getSafetyStats(int userId) async {
    try {
      final jsonResponse = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/home/safety-stats?user_id=$userId'),
          headers: await _headers(withAuth: true),
        );
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_stats_$userId', jsonEncode(jsonResponse));

      return SafetyStats.fromJson(jsonResponse);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cachedStats = prefs.getString('cached_stats_$userId');

      if (cachedStats != null) {
        final json = jsonDecode(cachedStats);
        return SafetyStats.fromJson(json);
      }

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

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_activity_$userId', jsonEncode(jsonList));

      return _parseRecentActivities(jsonList);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_activity_$userId');

      if (cached != null) {
        final List<dynamic> data = jsonDecode(cached);
        return _parseRecentActivities(data);
      }

      return [];
    }
  }

  static List<RecentActivity> _parseRecentActivities(List<dynamic> rawList) {
    final List<RecentActivity> parsed = [];
    for (final item in rawList) {
      if (item is Map<String, dynamic>) {
        parsed.add(RecentActivity.fromJson(item));
      } else if (item is Map) {
        parsed.add(RecentActivity.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return parsed;
  }


  static Future<List<ThreatReport>> getThreatReports() async {
    try {
      final jsonResponse = await _makeRequest(() async {
        return await http.get(
          Uri.parse('$baseUrl/threat-reports'),
          headers: await _headers(withAuth: true),
        );
      });

      List<dynamic> data;

      // ✅ supports: {results: []} or []
      if (jsonResponse.containsKey('results') && jsonResponse['results'] is List) {
        data = jsonResponse['results'];
      } else if (jsonResponse.containsKey('data') && jsonResponse['data'] is List) {
        data = jsonResponse['data'];
      } else {
        data = [];
      }

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
    String? name,
    String? email,
    String? phone,
    String? faceImage,
    bool? aadharVerified,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body["name"] = name;
    if (email != null) body["email"] = email;
    if (phone != null) body["phone"] = phone;
    if (faceImage != null) body["face_image"] = faceImage;
    if (aadharVerified != null) body["aadhar_verified"] = aadharVerified;

    return await _makeRequest(() async {
      return await http.put(
        Uri.parse('$baseUrl/profile/$userId'),
        headers: await _headers(withAuth: true),
        body: jsonEncode(body),
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

  static Future<Map<String, dynamic>> deleteNotification({
    required int userId,
    required int notificationId,
  }) async {
    return await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/notifications/$userId/$notificationId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> registerDeviceToken({
    required int userId,
    required String token,
    String platform = 'android',
  }) async {
    return await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/notifications/device-token'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          'user_id': userId,
          'token': token,
          'platform': platform,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> resolveSosEvent({
    required int userId,
    required String eventId,
    String? reason,
  }) async {
    return await _makeRequest(() async {
      return await http.patch(
        Uri.parse('$baseUrl/sos/$eventId/resolve'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          'user_id': userId,
          'resolved_by': 'user',
          'reason': reason,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>> updateSosMedia({
    required int userId,
    required String eventId,
    String? cameraFrontImage,
    String? cameraBackImage,
    String? audio10sUrl,
  }) async {
    return await _makeRequest(() async {
      return await http.patch(
        Uri.parse('$baseUrl/sos/$eventId/media'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          'user_id': userId,
          'camera_front_image': cameraFrontImage,
          'camera_back_image': cameraBackImage,
          'audio_10s_url': audio10sUrl,
        }),
      );
    });
  }

  // ✅ new: quick action details (no dio)

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

  // ✅ new: help & support faqs (no dio)

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

    Future<void> ensureFile(String path, String label) async {
      if (path.trim().isEmpty) {
        throw Exception('$label path is empty');
      }
      if (!await File(path).exists()) {
        throw Exception('$label file not found: $path');
      }
    }

    await ensureFile(frontVideoPath, 'Front video');
    await ensureFile(backVideoPath, 'Back video');
    if (startImagePath.trim().isNotEmpty) {
      await ensureFile(startImagePath, 'Start image');
    }
    if (endImagePath.trim().isNotEmpty) {
      await ensureFile(endImagePath, 'End image');
    }

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
    if (startImagePath.trim().isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath("start_image", startImagePath));
    }
    if (endImagePath.trim().isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath("end_image", endImagePath));
    }

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

    Future<void> ensureFile(String path, String label) async {
      if (path.trim().isEmpty) {
        throw Exception('$label path is empty');
      }
      if (!await File(path).exists()) {
        throw Exception('$label file not found: $path');
      }
    }

    await ensureFile(backVideoPath, 'Back video');
    if (startImagePath.trim().isNotEmpty) {
      await ensureFile(startImagePath, 'Start image');
    }
    if (endImagePath.trim().isNotEmpty) {
      await ensureFile(endImagePath, 'End image');
    }

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
    if (startImagePath.trim().isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath("start_image", startImagePath));
    }
    if (endImagePath.trim().isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath("end_image", endImagePath));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 15));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 200) return jsonDecode(response.body);

    throw Exception("Upload failed (${response.statusCode}): ${response.body}");
  }

  static Future<List<Map<String, dynamic>>> fetchAnonymousRecordingHistory({
    required int userId,
  }) async {
    final data = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/recordings/anonymous-history?user_id=$userId'),
        headers: await _headers(withAuth: true),
      );
    });

    final history = (data['history'] as List<dynamic>? ?? []);
    return history
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> fetchFakeCallRecordingHistory({
    required int userId,
  }) async {
    final data = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/recordings/fakecall-history?user_id=$userId'),
        headers: await _headers(withAuth: true),
      );
    });

    final history = (data['history'] as List<dynamic>? ?? []);
    return history
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e.cast<String, dynamic>()))
        .toList();
  }

  static Future<List<int>> downloadMediaBytes(String mediaUrl) async {
    final response = await http.get(Uri.parse(_absoluteUrl(mediaUrl))).timeout(_timeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw Exception('Failed to download media (${response.statusCode})');
  }

  static Future<Map<String, dynamic>> deleteAnonymousRecording({
    required int userId,
    required String recordingId,
  }) async {
    return await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/recordings/anonymous/$recordingId?user_id=$userId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> deleteFakeCallRecording({
    required int userId,
    required String recordingId,
  }) async {
    return await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/recordings/fakecall/$recordingId?user_id=$userId'),
        headers: await _headers(withAuth: true),
      );
    });
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
    }, timeout: _aiTimeout);
  }

  static Future<Map<String, dynamic>> getAnalyticsOverview({
    required int userId,
  }) async {
    return await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/analytics/overview?user_id=$userId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> generateAiSuggestions({
    required int userId,
  }) async {
    return await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/ai/suggestions/generate'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          'user_id': userId,
        }),
      );
    });
  }


  static Future<CreateBubbleResponse> createBubble({
    required String name,
    required int icon,
    required int color,
  }) async {
    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('User not logged in');
    }

    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/bubble/create'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          "name": name,
          "icon": icon,
          "color": color,
          "admin_id": user.id,
          "admin_name": user.username,
        }),
      );
    });

    return CreateBubbleResponse.fromJson(jsonResponse);
  }

  static Future<List<SafetyGroup>> getUserBubbles() async {
    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('User not logged in');
    }

    final jsonResponse = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/bubble/list/${user.id}'),
        headers: await _headers(withAuth: true),
      );
    });

    final bubblesList = jsonResponse["bubbles"] as List<dynamic>? ?? [];
    return bubblesList.map((json) => SafetyGroup.fromJson(json)).toList();
  }

  static Future<SafetyGroup> joinBubbleByCode(String code) async {
    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('User not logged in');
    }

    final jsonResponse = await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/bubble/join'),
        headers: await _headers(withAuth: true),
        body: jsonEncode({
          "code": code,
          "user_id": user.id,
          "name": user.username,
        }),
      );
    });

    return SafetyGroup.fromJson(jsonResponse["group"]);
  }

  static Future<Map<String, dynamic>> joinBubble(String token) async {
    return await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/bubble/join/$token'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> deleteBubble({
    required String code,
    required int adminId,
  }) async {
    return await _makeRequest(() async {
      return await http.delete(
        Uri.parse('$baseUrl/bubble/$code?admin_id=$adminId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> leaveBubble({
    required String code,
    required int userId,
  }) async {
    return await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/bubble/$code/leave?user_id=$userId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> kickBubbleMember({
    required String code,
    required int adminId,
    required int memberUserId,
  }) async {
    return await _makeRequest(() async {
      return await http.post(
        Uri.parse('$baseUrl/bubble/$code/kick?admin_id=$adminId&member_user_id=$memberUserId'),
        headers: await _headers(withAuth: true),
      );
    });
  }

  static Future<Map<String, dynamic>> fetchSafetyScore({
    required double lat,
    required double lng,
    int? userId,
  }) async {
    return await _makeRequest(() async {
      final uri = userId != null
          ? Uri.parse('$baseUrl/safety-score?user_id=$userId')
          : Uri.parse('$baseUrl/safety-score');

      return await http.post(
        uri,
        headers: await _headers(withAuth: true), // or false if no auth needed
        body: jsonEncode({
          "latitude": lat,
          "longitude": lng,
        }),
      );
    });
  }

  static Future<Map<String, dynamic>?> getNearestPoliceStation({
    required double lat,
    required double lng,
  }) async {
    final jsonResponse = await _makeRequest(() async {
      return await http.get(
        Uri.parse('$baseUrl/police-stations/nearest?lat=$lat&lng=$lng'),
        headers: await _headers(withAuth: true),
      );
    });

    final station = jsonResponse['station'];
    if (station is Map<String, dynamic>) {
      return station;
    }
    return null;
  }


}
