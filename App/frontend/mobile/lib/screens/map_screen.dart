// App/frontend/mobile/lib/screens/map_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/group_storage.dart';
import 'package:mobile/services/bubble_websocket_service.dart';
import 'package:mobile/services/background_location_service.dart';
import 'package:mobile/widgets/bubble_info_sheet.dart';
import 'package:mobile/widgets/create_bubble_dialog.dart';
import 'package:mobile/widgets/join_bubble_dialog.dart';
import 'package:mobile/widgets/map_search_bar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/bubble_model.dart';
import '../services/location_storage.dart';
import '../widgets/map_group_strip_left.dart';
import '../widgets/map_incognito_strip_right.dart';
import '../widgets/group_bubble_bar.dart';
import '../widgets/app_snackbar.dart';


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class LocationFetchingCard extends StatelessWidget {
  const LocationFetchingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            color: Colors.black.withOpacity(0.15),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text("Fetching location..."),
        ],
      ),
    );
  }
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _controller;
  Set<Marker> _markers = {};

  LatLng? _tempPinLocation;
  Marker? _scoreMarker;
  bool _isSelectingLocation = false;

  LatLng? _myLocation;
  double _zoom = 15;
  bool _loadingLocation = true;
  Map<String, dynamic>? _nearestPoliceStation;
  bool _loadingNearestPolice = false;

  MapType _mapType = MapType.normal;

  bool _incognito = false;

  late List<SafetyGroup> _groups;
  SafetyGroup? _currentGroup;

  // websocket for location sharing
  BubbleWebSocketService? _wsService;
  final Battery _battery = Battery();

  // for periodic location updates via websocket
  Timer? _locationTimer;
  bool _locationServiceWarningShown = false;
  bool _locationPermissionWarningShown = false;

  // default fallback if no last location
  final LatLng _defaultCenter = const LatLng(23.0293515, 72.5530625); // Delhi

  Future<BitmapDescriptor> _buildScoreMarkerIcon(String text) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()..color = Colors.red;
    canvas.drawCircle(const Offset(50, 50), 50, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(50 - textPainter.width / 2, 50 - textPainter.height / 2),
    );

    final img = await recorder.endRecording().toImage(100, 100);
    final bytes = await img.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  @override
  void initState() {
    super.initState();

    // static bubble commented out - use dynamic bubbles from backend
    // _currentgroup = _groups.first;
    
    _groups = [];

    _initOnOpen();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _wsService?.disconnect();
    super.dispose();
  }

  Future<void> _initOnOpen() async {
    final prefs = await SharedPreferences.getInstance();
    final savedIncognito = prefs.getBool('incognito_mode') ?? false;
    setState(() => _incognito = savedIncognito);

    try {
      final backendGroups = await ApiService.getUserBubbles();
      final selectedId = await GroupStorage.loadSelectedGroup();

      setState(() {
        _groups = backendGroups;
        if (backendGroups.isNotEmpty) {
          _currentGroup = selectedId != null
              ? backendGroups.firstWhere(
                  (g) => g.id == selectedId,
                  orElse: () => backendGroups.first,
                )
              : backendGroups.first;
        }
      });

      await GroupStorage.saveGroups(backendGroups);
      if (_currentGroup != null) {
        await GroupStorage.saveSelectedGroup(_currentGroup!.id);
      }
    } catch (e) {
      // fallback to stored groups if backend fails
      final storedGroups = await GroupStorage.loadGroups();
      final selectedId = await GroupStorage.loadSelectedGroup();

      setState(() {
        _groups = storedGroups;
        if (storedGroups.isNotEmpty) {
          _currentGroup = selectedId != null
              ? storedGroups.firstWhere(
                  (g) => g.id == selectedId,
                  orElse: () => storedGroups.first,
                )
              : storedGroups.first;
        }
      });
    }

    // ✅ move map to last location immediately
    final last = await LocationStorage.getLastLocation();
    if (last != null) {
      setState(() => _myLocation = LatLng(last["lat"]!, last["lng"]!));
    }

    await _goToMyLocation(showSnackOnFail: false);
    await _loadNearestPoliceStation();

    setState(() => _loadingLocation = false);

    // ✅ start websocket location sharing
    _startLocationSharing();
    await _updateMarkers();
  }

  // / ✅ start both websocket and background location sharing
  void _startLocationSharing() async {
    _startWebSocketSharing();
    
    // also start background location sharing
    final group = _currentGroup;
    if (group == null || group.code == null) return;

    try {
      final user = await ApiService.getCurrentUser();
      if (user == null) return;

      await BackgroundLocationService.startBackgroundLocationSharing(
        bubbleCode: group.code!,
        userId: user.id,
        incognito: _incognito,
      );

      print('✅ Background location sharing started for bubble: ${group.name}');
    } catch (e) {
      print('❌ Error starting background location sharing: $e');
    }
  }

  Future<void> _loadNearestPoliceStation() async {
    final loc = _myLocation;
    if (loc == null) return;

    if (mounted) {
      setState(() => _loadingNearestPolice = true);
    }

    try {
      final station = await ApiService.getNearestPoliceStation(
        lat: loc.latitude,
        lng: loc.longitude,
      );

      if (!mounted) return;
      setState(() {
        _nearestPoliceStation = station;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearestPoliceStation = null;
      });
    } finally {
      if (mounted) {
        setState(() => _loadingNearestPolice = false);
      }
    }
  }

  Future<void> _openDirectionsToNearestPolice() async {
    final station = _nearestPoliceStation;
    if (station == null) return;

    final destinationLat = station['lat'];
    final destinationLng = station['lng'];
    if (destinationLat == null || destinationLng == null) return;

    final origin = _myLocation;
    final Uri url;
    if (origin != null) {
      url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&origin=${origin.latitude},${origin.longitude}&destination=$destinationLat,$destinationLng&travelmode=driving',
      );
    } else {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$destinationLat,$destinationLng',
      );
    }

    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      _showSnack('Could not open Google Maps directions');
    }
  }

  void _startWebSocketSharing() async {
    _locationTimer?.cancel();
    _wsService?.disconnect();

    final group = _currentGroup;
    if (group == null || group.code == null) return;

    try {
      final user = await ApiService.getCurrentUser();
      if (user == null) return;

      _wsService = BubbleWebSocketService(
        bubbleCode: group.code!,
        userId: user.id,
      );

      _wsService!.onLocationUpdate = (members) {
        if (!mounted) return;
        
        setState(() {
          // update current group members with new locations
          if (_currentGroup != null) {
            final updatedMembers = members.map((m) {
              return GroupMember(
                id: m.userId.toString(),
                name: m.name,
                lat: m.lat ?? 0.0,
                lng: m.lng ?? 0.0,
                battery: m.battery,
              );
            }).toList();
            
            _currentGroup = SafetyGroup(
              id: _currentGroup!.id,
              name: _currentGroup!.name,
              members: updatedMembers,
              icon: _currentGroup!.icon,
              color: _currentGroup!.color,
              code: _currentGroup!.code,
            );
          }
        });
        _updateMarkers();
      };

      _wsService!.onError = (error) {
        print('WebSocket error: $error');
      };

      _wsService!.onConnectionChanged = (connected) {
        print('WebSocket connection: $connected');
      };

      await _wsService!.connect();

      // start periodic location updates via websocket
      _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        try {
          final serviceEnabled = await Geolocator.isLocationServiceEnabled();
          if (!serviceEnabled) {
            if (!_locationServiceWarningShown && mounted) {
              _locationServiceWarningShown = true;
              _showSnack("Location service is off. Enable it to update live location.");
            }
            return;
          }

          var permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied ||
              permission == LocationPermission.deniedForever) {
            if (!_locationPermissionWarningShown && mounted) {
              _locationPermissionWarningShown = true;
              _showSnack("Location permission denied. Please enable from app settings.");
            }
            return;
          }

          _locationServiceWarningShown = false;
          _locationPermissionWarningShown = false;

          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          final live = LatLng(pos.latitude, pos.longitude);
          _myLocation = live;
          await LocationStorage.saveLastLocation(live.latitude, live.longitude);
          if (mounted) {
            await _updateMarkers();
          }
        } catch (_) {
          // keep last known location if fresh read fails
        }

        if (_incognito) return;

        final loc = _myLocation;
        if (loc == null || _wsService == null || !_wsService!.isConnected) return;

        final battery = await _battery.batteryLevel;
        _wsService!.shareLocation(
          lat: loc.latitude,
          lng: loc.longitude,
          battery: battery,
        );
      });
    } catch (e) {
      print('Error starting WebSocket: $e');
    }
  }

  Future<void> _refreshGroupsAfterMutation({String? preferredGroupId}) async {
    final backendGroups = await ApiService.getUserBubbles();
    setState(() {
      _groups = backendGroups;
      if (backendGroups.isEmpty) {
        _currentGroup = null;
      } else if (preferredGroupId != null) {
        _currentGroup = backendGroups.firstWhere(
          (g) => g.id == preferredGroupId,
          orElse: () => backendGroups.first,
        );
      } else {
        _currentGroup = backendGroups.first;
      }
    });

    await GroupStorage.saveGroups(backendGroups);
    if (_currentGroup != null) {
      await GroupStorage.saveSelectedGroup(_currentGroup!.id);
      _startLocationSharing();
    } else {
      _locationTimer?.cancel();
      _wsService?.disconnect();
      await BackgroundLocationService.stopBackgroundLocationSharing();
    }
    await _updateMarkers();
  }

  Future<void> _refreshCurrentGroupBeforeSheet() async {
    final currentGroup = _currentGroup;
    if (currentGroup == null) return;

    try {
      final backendGroups = await ApiService.getUserBubbles();
      final matched = backendGroups.where((g) => g.id == currentGroup.id).toList();
      if (matched.isEmpty) return;

      if (!mounted) return;
      setState(() {
        _groups = backendGroups;
        _currentGroup = matched.first;
      });

      await GroupStorage.saveGroups(backendGroups);
      await GroupStorage.saveSelectedGroup(matched.first.id);
      await _updateMarkers();
    } catch (_) {
    }
  }

  Future<void> _deleteCurrentBubble() async {
    final group = _currentGroup;
    if (group == null || group.code == null) return;

    final user = await ApiService.getCurrentUser();
    if (user == null) return;

    await ApiService.deleteBubble(code: group.code!, adminId: user.id);
    await _refreshGroupsAfterMutation();
  }

  Future<void> _leaveCurrentBubble() async {
    final group = _currentGroup;
    if (group == null || group.code == null) return;

    final user = await ApiService.getCurrentUser();
    if (user == null) return;

    await ApiService.leaveBubble(code: group.code!, userId: user.id);
    await _refreshGroupsAfterMutation();
  }

  Future<void> _kickMemberFromCurrentBubble(GroupMember member) async {
    final group = _currentGroup;
    if (group == null || group.code == null) return;

    final user = await ApiService.getCurrentUser();
    final memberId = int.tryParse(member.id);
    if (user == null || memberId == null) return;

    await ApiService.kickBubbleMember(
      code: group.code!,
      adminId: user.id,
      memberUserId: memberId,
    );
    await _refreshGroupsAfterMutation(preferredGroupId: group.id);
  }

  Future<void> _goToMyLocation({bool showSnackOnFail = true}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (showSnackOnFail) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text("Location Required"),
              content: Text("Please enable location services to continue."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Geolocator.openLocationSettings();
                  },
                  child: Text("Enable"),
                ),
              ],
            ),
          );
        }
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

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final live = LatLng(pos.latitude, pos.longitude);

      setState(() {
        _myLocation = live;
        _zoom = 16;
      });
      await _updateMarkers();
      await _loadNearestPoliceStation();

      await LocationStorage.saveLastLocation(live.latitude, live.longitude);

      _controller?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: live, zoom: _zoom),
        ),
      );
    } catch (e) {
      if (showSnackOnFail) _showSnack("Error getting location: $e");
    }
  }

  Future<void> _updateMarkers() async {
    final Set<Marker> newMarkers = {};
    
    final user = await ApiService.getCurrentUser();

    if (_myLocation != null && user != null) {
      final myIcon = await _myPointerMarker(
        user.username[0].toUpperCase(),
        Theme.of(context).primaryColor,
      );

      newMarkers.add(
        Marker(
          markerId: const MarkerId("me"),
          position: _myLocation!,
          icon: myIcon,
          anchor: const Offset(0.5, 1.0),
          infoWindow: const InfoWindow(title: "📍 Me"),
        ),
      );
    }

    if (_currentGroup != null && user != null) {
      // use bubble's color if available, otherwise use green
      Color memberColor = _currentGroup!.color != null 
          ? Color(_currentGroup!.color!) 
          : Colors.green;
      
      // filter out current user and members without location
      final otherMembers = _currentGroup!.members.where((m) {
        return m.id != user.id.toString() && m.lat != 0.0 && m.lng != 0.0;
      });
          
      for (final m in otherMembers) {
        // use different color for incognito members
        final displayColor = m.incognito ? Colors.grey : memberColor;
        final icon = await _letterMarker(
          m.name[0].toUpperCase(),
          displayColor,
        );
        
        // add incognito indicator to info window
        final titleWithStatus = m.incognito 
            ? "${m.name} (🔍 Incognito)" 
            : m.name;

        newMarkers.add(
          Marker(
            markerId: MarkerId(m.id),
            position: LatLng(m.lat, m.lng),
            icon: icon,
            infoWindow: InfoWindow(title: titleWithStatus),
            onTap: () {
              _controller?.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: LatLng(m.lat, m.lng),
                    zoom: 16,
                  ),
                ),
              );
              // also show info in bottom sheet
              showModalBottomSheet(
                context: context,
                builder: (_) => Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            child: Text(m.name[0].toUpperCase()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (m.incognito)
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.visibility_off,
                                        size: 14,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text("Incognito Mode"),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "${m.lat.toStringAsFixed(4)}, ${m.lng.toStringAsFixed(4)}",
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.battery_full,
                            color: m.battery > 20 ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 8),
                          Text("Battery: ${m.battery}%"),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    if (_tempPinLocation != null) {
      newMarkers.add(
        Marker(
          markerId: const MarkerId("temp_pin"),
          position: _tempPinLocation!,
        ),
      );
    }

    if (_scoreMarker != null) {
      newMarkers.add(_scoreMarker!);
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  // / ✅ north direction button (bearing reset)
  void _resetToNorth() {
    final target = _myLocation ?? _defaultCenter;
    _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: _zoom,
          bearing: 0,
          tilt: 0,
        ),
      ),
    );
  }

  void _toggleSatellite() {
    setState(() {
      _mapType = _mapType == MapType.normal ? MapType.satellite : MapType.normal;
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppSnackBar.show(context, msg);
  }

  void _showCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Bubble Created 🎉"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Share this code with others to join:"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                code,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Share.share("Join my safety bubble with code: $code");
            },
            child: const Text("Share Code"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Done"),
          ),
        ],
      ),
    );
  }

  Future<BitmapDescriptor> _letterMarker(
      String letter, Color color) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()..color = color;
    canvas.drawCircle(const Offset(40, 40), 40, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(40 - textPainter.width / 2, 40 - textPainter.height / 2),
    );

    final img = await recorder.endRecording().toImage(80, 80);
    final bytes = await img.toByteData(format: ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _myPointerMarker(String letter, Color color) async {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    final fillPaint = Paint()..color = color;
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;

    final center = const Offset(48, 40);
    const radius = 28.0;

    canvas.drawCircle(center, radius, fillPaint);
    canvas.drawCircle(center, radius, strokePaint);

    final tail = Path()
      ..moveTo(center.dx - 14, center.dy + 18)
      ..lineTo(center.dx + 14, center.dy + 18)
      ..lineTo(center.dx, 104)
      ..close();
    canvas.drawPath(tail, fillPaint);
    canvas.drawPath(tail, strokePaint);

    canvas.drawCircle(center, 12, Paint()..color = Colors.white.withOpacity(0.25));

    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );

    final img = await recorder.endRecording().toImage(96, 112);
    final bytes = await img.toByteData(format: ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(bytes!.buffer.asUint8List());
  }

  Future<void> _confirmLocationSelection() async {
    if (_tempPinLocation == null) return;

    try {
      final result = await ApiService.fetchSafetyScore(
        lat: _tempPinLocation!.latitude,
        lng: _tempPinLocation!.longitude,
      );

      final score = result["risk_score"];

      final markerIcon = await _buildScoreMarkerIcon(
      score != null ? score.toString() : "--",
      );

      setState(() {
        _scoreMarker = Marker(
          markerId: const MarkerId("score_pin"),
          position: _tempPinLocation!,
          icon: markerIcon,
        );

        _tempPinLocation = null;
        _isSelectingLocation = false;
      });

      await _updateMarkers();
    } catch (e) {
      _showSnack("Failed to fetch safety score");
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final initialTarget = _myLocation ?? _defaultCenter;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            MapSearchBar(
              onPlaceSelected: (latLng) {
                _controller?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: latLng, zoom: 16),
                  ),
                );
              },
            ),

            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: _zoom,
              ),
              mapType: _mapType,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false, // we are making our own "north" btn
              zoomControlsEnabled: false,
              onMapCreated: (c) {
                _controller = c;
                },
              markers: _markers,
              onTap: (latLng) {
                if (!_isSelectingLocation) return;

                setState(() {
                  _tempPinLocation = latLng;

                  _markers.removeWhere(
                        (m) => m.markerId.value == "temp_pin",
                  );

                  _markers.add(
                    Marker(
                      markerId: const MarkerId("temp_pin"),
                      position: latLng,
                    ),
                  );
                });
              },
            ),

            if (_isSelectingLocation)
              Positioned(
                top: 100,
                left: 20,
                right: 20,
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.location_on, color: Colors.red, size: 28),
                        SizedBox(height: 8),
                        Text(
                          "Tap anywhere on the map to drop a pin.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          "Drop pin on map to check safety score",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            if (_isSelectingLocation && _tempPinLocation != null)
              Positioned(
                bottom: 120,
                left: 30,
                right: 30,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey,
                        ),
                        onPressed: () {
                          setState(() {
                            _isSelectingLocation = false;
                            _tempPinLocation = null;
                            _markers.removeWhere(
                                  (m) => m.markerId.value == "temp_pin",
                            );
                          });
                        },
                        child: const Text("Cancel"),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _confirmLocationSelection,
                        child: const Text("Safety Score"),
                      ),
                    ),
                  ],
                ),
              ),

            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 140,
                child: ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.7, 1.0],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Container(
                    color: Theme.of(context).cardColor,
                  ),
                ),
              ),
            ),


            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Column(
                children: [
                  GroupBubbleBar(
                    groups: _groups,
                    currentGroup: _currentGroup,
                    onCreate: () {
                      showDialog(
                        context: context,
                        builder: (_) => CreateBubbleDialog(
                          onCreate: (name, icon, color) async {
                            final res = await ApiService.createBubble(
                              name: name,
                              icon: icon.codePoint,
                              color: color.value,
                            );

                            setState(() {
                              _groups.insert(0, res.group);
                              _currentGroup = res.group;
                            });

                            await GroupStorage.saveGroups(_groups);
                            await GroupStorage.saveSelectedGroup(res.group.id);
                            _startWebSocketSharing();
                            await _updateMarkers();

                            _showCodeDialog(res.code);
                          },
                        ),
                      );
                    },
                    onJoin: () {
                      showDialog(
                        context: context,
                        builder: (_) => JoinBubbleDialog(
                          onJoin: (code) async {
                            try {
                              final group = await ApiService.joinBubbleByCode(code);

                              setState(() {
                                final existingIndex = _groups.indexWhere((g) => g.id == group.id);
                                if (existingIndex >= 0) {
                                  _groups[existingIndex] = group;
                                } else {
                                  _groups.insert(0, group);
                                }
                                _currentGroup = group;
                              });

                              await GroupStorage.saveGroups(_groups);
                              await GroupStorage.saveSelectedGroup(group.id);
                              _startWebSocketSharing();
                              await _updateMarkers();

                              _showSnack('Joined bubble: ${group.name}');
                            } catch (e) {
                              _showSnack('Failed to join: $e');
                            }
                          },
                        ),
                      );
                    },
                    onSelect: (g) async {
                      setState(() => _currentGroup = g);
                      await GroupStorage.saveSelectedGroup(g.id);
                      _startWebSocketSharing();
                      await _updateMarkers();
                    },
                  ),
                ],
              ),
            ),

            MapGroupMembersStripLeft(
              group: _currentGroup,
              onMemberTap: (member) {
                final target = LatLng(member.lat, member.lng);

                _controller?.animateCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: target,
                      zoom: 17,
                    ),
                  ),
                );

                _showSnack("${member.name}'s location");
              },
            ),


            MapIncognitoStripRight(
              incognito: _incognito,
              onChanged: (v) {
                setState(() => _incognito = v);
                
                // update background location service about incognito mode change
                BackgroundLocationService.setIncognitoMode(v);
              },
            ),

            // ✅ help icon button (top-right)
            Positioned(
              top: 60,
              right: 10,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).cardColor.withOpacity(0.95),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      color: Colors.black.withOpacity(0.2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('💡 How Bubbles Work'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _helpSection('Create', 'Tap "Create" to make a new safety bubble with friends or family.'),
                                _helpSection('Join', 'Ask others for their 6-digit code and tap "Join" to enter an existing bubble.'),
                                _helpSection('Share', 'Your location updates every 5 seconds to all bubble members (unless in Incognito mode).'),
                                _helpSection('Color', 'Each bubble has its own color for easy identification on the map.'),
                                _helpSection('Incognito', 'Turn ON to hide your location from the bubble while viewing others.'),
                                _helpSection('Click', 'Tap any member\'s marker to see their location details and battery status.'),
                                _helpSection('Battery', 'Red = Low battery (<20%), Green = Good battery (>20%).'),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Got it!'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Icon(
                        Icons.help_outline,
                        size: 22,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ✅ map floating controls (bottom-right)
            Positioned(
              right: 14,
              bottom: 22,
              child: Column(
                children: [
                  _circleBtn(
                    icon: Icons.location_pin,
                    tooltip: "Check Safety",
                    onTap: () {
                      setState(() {
                        _isSelectingLocation = true;
                        _tempPinLocation = null;

                        if (_scoreMarker != null) {
                          _markers.remove(_scoreMarker);
                          _scoreMarker = null;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  _circleBtn(
                    icon: Icons.public, // satellite btn
                    onTap: _toggleSatellite,
                    tooltip: _mapType == MapType.satellite
                        ? "Normal Map"
                        : "Satellite Map",
                  ),
                  const SizedBox(height: 12),
                  _circleBtn(
                    icon: Icons.navigation, // north
                    onTap: _resetToNorth,
                    tooltip: "North",
                  ),
                  const SizedBox(height: 12),
                  _circleBtn(
                    icon: Icons.my_location,
                    onTap: _goToMyLocation,
                    tooltip: "My Location",
                  ),
                ],
              ),
            ),

            if (_loadingLocation)
              Positioned(
                top: 90,
                left: 14,
                right: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.cardColor.withValues( alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 16,
                        color: Colors.black.withValues( alpha: 0.15),
                      ),
                    ],
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text("Fetching location..."),
                    ],
                  ),
                ),
              ),
            Positioned(
              left: 75,
              right: 65,
              bottom: 10,
              child: Column(
                children: [
                  if (_loadingNearestPolice)
                    _nearestPoliceBanner('Finding nearest police station...', '', loading: true),
                  if (!_loadingNearestPolice && _nearestPoliceStation != null)
                    _nearestPoliceBanner(
                      _nearestPoliceStation!['name']?.toString() ?? 'Nearest Police Station',
                      'Distance: ${_nearestPoliceStation!['distance_km'] ?? '--'} km • ${_nearestPoliceStation!['address'] ?? ''}',
                    ),
                ],
              ),
            ),

            Positioned(
              left: 14,
              bottom: 22,
              child: FloatingActionButton(
                heroTag: "bubbleInfo",
                elevation: 6,
                backgroundColor: Theme.of(context).cardColor,
                shape: const CircleBorder(),
                child: Icon(
                  Icons.groups,
                  color: Theme.of(context).colorScheme.primary,
                ),
                onPressed: () {
                  _refreshCurrentGroupBeforeSheet().whenComplete(() {
                    if (!mounted) return;
                    showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => BubbleInfoSheet(
                      group: _currentGroup,
                      onNavigateToMember: (location) {
                        _controller?.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(target: location, zoom: _zoom),
                          ),
                        );
                      },
                      onDeleteBubble: _deleteCurrentBubble,
                      onLeaveBubble: _leaveCurrentBubble,
                      onKickMember: _kickMemberFromCurrentBubble,
                    ),
                    );
                  });
                },
              )
            ),

          ],
        ),
      ),
    );
  }

  Widget _helpSection(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final theme = Theme.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: 7,
        shape: const CircleBorder(),
        color: theme.cardColor.withValues( alpha: 0.95),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              size: 22,
              color: theme.primaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _nearestPoliceBanner(String title, String subtitle, {bool loading = false}) {
    return Material(
      elevation: 5,
      borderRadius: BorderRadius.circular(14),
      color: Theme.of(context).cardColor.withValues(alpha: 0.96),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.local_police, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (!loading)
              IconButton(
                  onPressed: _openDirectionsToNearestPolice,
                  icon: const Icon(Icons.directions, size: 18),
                color: Theme.of(context).primaryColor,
              ),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
      ),
    );
  }
}
