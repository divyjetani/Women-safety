import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

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

  bool _flashOn = true;
  bool _checkingStop = false;
  bool _isStartingPending = false;
  bool _isCompleted = false;
  bool _hasSentAlert = false;
  String _verificationStatus = '';

  int _secondsLeft = _initialCountdownSeconds;
  String? _pendingId;

  Timer? _flashTimer;
  Timer? _countdownTimer;
  Timer? _statusPollTimer;

  Future<bool> _authenticateToCancel() async {
    final isSupported = await _localAuth.isDeviceSupported();
    final canCheckBiometric = await _localAuth.canCheckBiometrics;

    if (!isSupported && !canCheckBiometric) {
      return true;
    }

    return await _localAuth.authenticate(
      localizedReason: 'Authenticate to cancel automatic SOS',
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: false,
        useErrorDialogs: true,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _beginAutomaticPendingFlow();
  }

  Future<void> _beginAutomaticPendingFlow() async {
    if (_isStartingPending) return;
    _isStartingPending = true;

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
        audio10sUrl: '',
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
    } catch (_) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        'Failed to start automatic SOS countdown.',
        type: AppSnackBarType.error,
      );
      Navigator.of(context).pop();
    } finally {
      _isStartingPending = false;
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
      // best-effort polling only
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
      _verificationStatus = 'Capturing selfie for face verification...';
    });

    _flashTimer?.cancel();
    _countdownTimer?.cancel();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final selfieVerified = await _verifyWithSelfie(user.faceImage);

      setState(() {
        _verificationStatus = 'Use fingerprint/device lock to confirm cancel...';
      });
      final authenticated = await _authenticateToCancel();
      if (!mounted) return;

      if (selfieVerified && authenticated) {
        await _cancelPendingSos();
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        AppSnackBar.show(
          context,
          'Face or fingerprint verification failed. SOS will continue.',
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
      reason: 'Cancelled by user after authentication',
    );
  }

  Future<bool> _verifyWithSelfie(String profileImageBase64) async {
    XFile? selfie;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller.initialize();
      await controller.setFlashMode(FlashMode.off);
      selfie = await controller.takePicture();
    } catch (_) {
      return false;
    } finally {
      await controller?.dispose();
    }

    if (selfie == null) return false;

    if (profileImageBase64.trim().isEmpty) {
      return true;
    }

    try {
      final profileBytes = base64Decode(profileImageBase64);
      final selfieBytes = await File(selfie.path).readAsBytes();

      final score = await _histogramSimilarity(profileBytes, selfieBytes);
      return score >= 0.80;
    } catch (_) {
      return false;
    }
  }

  Future<List<double>> _extractHistogram(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: 64, targetHeight: 64);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) return List.filled(16, 0);

    final data = byteData.buffer.asUint8List();
    final bins = List<double>.filled(16, 0);

    for (int i = 0; i + 3 < data.length; i += 4) {
      final r = data[i].toDouble();
      final g = data[i + 1].toDouble();
      final b = data[i + 2].toDouble();
      final lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0;
      final bin = min(15, max(0, (lum * 15).round()));
      bins[bin] += 1;
    }

    final sum = bins.fold<double>(0, (a, v) => a + v);
    if (sum <= 0) return bins;
    return bins.map((v) => v / sum).toList();
  }

  Future<double> _histogramSimilarity(Uint8List aBytes, Uint8List bBytes) async {
    final h1 = await _extractHistogram(aBytes);
    final h2 = await _extractHistogram(bBytes);

    double diff = 0;
    for (int i = 0; i < h1.length; i++) {
      diff += (h1[i] - h2[i]).abs();
    }

    final double normalizedDiff = (diff / 2).clamp(0.0, 1.0).toDouble();
    return 1.0 - normalizedDiff;
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _countdownTimer?.cancel();
    _statusPollTimer?.cancel();
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
