// lib/providers/bubble_provider.dart
import 'package:flutter/material.dart';
import 'package:mobile/models/bubble_model.dart';
import 'package:mobile/services/bubble_api.dart';

class BubbleProvider extends ChangeNotifier {
  List<Bubble> _bubbles = [];
  Bubble? _currentBubble;
  bool _isLoading = false;
  String? _error;
  int _userId = 1; // TODO: Get from auth

  // Getters
  List<Bubble> get bubbles => _bubbles;
  Bubble? get currentBubble => _currentBubble;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get userId => _userId;

  // ✅ SET USER ID (from auth service)
  void setUserId(int userId) {
    _userId = userId;
  }

  // ✅ CREATE BUBBLE
  Future<Bubble?> createBubble({
    required String name,
    required int icon,
    required int color,
    required String adminName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bubble = await BubbleAPI.createBubble(
        name: name,
        icon: icon,
        color: color,
        adminId: _userId,
        adminName: adminName,
      );

      _bubbles.add(bubble);
      _currentBubble = bubble;
      notifyListeners();

      return bubble;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ JOIN BUBBLE
  Future<Bubble?> joinBubble({
    required String code,
    required String userName,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bubble = await BubbleAPI.joinBubble(
        code: code,
        userId: _userId,
        userName: userName,
      );

      // Check if already in list
      final index = _bubbles.indexWhere((b) => b.code == bubble.code);
      if (index >= 0) {
        _bubbles[index] = bubble;
      } else {
        _bubbles.add(bubble);
      }

      _currentBubble = bubble;
      notifyListeners();

      return bubble;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ FETCH ALL BUBBLES FOR USER
  Future<void> fetchUserBubbles() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bubbles = await BubbleAPI.getUserBubbles(_userId);
      _bubbles = bubbles;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ GET BUBBLE BY CODE
  Future<Bubble?> getBubble(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final bubble = await BubbleAPI.getBubble(code);
      _currentBubble = bubble;
      notifyListeners();
      return bubble;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ UPDATE CURRENT BUBBLE (from WebSocket updates)
  void updateCurrentBubble(Bubble bubble) {
    _currentBubble = bubble;

    // Update in list
    final index = _bubbles.indexWhere((b) => b.code == bubble.code);
    if (index >= 0) {
      _bubbles[index] = bubble;
    }

    notifyListeners();
  }

  // ✅ SET CURRENT BUBBLE
  void setCurrentBubble(Bubble? bubble) {
    _currentBubble = bubble;
    notifyListeners();
  }

  // ✅ DELETE BUBBLE
  Future<bool> deleteBubble(String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await BubbleAPI.deleteBubble(code: code, adminId: _userId);

      _bubbles.removeWhere((b) => b.code == code);
      if (_currentBubble?.code == code) {
        _currentBubble = null;
      }

      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ CLEAR ERROR
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
