// lib/services/share_service.dart
import 'package:battery_plus/battery_plus.dart';

class ShareService {
  final Battery _battery = Battery();

  Future<int> getBatteryPercent() async {
    return await _battery.batteryLevel;
  }

  /// Later connect to backend: send location & battery to group members
  Future<void> shareToGroup({
    required bool incognito,
    required String groupId,
    required double lat,
    required double lng,
  }) async {
    if (incognito) return;

    final battery = await getBatteryPercent();

    // ✅ Replace with your FastAPI POST request
    // await dio.post("/groups/$groupId/location", data: {...});

    // For now just debug print
    // ignore: avoid_print
    print("Sharing to group=$groupId => ($lat,$lng), battery=$battery%");
  }
}
