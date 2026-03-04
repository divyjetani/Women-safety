// App/frontend/mobile/lib/services/place_search_service.dart
class PlaceResult {
  final String name;
  final String address;
  final double lat;
  final double lng;

  PlaceResult(this.name, this.address, this.lat, this.lng);
}

class PlaceSearchService {
  static Future<List<PlaceResult>> searchNearby(String query) async {
    return [
      PlaceResult("Connaught Place", "New Delhi", 28.6315, 77.2167),
      PlaceResult("Karol Bagh", "New Delhi", 28.6519, 77.1909),
    ];
  }
}
