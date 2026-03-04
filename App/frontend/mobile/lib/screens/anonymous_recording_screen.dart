// App/frontend/mobile/lib/screens/anonymous_recording_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../app/theme.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';

class AnonymousRecordingScreen extends StatefulWidget {
  const AnonymousRecordingScreen({super.key});

  @override
  State<AnonymousRecordingScreen> createState() => _AnonymousRecordingScreenState();
}

class _AnonymousRecordingScreenState extends State<AnonymousRecordingScreen> {
  List<Map<String, dynamic>> _recordings = [];
  bool _isSyncingRemote = false;

  bool _isRecording = false;
  bool _isStoppingRecording = false;
  int _seconds = 0;
  Timer? _timer;

  CameraController? _frontCam;
  CameraController? _backCam;
  bool _camsReady = false;

  String _startImagePath = "";
  String _endImagePath = "";
  bool _frontRecordingStarted = false;
  bool _backRecordingStarted = false;

  Position? _startPos;
  Position? _endPos;
  String _startedAt = "";
  String _endedAt = "";

  @override
  void initState() {
    super.initState();
    _initData();
    _initCameras();
  }

  Future<void> _initData() async {
    await _loadRecordings();
    await _syncRecordingsFromBackend();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _frontCam?.dispose();
    _backCam?.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString("anonymous_recordings_list") ?? "[]";
    final decoded = jsonDecode(raw) as List<dynamic>;

    setState(() {
      _recordings = decoded.map((e) => Map<String, dynamic>.from(e)).toList();
    });
  }

  Future<void> _saveRecordings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("anonymous_recordings_list", jsonEncode(_recordings));
  }

  Future<String> _cacheRemoteFile({
    required String url,
    required String folderName,
    required String fallbackFileName,
  }) async {
    if (url.trim().isEmpty) return "";

    try {
      final uri = Uri.parse(url);
      final candidateName = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : fallbackFileName;
      final fileName = candidateName.isEmpty ? fallbackFileName : candidateName;

      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory("${dir.path}/$folderName");
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final outPath = "${folder.path}/$fileName";
      final outFile = File(outPath);
      if (await outFile.exists()) return outPath;

      final bytes = await ApiService.downloadMediaBytes(url);
      await outFile.writeAsBytes(bytes, flush: true);
      return outPath;
    } catch (_) {
      return "";
    }
  }

  Future<void> _syncRecordingsFromBackend() async {
    if (_isSyncingRemote) return;

    setState(() => _isSyncingRemote = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("cached_user_id") ?? 1;

      final history = await ApiService.fetchAnonymousRecordingHistory(userId: userId);
      final List<Map<String, dynamic>> synced = [];

      for (final item in history) {
        final id = (item["id"] ?? DateTime.now().millisecondsSinceEpoch).toString();
        final files = Map<String, dynamic>.from(item["files"] ?? {});

        final frontMeta = Map<String, dynamic>.from(files["front_video"] ?? {});
        final backMeta = Map<String, dynamic>.from(files["back_video"] ?? {});
        final startMeta = Map<String, dynamic>.from(files["start_image"] ?? {});
        final endMeta = Map<String, dynamic>.from(files["end_image"] ?? {});

        String frontLocal = await _cacheRemoteFile(
          url: (frontMeta["url"] ?? "").toString(),
          folderName: "anonymous_videos_cache",
          fallbackFileName: "${id}_front.mp4",
        );

        String backLocal = await _cacheRemoteFile(
          url: (backMeta["url"] ?? "").toString(),
          folderName: "anonymous_videos_cache",
          fallbackFileName: "${id}_back.mp4",
        );

        final startLocal = await _cacheRemoteFile(
          url: (startMeta["url"] ?? "").toString(),
          folderName: "anonymous_images_cache",
          fallbackFileName: "${id}_start.jpg",
        );

        final endLocal = await _cacheRemoteFile(
          url: (endMeta["url"] ?? "").toString(),
          folderName: "anonymous_images_cache",
          fallbackFileName: "${id}_end.jpg",
        );

        if (frontLocal.isEmpty && backLocal.isNotEmpty) {
          frontLocal = backLocal;
        }
        if (backLocal.isEmpty && frontLocal.isNotEmpty) {
          backLocal = frontLocal;
        }

        final hasAnyVideo = frontLocal.isNotEmpty || backLocal.isNotEmpty;

        synced.add({
          "id": id,
          "serverRecordingId": id,
          "startedAt": item["started_at"] ?? "",
          "endedAt": item["ended_at"] ?? "",
          "duration": item["duration_seconds"] ?? 0,
          "frontVideoPath": frontLocal,
          "backVideoPath": backLocal,
          "startImagePath": startLocal,
          "endImagePath": endLocal,
          "startLat": (item["start_location"]?['lat'] ?? "").toString(),
          "startLng": (item["start_location"]?['lng'] ?? "").toString(),
          "endLat": (item["end_location"]?['lat'] ?? "").toString(),
          "endLng": (item["end_location"]?['lng'] ?? "").toString(),
          "uploadStatus": hasAnyVideo ? "uploaded" : "failed",
          "lastError": hasAnyVideo ? "" : "Recording details found, but video file is missing on server.",
          "source": "remote",
        });
      }

      final localPending = _recordings.where((r) {
        final status = (r["uploadStatus"] ?? "").toString();
        final source = (r["source"] ?? "local").toString();
        return source != "remote" && status != "uploaded";
      }).toList();

      final merged = <Map<String, dynamic>>[...synced, ...localPending];

      if (!mounted) return;
      setState(() => _recordings = merged);
      await _saveRecordings();
    } catch (_) {
      // keep cached local records if sync fails
    } finally {
      if (mounted) {
        setState(() => _isSyncingRemote = false);
      }
    }
  }

  Future<void> _initCameras() async {
    try {
      final cams = await availableCameras();

      final front = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      final back = cams.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );

      CameraController? frontController;
      CameraController? backController;

      try {
        frontController = CameraController(front, ResolutionPreset.medium, enableAudio: true);
        await frontController.initialize();
      } catch (e) {
        debugPrint("Front camera init failed: $e");
      }

      try {
        backController = CameraController(back, ResolutionPreset.medium, enableAudio: true);
        await backController.initialize();
      } catch (e) {
        debugPrint("Back camera init failed: $e");
      }

      _frontCam = frontController;
      _backCam = backController;

      setState(() => _camsReady = _frontCam != null || _backCam != null);
    } catch (e) {
      setState(() => _camsReady = false);
      debugPrint("Camera init failed: $e");
    }
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

  // ✅ capture image (use back cam)
  Future<String> _captureImage(String name) async {
    try {
      if (_backCam == null || !_backCam!.value.isInitialized) return "";
      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory("${dir.path}/anonymous_images");
      if (!await folder.exists()) await folder.create(recursive: true);

      final f = await _backCam!.takePicture();
      final out = "${folder.path}/$name.jpg";
      await File(f.path).copy(out);
      return out;
    } catch (_) {
      return "";
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _seconds = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _seconds++);
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    AppSnackBar.show(context, msg);
  }

  Future<void> _startRecording() async {
    if (_frontCam?.value.isRecordingVideo == true || _backCam?.value.isRecordingVideo == true) {
      _showSnack("Already recording...");
      return;
    }

    if (!_camsReady) {
      _showSnack("Camera not ready ❌");
      return;
    }
    if (_isRecording) return;

    try {
      setState(() => _isRecording = true);
      _frontRecordingStarted = false;
      _backRecordingStarted = false;
      _startedAt = DateTime.now().toIso8601String();

      _startPos = await _getLocation();
      _startImagePath = await _captureImage("start_${DateTime.now().millisecondsSinceEpoch}");

      // await _frontcam!.prepareforvideorecording();
      // await _backcam!.prepareforvideorecording();

      try {
        if (_frontCam != null && _frontCam!.value.isInitialized) {
          await _frontCam!.startVideoRecording();
          _frontRecordingStarted = true;
        }
      } catch (e) {
        debugPrint("Front start failed: $e");
      }

      try {
        if (_backCam != null && _backCam!.value.isInitialized) {
          await _backCam!.startVideoRecording();
          _backRecordingStarted = true;
        }
      } catch (e) {
        debugPrint("Back start failed: $e");
      }

      if (!_frontRecordingStarted && !_backRecordingStarted) {
        setState(() => _isRecording = false);
        _showSnack("Could not start camera recording ❌");
        return;
      }

      _seconds = 0;
      _startTimer();
    } catch (e) {
      setState(() => _isRecording = false);
      debugPrint("Start recording error: $e");
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _isStoppingRecording) return;
    setState(() => _isStoppingRecording = true);

    try {
      _timer?.cancel();

      setState(() {
        _isRecording = false;
      });

      _endedAt = DateTime.now().toIso8601String();
      _endPos = await _getLocation();
      _endImagePath = await _captureImage("end_${DateTime.now().millisecondsSinceEpoch}");

      XFile? frontFile;
      XFile? backFile;

      try {
        if (_frontCam != null && _frontRecordingStarted) {
          frontFile = await _frontCam!.stopVideoRecording();
        }
      } catch (e) {
        debugPrint("Front stop failed: $e");
      }

      try {
        if (_backCam != null && _backRecordingStarted) {
          backFile = await _backCam!.stopVideoRecording();
        }
      } catch (e) {
        debugPrint("Back stop failed: $e");
      }

      _frontRecordingStarted = false;
      _backRecordingStarted = false;

      if (frontFile == null && backFile == null) {
        _showSnack("Recording failed: no video file generated ❌");
        return;
      }


      final dir = await getApplicationDocumentsDirectory();
      final folder = Directory("${dir.path}/anonymous_videos");
      if (!await folder.exists()) await folder.create(recursive: true);

      final id = DateTime.now().millisecondsSinceEpoch;

      String frontSaved = "";
      String backSaved = "";

      if (frontFile != null) {
        frontSaved = "${folder.path}/front_$id.mp4";
        await File(frontFile.path).copy(frontSaved);
      }

      if (backFile != null) {
        backSaved = "${folder.path}/back_$id.mp4";
        await File(backFile.path).copy(backSaved);
      }

      if (frontSaved.isEmpty && backSaved.isEmpty) {
        _showSnack("Recording save failed ❌");
        return;
      }

      final normalized = await _normalizeAnonymousMedia(
        frontVideoPath: frontSaved,
        backVideoPath: backSaved,
        startImagePath: _startImagePath,
        endImagePath: _endImagePath,
      );

      if (normalized == null) {
        _showSnack("Recording saved but video file missing ❌");
        return;
      }

      final recordingObj = {
        "id": id,
        "startedAt": _startedAt,
        "endedAt": _endedAt,
        "duration": _seconds,

        "frontVideoPath": normalized["frontVideoPath"],
        "backVideoPath": normalized["backVideoPath"],

        "startImagePath": normalized["startImagePath"],
        "endImagePath": normalized["endImagePath"],

        "startLat": _startPos?.latitude.toString() ?? "",
        "startLng": _startPos?.longitude.toString() ?? "",
        "endLat": _endPos?.latitude.toString() ?? "",
        "endLng": _endPos?.longitude.toString() ?? "",

        "uploadStatus": "pending",
        "lastError": "",
      };

      // ✅ insert into list and save prefs
      setState(() {
        _recordings.insert(0, recordingObj);
      });
      await _saveRecordings();

      _showSnack("Recording saved locally ✅");

      // ✅ upload (if only back exists, upload only back)
      await _uploadRecording(recordingObj);

    } catch (e) {
      debugPrint("STOP RECORDING ERROR: $e");
      _showSnack("Stop error: $e");
    } finally {
      if (mounted) {
        setState(() => _isStoppingRecording = false);
      }
    }

    await _reInitCamerasAfterRecording();
  }

  Future<Map<String, String>?> _normalizeAnonymousMedia({
    required String frontVideoPath,
    required String backVideoPath,
    required String startImagePath,
    required String endImagePath,
  }) async {
    Future<bool> exists(String path) async {
      if (path.isEmpty) return false;
      return File(path).exists();
    }

    String front = frontVideoPath;
    String back = backVideoPath;
    String startImg = startImagePath;
    String endImg = endImagePath;

    final frontOk = await exists(front);
    final backOk = await exists(back);
    if (!frontOk && backOk) {
      front = back;
    } else if (!backOk && frontOk) {
      back = front;
    }

    final finalFrontOk = await exists(front);
    final finalBackOk = await exists(back);
    if (!finalFrontOk || !finalBackOk) {
      return null;
    }

    final startOk = await exists(startImg);
    final endOk = await exists(endImg);
    if (!startOk) startImg = "";
    if (!endOk) endImg = "";

    return {
      "frontVideoPath": front,
      "backVideoPath": back,
      "startImagePath": startImg,
      "endImagePath": endImg,
    };
  }

  Future<void> _reInitCamerasAfterRecording() async {
    try {
      setState(() => _camsReady = false);

      await _frontCam?.dispose();
      await _backCam?.dispose();

      _frontCam = null;
      _backCam = null;

      await _initCameras(); // your existing init function
    } catch (e) {
      debugPrint("Re-init cameras failed: $e");
    }
  }


  Future<void> _uploadRecording(Map<String, dynamic> item) async {
    final idx = _recordings.indexWhere((r) => r["id"] == item["id"]);
    if (idx == -1) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("cached_user_id") ?? 1;

      setState(() {
        _recordings[idx]["uploadStatus"] = "uploading";
        _recordings[idx]["lastError"] = "";
      });
      await _saveRecordings();

      final frontPath = item["frontVideoPath"] ?? "";
      final backPath = item["backVideoPath"] ?? "";

      // ✅ if front missing or back missing, still upload whatever exists
      final response = await ApiService.uploadAnonymousRecording(
        userId: userId,
        frontVideoPath: frontPath.isEmpty ? backPath : frontPath,
        backVideoPath: backPath.isEmpty ? frontPath : backPath,
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

      final serverId = (response["recording"]?['id'] ?? "").toString();

      setState(() {
        _recordings[idx]["uploadStatus"] = "uploaded";
        if (serverId.isNotEmpty) {
          _recordings[idx]["serverRecordingId"] = serverId;
        }
      });
      await _saveRecordings();

      _showSnack("Uploaded to server ✅");

    } catch (e) {
      setState(() {
        _recordings[idx]["uploadStatus"] = "failed";
        _recordings[idx]["lastError"] = e.toString();
      });
      await _saveRecordings();
      _showSnack("Upload failed ❌");
    }
  }

  // ✅ delete from server + cache + list
  Future<String> _resolveServerRecordingId(Map<String, dynamic> record) async {
    final explicit = (record["serverRecordingId"] ?? "").toString().trim();
    if (explicit.isNotEmpty) return explicit;

    final idValue = (record["id"] ?? "").toString().trim();
    if (idValue.startsWith("user")) return idValue;
    return "";
  }

  Future<void> _deleteRecordingWithConfirmation(int index) async {
    if (index < 0 || index >= _recordings.length) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete recording?"),
          content: const Text(
            "This will remove the recording from your phone cache and server history (if uploaded).",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) return;
    await _deleteRecording(index);
  }

  Future<void> _deleteRecording(int index) async {
    final r = _recordings[index];

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt("cached_user_id") ?? 1;
      final serverRecordingId = await _resolveServerRecordingId(r);
      if (serverRecordingId.isNotEmpty) {
        await ApiService.deleteAnonymousRecording(
          userId: userId,
          recordingId: serverRecordingId,
        );
      }
    } catch (e) {
      _showSnack("Could not delete from server: $e");
      return;
    }

    Future<void> safeDelete(String path) async {
      try {
        if (path.isEmpty) return;
        final f = File(path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    await safeDelete(r["frontVideoPath"] ?? "");
    await safeDelete(r["backVideoPath"] ?? "");
    await safeDelete(r["startImagePath"] ?? "");
    await safeDelete(r["endImagePath"] ?? "");

    setState(() => _recordings.removeAt(index));
    await _saveRecordings();
  }

  Color _statusColor(String s) {
    if (s == "uploaded") return AppTheme.successColor;
    if (s == "failed") return AppTheme.dangerColor;
    return AppTheme.warningColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Anonymous Recording"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ✅ start/stop recording button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.videocam_rounded, color: AppTheme.dangerColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isRecording
                          ? "Recording silently... $_seconds sec"
                          : "Tap Start to record silently (Front + Back)",
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isStoppingRecording ? null : (_isRecording ? _stopRecording : _startRecording),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isRecording ? AppTheme.dangerColor : AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: _isStoppingRecording
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(_isRecording ? "Stop" : "Start"),
                  )
                ],
              ),
            ),
            if (_isStoppingRecording) ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Saving recording... Please wait',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 16),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Your Recordings",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            if (_isSyncingRemote) ...[
              const SizedBox(height: 6),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Syncing recordings from server...",
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
            const SizedBox(height: 10),

            Expanded(
              child: _recordings.isEmpty
                  ? const Center(child: Text("No recordings yet"))
                  : ListView.builder(
                itemCount: _recordings.length,
                itemBuilder: (context, i) {
                  final r = _recordings[i];
                  final status = r["uploadStatus"] ?? "pending";
                  final canPlayFront = (r["frontVideoPath"] ?? "").toString().isNotEmpty && File((r["frontVideoPath"] ?? "").toString()).existsSync();
                  final canPlayBack = (r["backVideoPath"] ?? "").toString().isNotEmpty && File((r["backVideoPath"] ?? "").toString()).existsSync();

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
                            const Text("Anonymous Recording", style: TextStyle(fontWeight: FontWeight.w900)),
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
                                label: const Text("Front"),
                                onPressed: canPlayFront ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _VideoPlayer(path: r["frontVideoPath"]),
                                    ),
                                  );
                                } : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.play_circle_outline_rounded),
                                label: const Text("Back"),
                                onPressed: canPlayBack ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => _VideoPlayer(path: r["backVideoPath"]),
                                    ),
                                  );
                                } : null,
                              ),
                            ),
                          ],
                        ),

                        if (!canPlayFront && !canPlayBack) ...[
                          const SizedBox(height: 8),
                          Text(
                            "Video file not available for this record.",
                            style: TextStyle(color: AppTheme.dangerColor, fontSize: 12),
                          ),
                        ],

                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.location_on_outlined),
                            label: const Text("Location + Images"),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _LocationScreen(recording: r),
                                ),
                              );
                            },
                          ),
                        ),

                        if (status == "failed") ...[
                          const SizedBox(height: 8),
                          Text(
                            "Upload failed: ${r["lastError"]}",
                            style: TextStyle(color: AppTheme.dangerColor, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => _uploadRecording(r),
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
                            onPressed: () => _deleteRecordingWithConfirmation(i),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.dangerColor),
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

class _VideoPlayer extends StatefulWidget {
  final String path;
  const _VideoPlayer({required this.path});

  @override
  State<_VideoPlayer> createState() => _VideoPlayerState();
}

class _VideoPlayerState extends State<_VideoPlayer> {
  VideoPlayerController? _c;
  String _error = "";

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      if (widget.path.isEmpty || !await File(widget.path).exists()) {
        if (!mounted) return;
        setState(() => _error = "Video file not found on device.");
        return;
      }

      final c = VideoPlayerController.file(File(widget.path));
      await c.initialize();
      await c.setLooping(true);
      await c.play();
      if (!mounted) return;
      setState(() => _c = c);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "Unable to play this recording.");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_c == null && _error.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_c == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Recording")),
        body: Center(child: Text(_error)),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text("Recording")),
      body: Center(
        child: AspectRatio(
          aspectRatio: _c!.value.aspectRatio,
          child: VideoPlayer(_c!),
        ),
      ),
    );
  }
}

// / ✅ location + images screen
class _LocationScreen extends StatelessWidget {
  final Map<String, dynamic> recording;
  const _LocationScreen({required this.recording});

  @override
  Widget build(BuildContext context) {
    Widget img(String path) {
      final exists = path.isNotEmpty && File(path).existsSync();
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: exists
            ? Image.file(File(path), height: 180, width: double.infinity, fit: BoxFit.cover)
            : Container(height: 180, color: Colors.black12, child: const Center(child: Text("No Image"))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Location + Images")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              "Start: ${recording["startLat"]}, ${recording["startLng"]}",
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            img(recording["startImagePath"] ?? ""),
            const SizedBox(height: 18),
            Text(
              "End: ${recording["endLat"]}, ${recording["endLng"]}",
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            img(recording["endImagePath"] ?? ""),
          ],
        ),
      ),
    );
  }
}
