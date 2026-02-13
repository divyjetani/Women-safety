import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:proximity_sensor/proximity_sensor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../app/theme.dart';
import '../services/api_service.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  // ✅ Fake contacts (local)
  List<Map<String, dynamic>> fakeContacts = [];

  // ✅ Recordings list (local)
  List<Map<String, dynamic>> _fakeCallRecordings = [];

  @override
  void initState() {
    super.initState();
    _loadFakeContacts();
    _loadRecordings();
  }

  // =========================
  // CONTACTS
  // =========================
  Future<void> _loadFakeContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("fake_contacts");

    if (raw != null) {
      final List<dynamic> decoded = jsonDecode(raw);
      setState(() {
        fakeContacts = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } else {
      setState(() {
        fakeContacts = [
          {"name": "Mom", "number": "+91 90000 11111"},
          {"name": "Dad", "number": "+91 90000 22222"},
        ];
      });
      await _saveContacts();
    }
  }

  Future<void> _saveContacts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("fake_contacts", jsonEncode(fakeContacts));
  }

  Future<void> _addOrEditContact({Map<String, dynamic>? contact, int? index}) async {
    final nameCtrl = TextEditingController(text: contact?["name"] ?? "");
    final numCtrl = TextEditingController(text: contact?["number"] ?? "");

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                contact == null ? "Add Fake Contact" : "Edit Fake Contact",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: numCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone number",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || numCtrl.text.trim().isEmpty) {
                      Navigator.pop(ctx);
                      return;
                    }

                    final newItem = {"name": nameCtrl.text.trim(), "number": numCtrl.text.trim()};

                    setState(() {
                      if (index == null) {
                        fakeContacts.add(newItem);
                      } else {
                        fakeContacts[index] = newItem;
                      }
                    });

                    await _saveContacts();
                    if (!mounted) return;
                    Navigator.pop(ctx);
                  },
                  child: const Text("Save"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteContact(int index) async {
    setState(() => fakeContacts.removeAt(index));
    await _saveContacts();
  }

  // =========================
  // RECORDINGS LIST SAVE/LOAD
  // =========================
  Future<void> _loadRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("fakecall_recordings_list") ?? "[]";
    final decoded = jsonDecode(raw) as List<dynamic>;

    setState(() {
      _fakeCallRecordings = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    });
  }

  Future<void> _saveRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("fakecall_recordings_list", jsonEncode(_fakeCallRecordings));
  }

  // =========================
  // START FAKE CALL (Incoming)
  // =========================
  void _startFakeCall(Map<String, dynamic> contact) async {
    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => FakeIncomingCallScreen(
          name: contact["name"],
          number: contact["number"],
        ),
      ),
    );

    // ✅ If recording object returned, add it to list
    if (result != null) {
      setState(() => _fakeCallRecordings.insert(0, result));
      await _saveRecordings();

      // ✅ upload in background-like
      await _uploadFakeCallRecording(result);
    }
  }

  // =========================
  // UPLOAD + RETRY
  // =========================
  Future<void> _uploadFakeCallRecording(Map<String, dynamic> item) async {
    final idx = _fakeCallRecordings.indexWhere((r) => r["id"] == item["id"]);
    if (idx == -1) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("cached_user_id") ?? 1;

      setState(() {
        _fakeCallRecordings[idx]["uploadStatus"] = "pending";
        _fakeCallRecordings[idx]["lastError"] = "";
      });
      await _saveRecordings();

      await ApiService.uploadFakeCallRecording(
        userId: userId,
        backVideoPath: item["backVideoPath"],
        startImagePath: item["startImagePath"],
        endImagePath: item["endImagePath"],
        startedAt: item["startedAt"],
        endedAt: item["endedAt"],
        durationSeconds: item["duration"],
        startLat: item["startLat"],
        startLng: item["startLng"],
        endLat: item["endLat"],
        endLng: item["endLng"],
      );

      setState(() {
        _fakeCallRecordings[idx]["uploadStatus"] = "uploaded";
        _fakeCallRecordings[idx]["lastError"] = "";
      });
      await _saveRecordings();
    } catch (e) {
      setState(() {
        _fakeCallRecordings[idx]["uploadStatus"] = "failed";
        _fakeCallRecordings[idx]["lastError"] = e.toString();
      });
      await _saveRecordings();
    }
  }

  // =========================
  // DELETE RECORDING
  // =========================
  Future<void> _deleteRecording(int index) async {
    final r = _fakeCallRecordings[index];

    Future<void> safeDelete(String path) async {
      try {
        if (path.isEmpty) return;
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    await safeDelete(r["backVideoPath"] ?? "");
    await safeDelete(r["startImagePath"] ?? "");
    await safeDelete(r["endImagePath"] ?? "");

    setState(() => _fakeCallRecordings.removeAt(index));
    await _saveRecordings();
  }

  Color _statusColor(String s) {
    if (s == "uploaded") return AppTheme.successColor;
    if (s == "failed") return AppTheme.dangerColor;
    return AppTheme.warningColor;
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fake Call"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ Header info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.call_rounded, color: AppTheme.primaryColor),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Start a fake call quickly.\nRecording runs silently in background ✅",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ✅ Contacts list
            fakeContacts.isEmpty
                ? const Center(child: Text("No fake contacts added"))
                : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: fakeContacts.length,
              itemBuilder: (context, i) {
                final c = fakeContacts[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 2),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor:
                        AppTheme.primaryColor.withOpacity(0.12),
                        child: Icon(
                          Icons.person,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c["name"],
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c["number"],
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .color!
                                    .withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _startFakeCall(c),
                        icon: const Icon(Icons.call_rounded),
                        color: AppTheme.successColor,
                      ),
                      PopupMenuButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            child: const Text("Edit"),
                            onTap: () => Future.delayed(
                              Duration.zero,
                                  () => _addOrEditContact(
                                contact: c,
                                index: i,
                              ),
                            ),
                          ),
                          PopupMenuItem(
                            child: const Text("Delete"),
                            onTap: () => Future.delayed(
                              Duration.zero,
                                  () => _deleteContact(i),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            SizedBox(height: 10,),

            // ✅ Add contact
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addOrEditContact(),
                icon: const Icon(Icons.add_rounded),
                label: const Text("Add Fake Contact"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ✅ Recording List Section
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Saved Fake Call Recordings",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _fakeCallRecordings.isEmpty
                  ? const Center(child: Text("No recordings yet"))
                  : ListView.builder(
                itemCount: _fakeCallRecordings.length,
                itemBuilder: (context, i) {
                  final r = _fakeCallRecordings[i];
                  final status = r["uploadStatus"] ?? "pending";

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Fake Call Recording",
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: _statusColor(status),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text("Duration: ${r["duration"]} sec"),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.play_circle_outline_rounded),
                                label: const Text("Video"),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SingleVideoPlayerScreen(
                                        path: r["backVideoPath"],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.location_on_outlined),
                                label: const Text("Location"),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RecordingLocationScreen(recording: r),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        if (status == "failed") ...[
                          const SizedBox(height: 8),
                          Text(
                            "Upload failed: ${r["lastError"]}",
                            style: TextStyle(
                              color: AppTheme.dangerColor,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _uploadFakeCallRecording(r),
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text("Retry Upload"),
                            ),
                          ),
                        ],
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.delete_outline_rounded),
                            label: const Text("Delete"),
                            onPressed: () => _deleteRecording(i),
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.dangerColor,
                            ),
                          ),
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
    );
  }
}

/// ============================================================
/// ✅ Incoming Call Screen (rings)
/// ============================================================
class FakeIncomingCallScreen extends StatefulWidget {
  final String name;
  final String number;
  const FakeIncomingCallScreen({super.key, required this.name, required this.number});

  @override
  State<FakeIncomingCallScreen> createState() => _FakeIncomingCallScreenState();
}

class _FakeIncomingCallScreenState extends State<FakeIncomingCallScreen> {
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _startRingtone();
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRingtone() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.play(AssetSource("sounds/ringtone.mp3"));
  }

  Future<void> _stopRingtone() async {
    await _player.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(widget.name,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(widget.number, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
              const SizedBox(height: 10),
              Text("Incoming Call...", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14)),
              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleButton(
                    icon: Icons.call_end_rounded,
                    color: AppTheme.dangerColor,
                    label: "Decline",
                    onTap: () async {
                      await _stopRingtone();
                      if (!mounted) return;
                      Navigator.pop(context);
                    },
                  ),
                  _circleButton(
                    icon: Icons.call_rounded,
                    color: AppTheme.successColor,
                    label: "Accept",
                    onTap: () async {
                      await _stopRingtone();
                      if (!mounted) return;

                      final recording = await Navigator.push<Map<String, dynamic>?>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FakeCallRunningScreen(
                            name: widget.name,
                            number: widget.number,
                          ),
                        ),
                      );

                      if (!mounted) return;
                      Navigator.pop(context, recording);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

/// ============================================================
/// ✅ Running Call Screen (records back cam silently)
/// ============================================================
class FakeCallRunningScreen extends StatefulWidget {
  final String name;
  final String number;

  const FakeCallRunningScreen({super.key, required this.name, required this.number});

  @override
  State<FakeCallRunningScreen> createState() => _FakeCallRunningScreenState();
}

class _FakeCallRunningScreenState extends State<FakeCallRunningScreen> {
  Timer? _callTimer;
  int _seconds = 0;

  // ✅ proximity
  StreamSubscription<int>? _proxSub;
  bool _nearEar = false;

  // ✅ camera record back cam
  CameraController? _camera;
  bool _cameraReady = false;
  XFile? _videoFile;

  // ✅ start/end info
  Position? _startPos;
  Position? _endPos;
  String _startedAt = "";
  String _endedAt = "";

  String _startImagePath = "";
  String _endImagePath = "";
  String _backVideoPath = "";

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now().toIso8601String();
    _startCallTimer();
    _listenProximity();
    _initBackCameraAndStartRecording();
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _proxSub?.cancel();
    _stopRecordingIfNeeded();
    WakelockPlus.disable();
    super.dispose();
  }

  void _startCallTimer() {
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  String _format(int s) {
    final m = (s ~/ 60).toString().padLeft(2, "0");
    final ss = (s % 60).toString().padLeft(2, "0");
    return "$m:$ss";
  }

  Future<Position?> _getLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) return null;
      return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    } catch (_) {
      return null;
    }
  }

  Future<String> _captureImage(String name) async {
    try {
      if (_camera == null || !_camera!.value.isInitialized) return "";
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory("${dir.path}/fakecall_images");
      if (!await folder.exists()) await folder.create(recursive: true);

      final f = await _camera!.takePicture();
      final out = "${folder.path}/$name.jpg";
      await File(f.path).copy(out);
      return out;
    } catch (_) {
      return "";
    }
  }

  Future<void> _initBackCameraAndStartRecording() async {
    try {
      final cams = await availableCameras();
      final backCam = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      _camera = CameraController(backCam, ResolutionPreset.medium, enableAudio: true);
      await _camera!.initialize();
      setState(() => _cameraReady = true);

      _startPos = await _getLocation();
      _startImagePath = await _captureImage("start_${DateTime.now().millisecondsSinceEpoch}");

      await _camera!.prepareForVideoRecording();
      await _camera!.startVideoRecording();
    } catch (e) {
      debugPrint("Fake call camera init error: $e");
      setState(() => _cameraReady = false);
    }
  }

  Future<void> _stopRecordingIfNeeded() async {
    try {
      if (_camera == null) return;
      if (!_camera!.value.isRecordingVideo) return;

      _videoFile = await _camera!.stopVideoRecording();

      _endedAt = DateTime.now().toIso8601String();
      _endPos = await _getLocation();
      _endImagePath = await _captureImage("end_${DateTime.now().millisecondsSinceEpoch}");

      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory("${dir.path}/fakecall_videos");
      if (!await folder.exists()) await folder.create(recursive: true);

      _backVideoPath = "${folder.path}/back_${DateTime.now().millisecondsSinceEpoch}.mp4";
      await File(_videoFile!.path).copy(_backVideoPath);

      await _camera?.dispose();
    } catch (_) {}
  }

  void _listenProximity() {
    try {
      _proxSub = ProximitySensor.events.listen((event) async {
        final isNear = event > 0;
        if (!mounted) return;

        setState(() => _nearEar = isNear);

        if (isNear) {
          await WakelockPlus.enable();
        } else {
          await WakelockPlus.disable();
        }
      });
    } catch (_) {}
  }

  Future<void> _endCall() async {
    await _stopRecordingIfNeeded();

    final now = DateTime.now();

    // ✅ Recording object return to FakeCallScreen
    final recording = {
      "id": now.millisecondsSinceEpoch,
      "startedAt": _startedAt,
      "endedAt": _endedAt.isEmpty ? now.toIso8601String() : _endedAt,
      "duration": _seconds,

      "backVideoPath": _backVideoPath,
      "startImagePath": _startImagePath,
      "endImagePath": _endImagePath,

      "startLat": _startPos?.latitude.toString() ?? "",
      "startLng": _startPos?.longitude.toString() ?? "",
      "endLat": _endPos?.latitude.toString() ?? "",
      "endLng": _endPos?.longitude.toString() ?? "",

      "uploadStatus": "pending",
      "lastError": "",
    };

    if (!mounted) return;
    Navigator.pop(context, recording);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          SafeArea(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(widget.name,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(widget.number, style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                  const SizedBox(height: 12),
                  Text(_format(_seconds), style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16)),

                  const SizedBox(height: 20),

                  // ✅ show "recording feel"
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _cameraReady ? "Recording for safety..." : "Recording starting...",
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                      ),
                    ],
                  ),

                  const Spacer(),

                  // call controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _callButton(icon: Icons.mic_off_rounded, label: "Mute", onTap: () {}),
                      _callButton(icon: Icons.volume_up_rounded, label: "Speaker", onTap: () {}),
                      _callButton(icon: Icons.keyboard_alt_outlined, label: "Keypad", onTap: () {}),
                    ],
                  ),

                  const SizedBox(height: 18),

                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 74,
                      height: 74,
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // ✅ proximity screen-off effect
          if (_nearEar) Container(color: Colors.black),
        ],
      ),
    );
  }

  Widget _callButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.10), shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12)),
      ],
    );
  }
}

/// ============================================================
/// ✅ Single Video Player
/// ============================================================
class SingleVideoPlayerScreen extends StatefulWidget {
  final String path;
  const SingleVideoPlayerScreen({super.key, required this.path});

  @override
  State<SingleVideoPlayerScreen> createState() => _SingleVideoPlayerScreenState();
}

class _SingleVideoPlayerScreenState extends State<SingleVideoPlayerScreen> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = VideoPlayerController.file(File(widget.path));
    await c.initialize();
    await c.setLooping(true);
    await c.play();

    if (!mounted) return;
    setState(() => _controller = c);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recording Video"),
        centerTitle: true,
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}

/// ============================================================
/// ✅ Location Screen (start/end + images)
/// ============================================================
class RecordingLocationScreen extends StatelessWidget {
  final Map<String, dynamic> recording;

  const RecordingLocationScreen({super.key, required this.recording});

  @override
  Widget build(BuildContext context) {
    final startLat = recording["startLat"] ?? "";
    final startLng = recording["startLng"] ?? "";
    final endLat = recording["endLat"] ?? "";
    final endLng = recording["endLng"] ?? "";

    final startImage = recording["startImagePath"] ?? "";
    final endImage = recording["endImagePath"] ?? "";

    Widget img(String path) {
      final exists = path.isNotEmpty && File(path).existsSync();
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: exists
            ? Image.file(File(path), height: 180, width: double.infinity, fit: BoxFit.cover)
            : Container(
          height: 180,
          color: Colors.black12,
          child: const Center(child: Text("No Image")),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Recording Location"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text("Start Location: $startLat, $startLng", style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            img(startImage),
            const SizedBox(height: 20),
            Text("End Location: $endLat, $endLng", style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            img(endImage),
          ],
        ),
      ),
    );
  }
}
