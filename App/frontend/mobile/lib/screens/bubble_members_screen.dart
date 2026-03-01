// lib/screens/bubble_members_screen.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mobile/models/bubble_model.dart';
import 'package:provider/provider.dart';
import 'package:mobile/services/bubble_api.dart';
import 'package:mobile/services/bubble_websocket_service.dart';
import 'package:mobile/app/auth_provider.dart';
import 'package:mobile/widgets/app_snackbar.dart';

class BubbleMembersScreen extends StatefulWidget {
  final Bubble initialBubble;

  const BubbleMembersScreen({
    Key? key,
    required this.initialBubble,
  }) : super(key: key);

  @override
  State<BubbleMembersScreen> createState() => _BubbleMembersScreenState();
}

class _BubbleMembersScreenState extends State<BubbleMembersScreen> {
  late BubbleWebSocketService _wsService;
  late MapController _mapController;

  Bubble? _bubble;
  List<BubbleMember> _members = [];
  Position? _currentPosition;
  int _batteryLevel = 100;
  bool _isSharing = true;
  bool _isLoading = true;
  String? _errorMessage;

  final Battery _battery = Battery();

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _bubble = widget.initialBubble;
    _members = widget.initialBubble.members;
    
    _initializeServices();
  }

  // ✅ INITIALIZE LOCATION, BATTERY, AND WEBSOCKET
  Future<void> _initializeServices() async {
    try {
      // Get initial battery level
      _batteryLevel = await _battery.batteryLevel;

      // Request location permission
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() => _errorMessage = 'Location permission required');
        return;
      }

      final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
      if (user == null) {
        setState(() => _errorMessage = 'Please login again to load bubble members');
        return;
      }

      // Connect to WebSocket
      _wsService = BubbleWebSocketService(
        bubbleCode: _bubble!.code,
        userId: user.id,
      );

      _wsService.onLocationUpdate = (members) {
        if (mounted) {
          setState(() => _members = members);
          _updateMapMarkers();
        }
      };

      _wsService.onBubbleInfo = (bubble) {
        if (mounted) {
          setState(() => _bubble = bubble);
        }
      };

      _wsService.onError = (error) {
        if (mounted) {
          AppSnackBar.show(context, 'Error: $error', type: AppSnackBarType.error);
        }
      };

      _wsService.onConnectionChanged = (connected) {
        if (mounted) {
          AppSnackBar.show(
            context,
            connected ? '🟢 Connected' : '🔴 Disconnected',
            type: connected ? AppSnackBarType.success : AppSnackBarType.error,
            duration: const Duration(seconds: 2),
          );
        }
      };

      await _wsService.connect();

      // Get initial location
      await _updateLocation();

      // Start periodic updates
      _startLocationUpdates();
      _startBatteryUpdates();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Initialization error: $e';
          _isLoading = false;
        });
      }
    }
  }

  // ✅ GET CURRENT LOCATION
  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );

      setState(() => _currentPosition = position);

      // Share location via WebSocket
      if (_isSharing && _wsService.isConnected) {
        _wsService.shareLocation(
          lat: position.latitude,
          lng: position.longitude,
          battery: _batteryLevel,
        );
      }

      // Animate map to current position
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        15,
      );
    } catch (e) {
      setState(() => _errorMessage = 'Location error: $e');
    }
  }

  // ✅ START PERIODIC LOCATION UPDATES
  void _startLocationUpdates() {
    Future.doWhile(() async {
      if (!mounted || !_isSharing) {
        await Future.delayed(const Duration(seconds: 5));
        return true;
      }

      await _updateLocation();
      await Future.delayed(const Duration(seconds: 10)); // Update every 10 seconds
      return true;
    });
  }

  // ✅ START BATTERY LEVEL MONITORING
  void _startBatteryUpdates() {
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      _getBatteryLevel();
    });

    // Update battery every 30 seconds
    Future.doWhile(() async {
      if (!mounted) return false;
      await Future.delayed(const Duration(seconds: 30));
      await _getBatteryLevel();
      return true;
    });
  }

  // ✅ GET BATTERY LEVEL
  Future<void> _getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      setState(() => _batteryLevel = level);

      // Share updated location with new battery level
      if (_isSharing && _currentPosition != null && _wsService.isConnected) {
        _wsService.shareLocation(
          lat: _currentPosition!.latitude,
          lng: _currentPosition!.longitude,
          battery: _batteryLevel,
        );
      }
    } catch (e) {
      // Battery level fetch failed
    }
  }

  // ✅ UPDATE MAP MARKERS
  void _updateMapMarkers() {
    if (!mounted) return;
    // Map will be rebuilt with new marker positions
  }

  // ✅ TOGGLE LOCATION SHARING
  Future<void> _toggleSharing() async {
    setState(() => _isSharing = !_isSharing);

    if (_isSharing) {
      await _updateLocation();
      AppSnackBar.show(context, '📍 Location sharing enabled', type: AppSnackBarType.success);
    } else {
      AppSnackBar.show(context, '🔇 Location sharing paused', type: AppSnackBarType.warning);
    }
  }

  @override
  void dispose() {
    _wsService.disconnect();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_bubble?.name ?? 'Bubble Members'),
        elevation: 0,
        backgroundColor: const Color(0xFF1A1F2E),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                '🔋 $_batteryLevel%',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ✅ ERROR MESSAGE
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade900,
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // ✅ MAP VIEW
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      _currentPosition?.latitude ?? 0,
                      _currentPosition?.longitude ?? 0,
                    ),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'shesafe.app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Current user marker
                        if (_currentPosition != null)
                          Marker(
                            width: 80,
                            height: 80,
                            point: LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'You',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Other members markers
                        ..._members
                            .where((m) => m.lat != null && m.lng != null)
                            .map((member) => Marker(
                                  width: 80,
                                  height: 80,
                                  point: LatLng(member.lat!, member.lng!),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _getBatteryColor(member.battery),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.location_on,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: _getBatteryColor(member.battery),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '${member.name} 🔋${member.battery}%',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ],
                    ),
                  ],
                ),

                // ✅ FLOATING ACTION BUTTONS
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: Column(
                    spacing: 12,
                    children: [
                      // Sharing toggle
                      FloatingActionButton(
                        backgroundColor: _isSharing
                            ? const Color(0xFF00E676)
                            : const Color(0xFF6B7280),
                        onPressed: _toggleSharing,
                        child: Icon(
                          _isSharing ? Icons.location_on : Icons.location_off,
                          color: Colors.white,
                        ),
                      ),

                      // Center on current location
                      FloatingActionButton(
                        backgroundColor: const Color(0xFFFF1744),
                        onPressed: () {
                          if (_currentPosition != null) {
                            _mapController.move(
                              LatLng(
                                _currentPosition!.latitude,
                                _currentPosition!.longitude,
                              ),
                              15,
                            );
                          }
                        },
                        child: const Icon(Icons.my_location, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ✅ MEMBERS LIST PANEL
          Container(
            color: const Color(0xFF1A1F2E),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Members (${_members.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF151B23),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Code: ${_bubble?.code}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF1744),
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF151B23),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: member.lat != null && member.lng != null
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Status indicator
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: member.lat != null && member.lng != null
                                        ? Colors.green
                                        : Colors.grey,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    member.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Battery level
                            Row(
                              children: [
                                Icon(
                                  _getBatteryIcon(member.battery),
                                  size: 16,
                                  color: _getBatteryColor(member.battery),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${member.battery}%',
                                  style: TextStyle(
                                    color: _getBatteryColor(member.battery),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ BATTERY COLOR
  Color _getBatteryColor(int battery) {
    if (battery >= 50) return Colors.green;
    if (battery >= 20) return Colors.orange;
    return Colors.red;
  }

  // ✅ BATTERY ICON
  IconData _getBatteryIcon(int battery) {
    if (battery >= 75) return Icons.battery_full;
    if (battery >= 50) return Icons.battery_6_bar;
    if (battery >= 25) return Icons.battery_3_bar;
    return Icons.battery_1_bar;
  }
}
