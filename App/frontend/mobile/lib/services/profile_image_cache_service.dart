// App/frontend/mobile/lib/services/profile_image_cache_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/conn_url.dart';

class ProfileImageCacheService {
  static String _prefsKey(int userId) => 'profile_image_local_$userId';

  static bool _looksLikeBase64(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return false;
    if (raw.startsWith('/profile_pics/') || raw.startsWith('http://') || raw.startsWith('https://')) {
      return false;
    }
    if (raw.startsWith('data:image/')) return true;
    return RegExp(r'^[A-Za-z0-9+/=\r\n]+$').hasMatch(raw);
  }

  static String _normalizeBase64(String value) {
    final raw = value.trim();
    if (raw.startsWith('data:image/') && raw.contains(',')) {
      return raw.split(',')[1].trim();
    }
    return raw;
  }

  static String _toAbsoluteUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) return trimmed;
    final base = ApiUrls.baseUrl.replaceAll(RegExp(r'/$'), '');
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$base$path';
  }

  static Future<File> _targetFile(int userId) async {
    final dir = await getApplicationDocumentsDirectory();
    final profileDir = Directory('${dir.path}/profile_images');
    if (!await profileDir.exists()) {
      await profileDir.create(recursive: true);
    }
    return File('${profileDir.path}/user_${userId}_profile.jpg');
  }

  static Future<void> _storeLocalPath(int userId, String? path) async {
    final prefs = await SharedPreferences.getInstance();
    if (path == null || path.trim().isEmpty) {
      await prefs.remove(_prefsKey(userId));
      return;
    }
    await prefs.setString(_prefsKey(userId), path);
  }

  static Future<String?> getLocalPath(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_prefsKey(userId));
    if (value == null || value.trim().isEmpty) return null;

    final file = File(value);
    if (!await file.exists()) {
      await prefs.remove(_prefsKey(userId));
      return null;
    }
    return value;
  }

  static Future<void> clearLocal(int userId) async {
    final existing = await getLocalPath(userId);
    if (existing != null) {
      try {
        await File(existing).delete();
      } catch (_) {}
    }
    await _storeLocalPath(userId, null);
  }

  static Future<String?> syncFromSource({
    required int userId,
    required String source,
  }) async {
    final normalized = source.trim();

    if (normalized.isEmpty) {
      await clearLocal(userId);
      return null;
    }

    try {
      final target = await _targetFile(userId);

      if (_looksLikeBase64(normalized)) {
        final bytes = base64Decode(_normalizeBase64(normalized));
        await target.writeAsBytes(bytes, flush: true);
        await _storeLocalPath(userId, target.path);
        return target.path;
      }

      final url = _toAbsoluteUrl(normalized);
      final response = await http.get(Uri.parse(url));
      if (response.statusCode >= 200 && response.statusCode < 300 && response.bodyBytes.isNotEmpty) {
        await target.writeAsBytes(response.bodyBytes, flush: true);
        await _storeLocalPath(userId, target.path);
        return target.path;
      }
    } catch (_) {
    }

    return await getLocalPath(userId);
  }
}
