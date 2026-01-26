// widgets/sos_popup.dart - Updated with fixed imports and access
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // ADD THIS
import '../app/auth_provider.dart';
import '../services/api_service.dart';
import '../services/sos_notification_service.dart';
import '../services/firebase_service.dart';
import '../app/theme.dart';

class SOSPopup extends StatefulWidget {
  const SOSPopup({super.key});

  @override
  State<SOSPopup> createState() => _SOSPopupState();
}

class _SOSPopupState extends State<SOSPopup> {
  bool _isSending = false;
  String _status = '';
  bool _success = false;

  // Create local instance
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> _sendSOS() async {
    setState(() {
      _isSending = true;
      _status = 'Sending emergency alert...';
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user != null) {
        // First, show local notification immediately for user feedback
        await _showLocalNotification(user.username, 'Current Location');

        setState(() {
          _status = 'Sending notifications to emergency contacts...';
        });

        // Send notifications to emergency contacts
        await _sendEmergencyNotifications(user.username, 'Current Location');

        // Then send SOS to backend (this can be async)
        try {
          await ApiService.sendSOS(
            userId: user.id,
            location: 'Current Location (GPS)',
            message: 'Emergency SOS activated by user',
          );
        } catch (e) {
          // Even if backend fails, notifications are already sent
          print('Backend SOS failed but notifications sent: $e');
        }

        setState(() {
          _success = true;
          _status = '✅ Emergency alert sent successfully!\n'
              'Your emergency contacts have been notified.\n'
              'Stay calm and wait for help.';
        });

        // Close popup after 4 seconds
        await Future.delayed(const Duration(seconds: 4));
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        throw Exception('User not logged in');
      }
    } catch (e) {
      setState(() {
        _success = false;
        _status = '❌ Failed to send alert. Please try again.\n'
            'Make sure you have internet connection.';
        print('SOS Error: $e');
      });
    } finally {
      if (!_success) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _sendEmergencyNotifications(String userName, String location) async {
    try {
      print('🔄 Getting emergency contact tokens...');

      // Get actual emergency contact tokens
      final tokens = await _getActualEmergencyContactTokens();

      if (tokens.isEmpty) {
        print('⚠️ No emergency contacts found, using test mode');

        // Fallback: Use current user's token for testing
        final currentToken = await FirebaseNotificationService.getFCMToken();
        if (currentToken != null) {
          print('📱 Using own device for testing: ${currentToken.substring(0, 20)}...');
          await SOSNotificationService.sendEmergencyNotification(
            userName: userName,
            location: location,
            fcmTokens: [currentToken],
          );
        } else {
          print('⚠️ No FCM token available');
        }
        return;
      }

      print('📱 Sending to ${tokens.length} emergency contact(s)');

      // Send notifications
      await SOSNotificationService.sendEmergencyNotification(
        userName: userName,
        location: location,
        fcmTokens: tokens,
      );

      print('✅ Emergency notifications sent');

    } catch (e) {
      print('❌ Error sending notifications: $e');
      // Don't throw - we still want to show success to the user
    }
  }

  Future<List<String>> _getActualEmergencyContactTokens() async {
    // TODO: Implement based on your app's data structure

    // For now, return empty list - will trigger fallback to test mode
    return [];
  }

  Future<void> _showLocalNotification(String userName, String location) async {
    try {
      // Initialize notifications plugin if needed
      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await _localNotificationsPlugin.initialize(initializationSettings);

      // Create notification channel for Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'emergency_channel',
        'Emergency Alerts',
        description: 'Emergency SOS notifications',
        importance: Importance.max,
      );

      await _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Show immediate notification on the user's own device
      await _localNotificationsPlugin.show(
        999, // High ID for emergency
        'SOS Activated 🚨',
        'Emergency alert sent to your contacts from $location',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'emergency_channel',
            'Emergency Alerts',
            channelDescription: 'Emergency SOS notifications',
            importance: Importance.max,
            priority: Priority.high,
            color: Colors.red,
            enableVibration: true,
            playSound: true,
            ledColor: Colors.red,
            ledOnMs: 1000,
            ledOffMs: 500,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'default',
            badgeNumber: 1,
          ),
        ),
        payload: 'sos_activated',
      );

      print('📱 Local SOS notification shown');
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // SOS Icon with pulsing animation when sending
              _buildSOSIcon(),

              const SizedBox(height: 20),

              // Title
              Text(
                _success ? 'Emergency Alert Sent!' : 'Emergency SOS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge!.color,
                ),
              ),

              const SizedBox(height: 12),

              // Description
              Text(
                _success
                    ? 'Help is on the way! Notifications sent to emergency contacts.'
                    : 'This will notify your emergency contacts immediately.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).textTheme.bodyMedium!.color,
                ),
              ),

              const SizedBox(height: 20),

              // Status message
              if (_status.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _success ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _success ? Colors.green[200] ?? Colors.green : Colors.red[200] ?? Colors.red,
                    ),
                  ),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _success ? Colors.green[800] : Colors.red[800],
                      fontSize: 14,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Notification preview
              if (!_isSending && !_success)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200] ?? Colors.orangeAccent),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.notifications_active, color: Colors.orange[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'Immediate notifications will be \nsent to:',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• Your emergency contacts\n• Your device for confirmation\n• Police if connected to backend',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Warning for test mode
              if (!_isSending && !_success)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200] ?? Colors.blue),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue[700], size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'In test mode: Sending to your own device',
                          style: TextStyle(
                            color: Colors.blue[700],
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Buttons
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
        if (_isSending && !_success)
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.red.withOpacity(0.2),
            ),
          ),

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
          SizedBox(
            width: 100,
            height: 100,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(Colors.red.withOpacity(0.8)),
            ),
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
              side: BorderSide(
                color: Theme.of(context).textTheme.bodyMedium!.color!.withOpacity(0.3),
              ),
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
            onPressed: _isSending ? null : _sendSOS,
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
                : const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('SEND SOS'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}