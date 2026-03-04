// App/frontend/mobile/lib/services/group_api.dart
import 'package:dio/dio.dart';

class GroupApi {
  final Dio dio;
  GroupApi(this.dio);

  Future<List<dynamic>> getGroups() async {
    final res = await dio.get("/groups");
    return res.data["groups"] as List<dynamic>;
  }

  Future<Map<String, dynamic>> createGroup(String name) async {
    final res = await dio.post("/groups", data: {"name": name});
    return res.data["group"];
  }

  Future<Map<String, dynamic>> addMember({
    required String groupId,
    required String name,
    required String phone,
  }) async {
    final res = await dio.post("/groups/$groupId/members", data: {
      "name": name,
      "phone": phone,
    });
    return res.data;
  }

  Future<Map<String, dynamic>> share({
    required String groupId,
    required String userId,
    required double lat,
    required double lng,
    required int battery,
    required bool incognito,
  }) async {
    final res = await dio.post("/groups/$groupId/share", data: {
      "user_id": userId,
      "lat": lat,
      "lng": lng,
      "battery": battery,
      "incognito": incognito,
    });
    return res.data as Map<String, dynamic>;
  }

  // / ✅ get latest shares of all members in group
  Future<List<dynamic>> getLatestShares(String groupId) async {
    final res = await dio.get("/groups/$groupId/latest");
    return res.data["latest"] as List<dynamic>;
  }

  Future<Map<String, dynamic>> sos({
    required String groupId,
    required String userId,
    required double lat,
    required double lng,
    required int battery,
    String message = "SOS! Need help immediately!",
  }) async {
    final res = await dio.post("/groups/$groupId/sos", data: {
      "user_id": userId,
      "lat": lat,
      "lng": lng,
      "battery": battery,
      "message": message,
    });
    return res.data as Map<String, dynamic>;
  }
}
