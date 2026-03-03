import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

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
  static const int _initialCountdownSeconds = 8;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _flashOn = true;
  bool _checkingStop = false;
  bool _sosTriggered = false;
  int _secondsLeft = _initialCountdownSeconds;
  Timer? _flashTimer;
  Timer? _countdownTimer;

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
    _startFlashCountdown();
  }

  void _startFlashCountdown() {
    _flashTimer?.cancel();
    _countdownTimer?.cancel();

    HapticFeedback.vibrate();

    _flashTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _flashOn = !_flashOn);
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_checkingStop || _sosTriggered) return;

      if (_secondsLeft > 1) {
        setState(() => _secondsLeft -= 1);
        HapticFeedback.heavyImpact();
        return;
      }

      if (_secondsLeft <= 1) {
        if (!_sosTriggered) {
          setState(() => _secondsLeft = 0);
        }
        timer.cancel();
        await _triggerSosNow();
      }
    });
  }

  Future<void> _triggerSosNow() async {
    if (_sosTriggered) return;
    _sosTriggered = true;

    _flashTimer?.cancel();
    _countdownTimer?.cancel();
    if (!mounted) return;

    try {
      await widget.onConfirmedDanger();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to open SOS flow. Retrying is recommended.')),
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _stopAndVerify() async {
    if (_checkingStop || _sosTriggered) return;
    setState(() => _checkingStop = true);

    _flashTimer?.cancel();
    _countdownTimer?.cancel();

    try {
      final faceVerified = await _mockFaceVerification();
      if (faceVerified) {
        if (!mounted) return;
        Navigator.of(context).pop();
        return;
      }

      final authenticated = await _authenticateToCancel();

      if (!mounted) return;

      if (authenticated) {
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification failed. SOS will continue.')),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Authentication error. SOS countdown resumed.')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _checkingStop = false);
      if (!_sosTriggered && _secondsLeft > 0) {
        _startFlashCountdown();
      }
    }
  }

  Future<bool> _mockFaceVerification() async {
    await Future.delayed(const Duration(milliseconds: 900));
    return false;
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _countdownTimer?.cancel();
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
                  'Tap STOP and verify face or device lock to cancel.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 26),
                ElevatedButton.icon(
                  onPressed: _checkingStop ? null : _stopAndVerify,
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
