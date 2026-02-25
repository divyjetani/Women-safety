import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BackgroundLocationService {
  static const _channel = MethodChannel('com.example.mobile/bg_location');
  
  /// Start background location sharing when app is closed
  static Future<void> startBackgroundLocationSharing({
    required String bubbleCode,
    required int userId,
    required bool incognito,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save bubble info so background service can access it
      await prefs.setString('selected_bubble_code', bubbleCode);
      await prefs.setInt('user_id', userId);
      await prefs.setBool('incognito_mode', incognito);
      
      // Start the Android service
      final result = await _channel.invokeMethod<bool>(
        'startLocationSharing',
        {
          'bubbleCode': bubbleCode,
          'userId': userId,
          'incognito': incognito,
        },
      );
      
      print('✅ Background location sharing started: $result');
    } catch (e) {
      print('❌ Error starting background location sharing: $e');
      rethrow;
    }
  }
  
  /// Stop background location sharing
  static Future<void> stopBackgroundLocationSharing() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopLocationSharing');
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('incognito_mode', false);
      
      print('✅ Background location sharing stopped: $result');
    } catch (e) {
      print('❌ Error stopping background location sharing: $e');
      rethrow;
    }
  }
  
  /// Update incognito mode without restarting the service
  static Future<void> setIncognitoMode(bool incognito) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('incognito_mode', incognito);
      
      // Notify the service of the change
      await _channel.invokeMethod<bool>(
        'setIncognito',
        {'incognito': incognito},
      );
      
      print('✅ Incognito mode set to: $incognito');
    } catch (e) {
      print('❌ Error setting incognito mode: $e');
    }
  }
}
