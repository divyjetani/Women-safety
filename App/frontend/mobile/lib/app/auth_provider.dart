// lib/app/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/models.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    _currentUser = await ApiService.getCurrentUser();
    notifyListeners();
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.login(email: email, password: password);

      if (response.success && response.user != null) {
        _currentUser = response.user;
        await ApiService.saveCurrentUser(response.user!);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = 'Login failed. Please check your email and password.';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String phone,
    required String password,
    required String gender,
    required String birthdate,
    required String faceImage,
    required bool aadharVerified,
    required List<String> emergencyContacts,
    String username = '',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.register(
        username: username,
        email: email,
        phone: phone,
        password: password,
        gender: gender,
        birthdate: birthdate,
        faceImage: faceImage,
        aadharVerified: aadharVerified,
        emergencyContacts: emergencyContacts,
      );

      if (response.success && response.user != null) {
        _currentUser = response.user;
        await ApiService.saveCurrentUser(response.user!);
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Registration failed. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<String?> forgotPassword(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.forgotPassword(email);
      _isLoading = false;
      notifyListeners();
      return response.message;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    await ApiService.logout();
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCurrentUser(User user) async {
    _currentUser = user;
    await ApiService.saveCurrentUser(user);
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
