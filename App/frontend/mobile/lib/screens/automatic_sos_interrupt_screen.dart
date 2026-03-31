// App/frontend/mobile/lib/screens/automatic_sos_interrupt_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';

import '../app/auth_provider.dart';
import '../services/api_service.dart';
import '../services/group_storage.dart';
import '../widgets/app_snackbar.dart';

class AutomaticSosInterruptScreen extends StatefulWidget {
  final String reason;
  final Future<void> Function() onConfirmedDanger;

  const AutomaticSosInterruptScreen({
    super.key,
    required this.reason,
    required this.onConfirmedDanger,
  });

  @override
  State<AutomaticSosInterruptScreen> createState() => _AutomaticSosInterruptScreenState();
}

class _AutomaticSosInterruptScreenState extends State<AutomaticSosInterruptScreen> {
  static const int _initialCountdownSeconds = 13;
  static const int _statusPollSeconds = 1;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final AudioRecorder _audioRecorder = AudioRecorder();

  bool _flashOn = true;
  bool _checkingStop = false;
  bool _isStartingPending = false;
  bool _isCompleted = false;
  bool _hasSentAlert = false;
  String _verificationStatus = '';
  String _pendingSetupStatus = '';

  int _secondsLeft = _initialCountdownSeconds;
  String? _pendingId;

  Timer? _flashTimer;
  Timer? _countdownTimer;
  Timer? _statusPollTimer;

  Future<bool> _authenticateToCancel() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheckBiometric = await _localAuth.canCheckBiometrics;

      if (!isSupported && !canCheckBiometric) {
        // No auth method present on this device; allow cancel.
        return true;
      }

      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to cancel automatic SOS',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } on PlatformException catch (e) {
      final code = e.code;
      if (code == auth_error.notAvailable ||
          code == auth_error.notEnrolled ||
          code == auth_error.passcodeNotSet) {
        // "if present" behavior: continue when lock/biometric is unavailable.
        return true;
      }
      rethrow;
    }
  }

  @override
  void initState() {
    super.initState();
    _beginAutomaticPendingFlow();
  }

  Future<void> _beginAutomaticPendingFlow() async {
    if (_isStartingPending) return;
    _isStartingPending = true;
    if (mounted) {
      setState(() {
        _pendingSetupStatus = 'Preparing automatic SOS...';
      });
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
      } catch (_) {
        position = null;
      }

      int? battery;
      try {
        battery = await Battery().batteryLevel;
      } catch (_) {
        battery = null;
      }

      final groups = await GroupStorage.loadGroups();
      final selected = await GroupStorage.loadSelectedGroup();
      String? selectedBubbleCode;
      if (selected != null) {
        final matched = groups.where((g) => g.id == selected).toList();
        if (matched.isNotEmpty) {
          selectedBubbleCode = matched.first.code ?? matched.first.id;
        }
      }

      final locationText = (position == null)
          ? 'Unknown location'
          : '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';

      final startResp = await ApiService.startAutomaticSosPending(
        userId: user.id,
        reason: widget.reason,
        location: locationText,
        lat: position?.latitude,
        lng: position?.longitude,
        battery: battery,
        bubbleCode: selectedBubbleCode,
        cameraFrontImage: user.faceImage,
        cameraBackImage: user.faceImage,
        audio10sUrl: null,
        message: 'Automatic SOS triggered. Reason: ${widget.reason}',
      );

      final pendingId = startResp['pending_id']?.toString();
      if (!mounted || pendingId == null || pendingId.isEmpty) return;

      final seconds = (startResp['seconds_remaining'] as num?)?.toInt() ?? _initialCountdownSeconds;
      setState(() {
        _pendingId = pendingId;
        _secondsLeft = seconds;
      });

      _startFlashCountdown();
      _startStatusPolling();

      // Record/capture media in background while countdown is already running.
      unawaited(_captureAndUploadPendingMedia(user.id, pendingId, user.faceImage));
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Failed to start automatic SOS countdown.',
        type: AppSnackBarType.error,
      );
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isStartingPending = false;
          _pendingSetupStatus = '';
        });
      } else {
        _isStartingPending = false;
      }
    }
  }

  Future<void> _captureAndUploadPendingMedia(int userId, String pendingId, String fallbackFaceImage) async {
    try {
      if (mounted) {
        setState(() {
          _pendingSetupStatus = 'Recording 10s audio in background...';
        });
      }

      final captures = await Future.wait<String>([
        _captureSelfieBase64(),
        _capture10sAudioBase64(),
      ]);
      final capturedSelfie = captures[0];
      final capturedAudio = captures[1];

      await ApiService.updateAutomaticPendingSosMedia(
        pendingId: pendingId,
        userId: userId,
        cameraFrontImage: capturedSelfie.isNotEmpty ? capturedSelfie : fallbackFaceImage,
        cameraBackImage: fallbackFaceImage,
        audio10sUrl: capturedAudio.isNotEmpty ? capturedAudio : null,
      );
    } catch (_) {
      // Best-effort media enrichment; pending SOS should continue even if upload fails.
    } finally {
      if (mounted && !_isCompleted) {
        setState(() {
          _pendingSetupStatus = '';
        });
      }
    }
  }

  Future<String> _captureSelfieBase64() async {
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return '';

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);

      final selfie = await controller.takePicture();
      final selfieBytes = await File(selfie.path).readAsBytes();
      if (selfieBytes.isEmpty) return '';
      return 'data:image/jpeg;base64,${base64Encode(selfieBytes)}';
    } catch (_) {
      return '';
    } finally {
      await controller?.dispose();
    }
  }

  Future<String> _capture10sAudioBase64() async {
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) return '';

      final dir = await getTemporaryDirectory();
      final outputPath = '${dir.path}/auto_sos_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: outputPath,
      );

      await Future<void>.delayed(const Duration(seconds: 10));
      final recordedPath = await _audioRecorder.stop();
      if (recordedPath == null || recordedPath.trim().isEmpty) return '';

      final file = File(recordedPath);
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

  void _startFlashCountdown() {
    _flashTimer?.cancel();
    _countdownTimer?.cancel();

    HapticFeedback.vibrate();

    _flashTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted || _isCompleted) return;
      setState(() => _flashOn = !_flashOn);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _checkingStop || _isCompleted) return;

      if (_secondsLeft > 1) {
        setState(() => _secondsLeft -= 1);
        HapticFeedback.heavyImpact();
      } else {
        setState(() => _secondsLeft = 0);
        timer.cancel();
        _onCountdownZero();
      }
    });
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: _statusPollSeconds), (_) {
      _pollAutomaticStatus();
    });
  }

  Future<void> _pollAutomaticStatus() async {
    final pendingId = _pendingId;
    if (pendingId == null || _isCompleted) return;

    try {
      final statusResp = await ApiService.getAutomaticSosStatus(pendingId: pendingId);
      if (!mounted) return;

      final status = statusResp['status']?.toString() ?? 'pending';
      final remaining = (statusResp['seconds_remaining'] as num?)?.toInt() ?? 0;

      if (status == 'pending') {
        setState(() {
          _secondsLeft = remaining;
        });
        return;
      }

      if (status == 'sent') {
        await _showAlertSentAndClose();
        return;
      }

      if (status == 'cancelled') {
        _flashTimer?.cancel();
        _countdownTimer?.cancel();
        _statusPollTimer?.cancel();
        _isCompleted = true;
        if (mounted) Navigator.of(context).pop();
      }
    } catch (_) {
    }
  }

  void _onCountdownZero() {
    if (_isCompleted) return;
    _flashTimer?.cancel();
    _countdownTimer?.cancel();
    if (!mounted) return;
    setState(() => _flashOn = true);
  }

  Future<void> _showAlertSentAndClose() async {
    if (_isCompleted || _hasSentAlert) return;
    _isCompleted = true;
    _hasSentAlert = true;

    _flashTimer?.cancel();
    _countdownTimer?.cancel();
    _statusPollTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _flashOn = true;
      _secondsLeft = 0;
    });

    try {
      await widget.onConfirmedDanger();
    } catch (_) {
      // backend already marks as sent
    }

    if (!mounted) return;
    AppSnackBar.show(
      context,
      'Alert has been sent.',
      type: AppSnackBarType.success,
    );

    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _stopAndVerify() async {
    if (_checkingStop || _isCompleted) return;
    setState(() {
      _checkingStop = true;
      _verificationStatus = 'Preparing authentication...';
    });

    _flashTimer?.cancel();
    _countdownTimer?.cancel();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      setState(() {
        _verificationStatus = 'Use fingerprint/device lock to confirm cancel...';
      });
      final authenticated = await _authenticateToCancel();
      if (!mounted) return;

      if (authenticated) {
        await _cancelPendingSos();
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        AppSnackBar.show(
          context,
          'Device authentication failed. SOS will continue.',
          type: AppSnackBarType.warning,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Authentication error. SOS countdown resumed.',
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _checkingStop = false;
          _verificationStatus = '';
        });
        if (!_isCompleted && _secondsLeft > 0) {
          _startFlashCountdown();
        }
      }
    }
  }

  Future<void> _cancelPendingSos() async {
    final pendingId = _pendingId;
    if (pendingId == null) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    _statusPollTimer?.cancel();
    await ApiService.cancelAutomaticSos(
      pendingId: pendingId,
      userId: user.id,
      reason: 'false_alert: cancelled by user after device authentication',
    );
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _countdownTimer?.cancel();
    _statusPollTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _flashOn ? Colors.red : Colors.white;
    final fg = _flashOn ? Colors.white : Colors.red;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'AUTOMATIC SOS',
                  style: TextStyle(
                    color: fg,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.reason,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  '$_secondsLeft',
                  style: TextStyle(
                    color: fg,
                    fontSize: 70,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _secondsLeft == 0
                      ? 'Alert has been sent.'
                      : 'Tap STOP and verify face or device lock to cancel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_isStartingPending && _pendingSetupStatus.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _pendingSetupStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (_checkingStop && _verificationStatus.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    _verificationStatus,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 26),
                ElevatedButton.icon(
                  onPressed: (_checkingStop || _secondsLeft == 0) ? null : _stopAndVerify,
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(_checkingStop ? 'Verifying...' : 'STOP'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
