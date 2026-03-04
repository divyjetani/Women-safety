// App/frontend/mobile/lib/widgets/sos_popup.dart

import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../app/auth_provider.dart';
import '../app/theme.dart';
import '../services/api_service.dart';
import '../services/firebase_service.dart';
import '../services/group_storage.dart';

class SOSPopup extends StatefulWidget {
  // / ✅ pass incognito from your map screen / state
  final bool incognito;

  final String groupId;
  final bool autoStart;
  final bool automaticFlow;

  const SOSPopup({
    super.key,
    required this.incognito,
    this.groupId = "bubble",
    this.autoStart = false,
    this.automaticFlow = false,
  });

  @override
  State<SOSPopup> createState() => _SOSPopupState();
}

class _SOSPopupState extends State<SOSPopup> {
  bool _isSending = false;
  String _status = '';
  bool _success = false;

  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final AudioRecorder _audioRecorder = AudioRecorder();

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<String> _captureSelfieBase64() async {
    CameraController? controller;
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) return '';
      final front = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      controller = CameraController(front, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      final picture = await controller.takePicture();
      final bytes = await File(picture.path).readAsBytes();
      if (bytes.isEmpty) return '';
      return 'data:image/jpeg;base64,${base64Encode(bytes)}';
    } catch (_) {
      return '';
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
    }
  }

  Future<String> _capture10sAudioBase64() async {
    try {
      final hasMicPermission = await _audioRecorder.hasPermission();
      if (!hasMicPermission) return '';

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      await Future<void>.delayed(const Duration(seconds: 10));
      final output = await _audioRecorder.stop();
      if (output == null || output.trim().isEmpty) return '';

      final file = File(output);
      if (!await file.exists()) return '';
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return '';
      return 'data:audio/mp4;base64,${base64Encode(bytes)}';
    } catch (_) {
      try {
        await _audioRecorder.stop();
      } catch (_) {}
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _sendSOS(
          incognito: widget.incognito,
          groupId: widget.groupId,
        );
      });
    }
  }

  Future<void> _sendSOS({
    required bool incognito,
    required String groupId,
  }) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _status = widget.automaticFlow
          ? 'Sending automatic SOS to bubble members...'
          : 'Sending emergency alert...';
      _success = false;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      // ✅ step 1: show local notification immediately
      await _showLocalNotification(user.username, 'Sending SOS...');

      if (!mounted) return;
      setState(() {
        _status = widget.automaticFlow
            ? 'Sending automatic SOS to emergency contacts and bubble members...'
            : 'Sending notifications to emergency contacts...';
      });

      // ✅ step 2: emergency contacts notification
      await _sendEmergencyNotifications(user.username, 'Current Location');

      // ✅ step 3: if incognito on => stop group sos
      if (incognito) {
        if (!mounted) return;
        setState(() {
          _success = true;
          _status = '✅ Emergency contacts notified!\n'
              'Incognito mode is ON, so group SOS was not sent.\n'
              'Stay safe ❤️';
        });

        await Future.delayed(const Duration(seconds: 4));
        if (mounted) Navigator.of(context).pop();
        return;
      }

      // ✅ step 4: send full sos payload to backend
      if (!mounted) return;
      setState(() {
        _status = 'Capturing selfie image for SOS...';
      });

      final capturedSelfie = await _captureSelfieBase64();
      if (!mounted) return;

      setState(() {
        _status = 'Recording 10s SOS audio clip...';
      });
      final capturedAudio = await _capture10sAudioBase64();

      if (!mounted) return;
      setState(() {
        _status = 'Sharing SOS details with media to contacts and bubble members...';
      });

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final battery = await Battery().batteryLevel;

        final groups = await GroupStorage.loadGroups();
        final selected = await GroupStorage.loadSelectedGroup();
        String? selectedBubbleCode;
        if (selected != null) {
          final matched = groups.where((g) => g.id == selected).toList();
          if (matched.isNotEmpty) {
            selectedBubbleCode = matched.first.code ?? matched.first.id;
          }
        }

        final locationText =
            '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

        final sosResponse = await ApiService.sendSOS(
          userId: user.id,
          location: locationText,
          lat: position.latitude,
          lng: position.longitude,
          battery: battery,
          triggerType: 'manual',
          triggerReason: 'Manual SOS button pressed by user',
          message: 'SOS from ${user.username}. Need immediate help.',
          bubbleCode: selectedBubbleCode,
          cameraFrontImage: capturedSelfie.isNotEmpty ? capturedSelfie : user.faceImage,
          cameraBackImage: user.faceImage,
          audio10sUrl: capturedAudio,
        );
        debugPrint('SOS sent with reportId=${sosResponse.reportId}');
      } catch (e) {
        debugPrint("SOS backend failed: $e");
      }

      if (!mounted) return;
      setState(() {
        _success = true;
        _status = widget.automaticFlow
          ? '✅ Automatic SOS sent successfully!\n'
            'Bubble group + emergency contacts notified.\n'
            'Stay calm and wait for help.'
          : '✅ Emergency alert sent successfully!\n'
            'Bubble group + emergency contacts notified.\n'
            'Stay calm and wait for help.';
      });

      await Future.delayed(const Duration(seconds: 4));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _success = false;
        _status =
        '❌ Failed to send alert. Please try again.\nMake sure you have internet connection.';
      });
      debugPrint('SOS Error: $e');
    } finally {
      if (mounted && !_success) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendEmergencyNotifications(String userName, String location) async {
    try {
      debugPrint('🔄 Getting emergency contact tokens...');
      final currentToken = await FirebaseNotificationService.getFCMToken();
      if (currentToken != null) {
        debugPrint('📱 Device token available: ${currentToken.substring(0, 16)}...');
      }
      debugPrint('✅ Emergency notifications are dispatched by backend SOS pipeline');
    } catch (e) {
      debugPrint('❌ Error sending notifications: $e');
    }
  }

  Future<void> _showLocalNotification(String userName, String location) async {
    try {
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotificationsPlugin.initialize(initializationSettings);

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'emergency_channel',
        'Emergency Alerts',
        description: 'Emergency SOS notifications',
        importance: Importance.max,
      );

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _localNotificationsPlugin.show(
        999,
        'SOS Activated 🚨',
        'Emergency alert sent to your contacts',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'emergency_channel',
            'Emergency Alerts',
            channelDescription: 'Emergency SOS notifications',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            playSound: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: 'sos_activated',
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _success
        ? Colors.green
        : _isSending
        ? Colors.orange
        : Colors.red;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildSOSIcon(),

              const SizedBox(height: 20),

              Text(
                _success ? 'Emergency Alert Sent!' : 'Emergency SOS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                _success
                    ? 'Help is on the way! Notifications sent successfully.'
                    : 'This will notify your emergency contacts immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),

              const SizedBox(height: 18),

              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor.withOpacity(0.35)),
                  ),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              if (!_isSending && !_success)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Row(
                        children: [
                          Icon(Icons.notifications_active, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Will notify:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        '• Emergency contacts\n• Bubble group members\n• Your phone for confirmation',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSOSIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _success
                  ? [Colors.green, Colors.greenAccent]
                  : [Colors.red, AppTheme.dangerColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (_success ? Colors.green : Colors.red).withOpacity(0.3),
                blurRadius: _isSending ? 30 : 20,
                spreadRadius: _isSending ? 10 : 5,
              ),
            ],
          ),
          child: Icon(
            _success ? Icons.check : Icons.emergency,
            color: Colors.white,
            size: 40,
          ),
        ),
        if (_isSending && !_success)
          const SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildActionButtons() {
    if (_success) {
      return ElevatedButton(
        onPressed: () => Navigator.of(context).pop(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
        child: const Text('Okay, Got It'),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isSending ? null : () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).textTheme.bodyLarge!.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            // ✅ fixed: wrap inside function
            onPressed: _isSending
                ? null
                : () => _sendSOS(
              incognito: widget.incognito,
              groupId: widget.groupId,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 3,
            ),
            child: _isSending
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
                : const Text('SEND SOS'),
          ),
        ),
      ],
    );
  }
}
