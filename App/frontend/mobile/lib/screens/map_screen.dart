import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../app/theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _mapController = MapController();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  bool _isFullScreen = false;
  bool _loadingLocation = true;

  LatLng? _myLocation;
  double _currentZoom = 13;

  String _currentAreaName = "Fetching area...";

  List<Map<String, dynamic>> _suggestions = [];

  // Dummy heatmap points
  final List<WeightedLatLng> heatPoints = [
    // 🔴 Risk
    WeightedLatLng(const LatLng(23.0145, 72.3307), 6),
    WeightedLatLng(const LatLng(23.6132, 72.2300), 5),
    WeightedLatLng(const LatLng(23.6125, 72.2288), 6),

    // 🟠 Alert
    WeightedLatLng(const LatLng(23.6152, 72.2182), 3),
    WeightedLatLng(const LatLng(23.6158, 72.2190), 4),
    WeightedLatLng(const LatLng(23.6148, 72.2176), 3),

    // 🟢 Safe
    WeightedLatLng(const LatLng(23.6102, 72.2150), 1),
    WeightedLatLng(const LatLng(23.6098, 72.2140), 1),
  ];

  final LatLng _defaultCenter = const LatLng(28.6139, 77.2090); // fallback

  @override
  void initState() {
    super.initState();

    // ✅ Auto-fetch on opening page
    _initLocationOnOpen();

    // ✅ Search suggestions when typing
    _searchController.addListener(() {
      final q = _searchController.text.trim();
      if (q.length < 3) {
        setState(() => _suggestions = []);
        return;
      }
      _fetchSuggestions(q);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ✅ Auto init
  Future<void> _initLocationOnOpen() async {
    await _goToMyLocation(showSnackOnFail: false);
    setState(() => _loadingLocation = false);
  }

  // ✅ My Location button + auto fetch
  Future<void> _goToMyLocation({bool showSnackOnFail = true}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showSnackOnFail) _showSnack("Turn ON Location Service");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (showSnackOnFail) _showSnack("Location permission denied");
        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (showSnackOnFail) {
          _showSnack("Permission denied forever. Enable from Settings.");
        }
        await Geolocator.openAppSettings();
        return;
      }

      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final LatLng live = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _myLocation = live;
        _currentZoom = 16;
      });

      _mapController.move(live, _currentZoom);

      // ✅ Reverse geocode to area name
      final area = await _reverseGeocode(live.latitude, live.longitude);
      if (area != null) {
        setState(() => _currentAreaName = area);
      } else {
        setState(() => _currentAreaName = "Unknown area");
      }
    } catch (e) {
      if (showSnackOnFail) _showSnack("Error getting location: $e");
    }
  }

  // ✅ Reverse geocoding using Nominatim
  Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final url =
          "https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon";

      final res = await http.get(
        Uri.parse(url),
        headers: {
          // ✅ Required by Nominatim policy
          "User-Agent": "safety-app/1.0 (contact: your@email.com)"
        },
      );

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      final address = data["address"];

      // take best readable name
      final String area =
          address["suburb"] ??
              address["neighbourhood"] ??
              address["city"] ??
              address["town"] ??
              address["village"] ??
              data["display_name"];

      return area.toString();
    } catch (_) {
      return null;
    }
  }

  // ✅ Suggestions (Search)
  Future<void> _fetchSuggestions(String query) async {
    try {
      final url =
          "https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(query)}&addressdetails=1&limit=6";

      final res = await http.get(
        Uri.parse(url),
        headers: {
          "User-Agent": "safety-app/1.0 (contact: your@email.com)",
        },
      );

      if (res.statusCode != 200) return;

      final List list = jsonDecode(res.body);

      setState(() {
        _suggestions = list.map((e) {
          return {
            "name": e["display_name"],
            "lat": double.parse(e["lat"]),
            "lon": double.parse(e["lon"]),
          };
        }).toList();
      });
    } catch (_) {
      // ignore
    }
  }

  void _onSuggestionTap(Map<String, dynamic> place) {
    final LatLng target = LatLng(place["lat"], place["lon"]);

    setState(() {
      _currentAreaName = place["name"];
      _suggestions = [];
    });

    _searchFocus.unfocus();
    _mapController.move(target, 15);
  }

  void _zoomIn() {
    setState(() => _currentZoom += 1);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    setState(() => _currentZoom -= 1);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _toggleFullScreen() {
    setState(() => _isFullScreen = !_isFullScreen);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            if (!_isFullScreen) ...[
              // ✅ Area Name header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _loadingLocation ? "Loading..." : "Current Area",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _currentAreaName,
                          style: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .color!
                                .withValues(alpha: 0.7),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: _goToMyLocation,
                        icon: Icon(
                          Icons.my_location,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ Search Bar + Suggestions dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocus,
                        decoration: InputDecoration(
                          hintText: 'Search area...',
                          hintStyle: TextStyle(
                            color: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .color!
                                .withValues(alpha: 0.5),
                          ),
                          border: InputBorder.none,
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).primaryColor,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _suggestions = []);
                            },
                            icon: Icon(
                              Icons.close,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // ✅ Suggestions
                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _suggestions.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, index) {
                            final place = _suggestions[index];
                            return ListTile(
                              leading: Icon(Icons.location_on,
                                  color: Theme.of(context).primaryColor),
                              title: Text(
                                place["name"],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _onSuggestionTap(place),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],

            // ✅ Map View
            Expanded(
              child: Container(
                margin: _isFullScreen ? EdgeInsets.zero : const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_isFullScreen ? 0 : 25),
                  color: Theme.of(context).cardColor,
                  boxShadow: _isFullScreen
                      ? []
                      : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _myLocation ?? _defaultCenter,
                        initialZoom: _currentZoom,
                      ),
                      children: [
                        // ✅ High contrast LIGHT tiles
                        TileLayer(
                          urlTemplate:
                          "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: "com.example.app",
                        ),

                        // ✅ Heatmap
                        HeatMapLayer(
                          heatMapDataSource: InMemoryHeatMapDataSource(data: heatPoints),
                          heatMapOptions: HeatMapOptions(
                            radius: 45,
                            blurFactor: 0.8,
                            minOpacity: 0.15,
                          ),
                        ),

                        // ✅ Markers
                        MarkerLayer(
                          markers: [
                            // ✅ SMALL PIN marker (no bg)
                            if (_myLocation != null)
                              Marker(
                                point: _myLocation!,
                                width: 28,
                                height: 28,
                                child: Icon(
                                  Icons.location_pin,
                                  color: Theme.of(context).primaryColor,
                                  size: 28,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),

                    // ✅ Buttons on right side
                    Positioned(
                      right: 14,
                      bottom: 20,
                      child: Column(
                        children: [
                          _fabButton(
                            icon: _isFullScreen
                                ? Icons.fullscreen_exit
                                : Icons.fullscreen,
                            onTap: _toggleFullScreen,
                            context: context,
                          ),
                          const SizedBox(height: 12),
                          _fabButton(
                            icon: Icons.add,
                            onTap: _zoomIn,
                            context: context,
                          ),
                          const SizedBox(height: 12),
                          _fabButton(
                            icon: Icons.remove,
                            onTap: _zoomOut,
                            context: context,
                          ),
                          const SizedBox(height: 12),
                          _fabButton(
                            icon: Icons.my_location,
                            onTap: _goToMyLocation,
                            context: context,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ✅ Simplified Threat legend
            if (!_isFullScreen) ...[
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _simpleThreatChip("Safe", AppTheme.successColor),
                    _simpleThreatChip("Alert", AppTheme.warningColor),
                    _simpleThreatChip("Risk", AppTheme.dangerColor),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ]
          ],
        ),
      ),
    );
  }

  Widget _fabButton({
    required IconData icon,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return Material(
      elevation: 6,
      shape: const CircleBorder(),
      color: Theme.of(context).cardColor,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            icon,
            color: Theme.of(context).primaryColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _simpleThreatChip(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "$label",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
