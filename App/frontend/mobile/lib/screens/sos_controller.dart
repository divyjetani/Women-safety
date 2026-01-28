import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:mobile/services/group_api.dart';

class SosController {
  final GroupApi api;
  final Battery _battery = Battery();

  SosController(this.api);

  Future<void> triggerSos({
    required String groupId, // bubble
    required String userId,
    required bool incognito,
  }) async {
    if (incognito) {
      // If user incognito, we should not send SOS to group
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final battery = await _battery.batteryLevel;

    await api.sos(
      groupId: groupId,
      userId: userId,
      lat: pos.latitude,
      lng: pos.longitude,
      battery: battery,
      message: "SOS from $userId - Please help ASAP!",
    );
  }
}
