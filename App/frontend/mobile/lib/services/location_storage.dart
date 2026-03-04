// App/frontend/mobile/lib/services/location_storage.dart
import 'package:shared_preferences/shared_preferences.dart';

class LocationStorage {
  static const _kLat = "last_lat";
  static const _kLng = "last_lng";

  static Future<void> saveLastLocation(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLat, lat);
    await prefs.setDouble(_kLng, lng);
  }

  static Future<Map<String, double>?> getLastLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLat);
    final lng = prefs.getDouble(_kLng);

    if (lat == null || lng == null) return null;
    return {"lat": lat, "lng": lng};
  }
}
