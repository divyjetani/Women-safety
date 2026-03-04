// App/frontend/mobile/lib/services/group_storage.dart
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bubble_model.dart';

class GroupStorage {
  static const _groupsKey = "groups";
  static const _selectedKey = "selected_group";

  static Future<void> saveGroups(List<SafetyGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final json = groups.map((g) => g.toJson()).toList();
    await prefs.setString(_groupsKey, jsonEncode(json));
  }

  static Future<List<SafetyGroup>> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_groupsKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List;
    return list.map((e) => SafetyGroup.fromJson(e)).toList();
  }

  static Future<void> saveSelectedGroup(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, id);
  }

  static Future<String?> loadSelectedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey);
  }
}
