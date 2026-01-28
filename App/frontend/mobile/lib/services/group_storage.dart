import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bubble_model.dart';

class GroupStorage {
  static const _groupsKey = "groups";
  static const _selectedKey = "selected_group";

  /// Save all groups
  static Future<void> saveGroups(List<SafetyGroup> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final json = groups.map((g) => g.toJson()).toList();
    await prefs.setString(_groupsKey, jsonEncode(json));
  }

  /// Load all groups
  static Future<List<SafetyGroup>> loadGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_groupsKey);
    if (raw == null) return [];

    final list = jsonDecode(raw) as List;
    return list.map((e) => SafetyGroup.fromJson(e)).toList();
  }

  /// Save selected group id
  static Future<void> saveSelectedGroup(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, id);
  }

  /// Load selected group id
  static Future<String?> loadSelectedGroup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey);
  }
}
