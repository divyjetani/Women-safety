// lib/screens/map_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/group_storage.dart';
import 'package:mobile/widgets/bubble_info_sheet.dart';
import 'package:mobile/widgets/create_bubble_dialog.dart';
import 'package:mobile/widgets/map_search_bar.dart';
import 'package:share_plus/share_plus.dart';

import '../models/bubble_model.dart';
import '../services/location_storage.dart';
import '../services/share_service.dart';
import '../widgets/map_group_strip_left.dart';
import '../widgets/map_incognito_strip_right.dart';
import '../widgets/group_bubble_bar.dart';


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

  LatLng? _myLocation;
  double _zoom = 15;
  bool _loadingLocation = true;

  // map modes
  MapType _mapType = MapType.normal;

  // incognito
  bool _incognito = false;

  // groups
  late List<SafetyGroup> _groups;
  late SafetyGroup _currentGroup;

  // share service
  final ShareService _shareService = ShareService();

  // for sharing periodically
  Timer? _shareTimer;

  // default fallback if no last location
  final LatLng _defaultCenter = const LatLng(23.0293515, 72.5530625); // Delhi

  @override
  void initState() {
    super.initState();

    _groups = [
      SafetyGroup(
        id: "1",
        name: "Family",
        members: [
          GroupMember(
            id: "u1",
            name: "Divy",
            lat: 23.6145,
            lng: 72.2098,
          ),
          GroupMember(
            id: "u2",
            name: "Mom",
            lat: 23.6129,
            lng: 72.2080,
          ),
        ],
      ),
    ];
    _currentGroup = _groups.first;

    _initOnOpen();
  }

  @override
  void dispose() {
    _shareTimer?.cancel();
    super.dispose();
  }

  Future<void> _initOnOpen() async {
    final storedGroups = await GroupStorage.loadGroups();

    if (storedGroups.isNotEmpty) {
      final selectedId = await GroupStorage.loadSelectedGroup();

      setState(() {
        _groups = storedGroups;
        _currentGroup = selectedId != null
            ? storedGroups.firstWhere(
              (g) => g.id == selectedId,
          orElse: () => storedGroups.first,
        )
            : storedGroups.first;
      });
    }

    // ✅ move map to last location immediately
    final last = await LocationStorage.getLastLocation();
    if (last != null) {
      setState(() => _myLocation = LatLng(last["lat"]!, last["lng"]!));
    }

    // ✅ now try real location
    await _goToMyLocation(showSnackOnFail: false);

    setState(() => _loadingLocation = false);

    // ✅ start sharing loop (every 7 sec)
    _startSharingLoop();
    await _updateMarkers();
  }

  void _startSharingLoop() {
    _shareTimer?.cancel();
    _shareTimer = Timer.periodic(const Duration(seconds: 7), (_) async {
      final loc = _myLocation;
      if (loc == null) return;

      await _shareService.shareToGroup(
        incognito: _incognito,
        groupId: _currentGroup.id,
        lat: loc.latitude,
        lng: loc.longitude,
      );
    });
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

    // 🔵 My location
    if (_myLocation != null) {
      final myIcon = await _letterMarker(
        "D", // first letter of logged-in user
        Colors.blue,
      );

      newMarkers.add(
        Marker(
          markerId: const MarkerId("me"),
          position: _myLocation!,
          icon: myIcon,
        ),
      );
    }

    // 🟢 Bubble members
    for (final m in _currentGroup.members) {
      final icon = await _letterMarker(
        m.name[0].toUpperCase(),
        Colors.green,
      );

      newMarkers.add(
        Marker(
          markerId: MarkerId(m.id),
          position: LatLng(m.lat, m.lng),
          icon: icon,
        ),
      );
    }

    setState(() {
      _markers = newMarkers;
    });
  }


  /// ✅ North direction button (bearing reset)
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showInviteDialog(String link) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Bubble Created 🎉"),
        content: SelectableText(link),
        actions: [
          TextButton(
            onPressed: () {
              Share.share(link); // use share_plus
            },
            child: const Text("Share"),
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

            // ✅ Google Map
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: initialTarget,
                zoom: _zoom,
              ),
              mapType: _mapType,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              compassEnabled: false, // we are making our own "north" btn
              zoomControlsEnabled: false,
              onMapCreated: (c) {
                _controller = c;
                },
              markers: _markers,
            ),

            ShaderMask(
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
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Positioned(
                    top: 8,
                    left: 0,
                    right: 0,
                    child: GroupBubbleBar(
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

                              // save + update UI
                              setState(() {
                                _groups.insert(0, res.group);
                                _currentGroup = res.group;
                              });

                              _showInviteDialog(res.inviteLink);
                            },
                          ),
                        );
                      },

                      onSelect: (g) async {
                        setState(() => _currentGroup = g);

                        // 🔐 persist selected group
                        await GroupStorage.saveSelectedGroup(g.id);

                        await _updateMarkers();
                        // _showSnack("Active group: ${g.name}");
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ✅ Left group strip
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


            // ✅ Right incognito strip
            MapIncognitoStripRight(
              incognito: _incognito,
              onChanged: (v) {
                setState(() => _incognito = v);
              },
            ),

            // ✅ Map floating controls (bottom-right)
            Positioned(
              right: 14,
              bottom: 22,
              child: Column(
                children: [
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

            // small loading top indicator
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
                  showModalBottomSheet(
                    context: context,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => BubbleInfoSheet(group: _currentGroup),
                  );
                },
              )
            ),

          ],
        ),
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
}
