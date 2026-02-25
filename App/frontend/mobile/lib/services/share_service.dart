// lib/services/share_service.dart
import 'package:battery_plus/battery_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mobile/conn_url.dart';
import 'api_service.dart';

class ShareService {
  final Battery _battery = Battery();
  static const String baseUrl = ApiUrls.baseUrl;

  Future<int> getBatteryPercent() async {
    return await _battery.batteryLevel;
  }

  /// Share location & battery to all bubbles the user is a member of
  Future<void> shareToGroup({
    required bool incognito,
    required String groupId,
    required double lat,
    required double lng,
  }) async {
    if (incognito) return;

    try {
      final battery = await getBatteryPercent();
      final user = await ApiService.getCurrentUser();
      
      if (user == null) return;

      // Call the backend share-location endpoint
      final response = await http.post(
        Uri.parse('$baseUrl/bubble/share-location'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'user_id': user.id,  // Send as int, not string
          'lat': lat,
          'lng': lng,
          'battery': battery,
          'incognito': incognito,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // ignore: avoid_print
        print("Location shared: ($lat,$lng), battery=$battery%");
      }
    } catch (e) {
      // Silently fail - don't interrupt user experience
      // ignore: avoid_print
      print("Failed to share location: $e");
    }
  }
}
