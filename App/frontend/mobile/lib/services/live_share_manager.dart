// App/frontend/mobile/lib/services/live_share_manager.dart
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';

import 'package:mobile/services/group_api.dart';

class LiveShareManager {
  final GroupApi api;
  final Battery _battery = Battery();

  Timer? _timer;

  LiveShareManager({required this.api});

  void start({
    required String groupId, // ✅ "bubble"
    required String userId,
    required bool Function() isIncognito, // getter from UI state
  }) {
    stop();

    _timer = Timer.periodic(const Duration(seconds: 7), (_) async {
      try {
        final incognito = isIncognito();
        if (incognito) {
          // still calling api is optional
          return;
        }

        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final battery = await _battery.batteryLevel;

        await api.share(
          groupId: groupId,
          userId: userId,
          lat: pos.latitude,
          lng: pos.longitude,
          battery: battery,
          incognito: false,
        );
      } catch (_) {
      }
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
