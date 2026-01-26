// services/sos_notification_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';

class SOSNotificationService {
  // Get these from your Firebase project
  static const String _projectId = 'women-safety-a7bfe'; // Found in Firebase Project Settings
  static const String _serviceAccountEmail = 'firebase-adminsdk-fbsvc@women-safety-a7bfe.iam.gserviceaccount.com';

  // FCM v1 endpoint
  static String get _fcmV1Url => 'https://fcm.googleapis.com/v1/projects/$_projectId/messages:send';

  // You'll need to implement token generation (usually done on backend)
  static Future<String?> _getAccessToken() async {
    // IMPORTANT: Generating access tokens should be done on a BACKEND server
    // For testing, you can generate a token manually:

    // Method 1: Generate manually (for testing):
    // 1. Run in terminal:
    //    gcloud auth print-access-token
    // 2. Use that token temporarily

    // Method 2: Use Firebase Admin SDK on your backend
    // return await YourBackendService.getFCMAccessToken();

    // For now, return null - you need to implement proper token generation
    return null;
  }

  static Future<void> sendEmergencyNotification({
    required String userName,
    required String location,
    required List<String> fcmTokens,
  }) async {
    try {
      // Get access token
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        print('❌ No access token available');
        return;
      }

      // Filter out test tokens
      final validTokens = fcmTokens.where((token) =>
      token.isNotEmpty && !token.startsWith('test_token_')).toList();

      if (validTokens.isEmpty) {
        print('⚠️ No valid FCM tokens provided');
        return;
      }

      // Send to each emergency contact
      for (final token in validTokens) {
        await _sendToFCMV1(token, userName, location, accessToken);
      }

      print('✅ Emergency notifications sent successfully');
    } catch (e) {
      print('❌ Failed to send notifications: $e');
    }
  }

  static Future<void> _sendToFCMV1(
      String token,
      String userName,
      String location,
      String accessToken
      ) async {
    try {
      print('📤 Sending via FCM v1 to token: ${token.substring(0, 20)}...');

      final response = await http.post(
        Uri.parse(_fcmV1Url),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $accessToken',
        },
        body: jsonEncode({
          'message': {
            'token': token.trim(),
            'notification': {
              'title': '🚨 EMERGENCY ALERT - $userName',
              'body': 'Needs help at $location. SOS activated!',
            },
            'data': {
              'type': 'emergency',
              'user': userName,
              'location': location,
              'timestamp': DateTime.now().toIso8601String(),
            },
            'android': {
              'priority': 'HIGH',
              'notification': {
                'channel_id': 'high_importance_channel',
                'sound': 'default',
                'priority': 'HIGH',
                'visibility': 'PUBLIC',
              },
            },
            'apns': {
              'payload': {
                'aps': {
                  'alert': {
                    'title': '🚨 EMERGENCY ALERT - $userName',
                    'body': 'Needs help at $location. SOS activated!',
                  },
                  'sound': 'default',
                  'badge': 1,
                },
              },
              'headers': {
                'apns-priority': '10', // High priority for iOS
              },
            },
          }
        }),
      );

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ FCM v1 notification sent successfully');
      } else {
        print('❌ FCM v1 Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('❌ Exception sending FCM v1: $e');
    }
  }
}