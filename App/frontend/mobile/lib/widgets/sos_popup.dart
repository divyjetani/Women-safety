// lib/widgets/sos_popup.dart

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../app/auth_provider.dart';
import '../app/theme.dart';
import '../network/bubble_api.dart';
import '../services/firebase_service.dart';
import '../services/sos_notification_service.dart';

class SOSPopup extends StatefulWidget {
  /// ✅ pass incognito from your map screen / state
  final bool incognito;

  /// ✅ group id = bubble
  final String groupId;

  const SOSPopup({
    super.key,
    required this.incognito,
    this.groupId = "bubble",
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

  Future<void> _sendSOS({
    required bool incognito,
    required String groupId,
  }) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _status = 'Sending emergency alert...';
      _success = false;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        throw Exception('User not logged in');
      }

      // ✅ STEP 1: show local notification immediately
      await _showLocalNotification(user.username, 'Sending SOS...');

      if (!mounted) return;
      setState(() {
        _status = 'Sending notifications to emergency contacts...';
      });

      // ✅ STEP 2: emergency contacts notification
      await _sendEmergencyNotifications(user.username, 'Current Location');

      // ✅ STEP 3: If incognito ON => stop group SOS
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

      // ✅ STEP 4: call backend bubble SOS using Dio (FastAPI)
      if (!mounted) return;
      setState(() {
        _status = 'Alerting your Bubble group members...';
      });

      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final battery = await Battery().batteryLevel;

        await BubbleApi.sendSosToBubble(
          userId: user.id.toString(),
          username: user.username,
          lat: position.latitude,
          lng: position.longitude,
          battery: battery,
          groupId: groupId,
        );
      } catch (e) {
        debugPrint("Bubble SOS backend failed: $e");
      }

      if (!mounted) return;
      setState(() {
        _success = true;
        _status = '✅ Emergency alert sent successfully!\n'
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
      if (!mounted) return;
      if (!_success) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendEmergencyNotifications(String userName, String location) async {
    try {
      debugPrint('🔄 Getting emergency contact tokens...');

      final tokens = await _getActualEmergencyContactTokens();

      if (tokens.isEmpty) {
        debugPrint('⚠️ No emergency contacts found, using test mode');

        final currentToken = await FirebaseNotificationService.getFCMToken();
        if (currentToken != null) {
          debugPrint('📱 Using own device for testing');
          await SOSNotificationService.sendEmergencyNotification(
            userName: userName,
            location: location,
            fcmTokens: [currentToken],
          );
        }
        return;
      }

      debugPrint('📱 Sending to ${tokens.length} emergency contact(s)');

      await SOSNotificationService.sendEmergencyNotification(
        userName: userName,
        location: location,
        fcmTokens: tokens,
      );

      debugPrint('✅ Emergency notifications sent');
    } catch (e) {
      debugPrint('❌ Error sending notifications: $e');
    }
  }

  Future<List<String>> _getActualEmergencyContactTokens() async {
    // TODO: connect to your DB (members list -> fcm tokens)
    return [];
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

      // ✅ Android channel
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
            // ✅ FIXED: wrap inside function
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
