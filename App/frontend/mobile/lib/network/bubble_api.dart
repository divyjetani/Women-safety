// App/frontend/mobile/lib/network/bubble_api.dart
import 'package:dio/dio.dart';
import 'package:mobile/conn_url.dart';
import 'dio_client.dart';

class BubbleApi {
  static final Dio _dio = DioClient.create(baseUrl: ApiUrls.baseUrl);

  // / ✅ fastapi: post /groups/{groupid}/sos
  static Future<void> sendSosToBubble({
    required String userId,
    required String username,
    required double lat,
    required double lng,
    required int battery,
    required String groupId, // "bubble"
  }) async {
    final payload = {
      "user_id": userId,
      "lat": lat,
      "lng": lng,
      "battery": battery,
      "message": "SOS from $username 🚨 Need help immediately!",
    };

    await _dio.post("/groups/$groupId/sos", data: payload);
  }

  // / ✅ fastapi: post /groups/{groupid}/share
  static Future<void> shareLiveToBubble({
    required String userId,
    required double lat,
    required double lng,
    required int battery,
    required bool incognito,
    required String groupId,
  }) async {
    final payload = {
      "user_id": userId,
      "lat": lat,
      "lng": lng,
      "battery": battery,
      "incognito": incognito,
    };

    await _dio.post("/groups/$groupId/share", data: payload);
  }
}
