// App/frontend/mobile/lib/app/auth_provider.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/profile_image_cache_service.dart';
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
        await ProfileImageCacheService.syncFromSource(
          userId: response.user!.id,
          source: response.user!.faceImage,
        );
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
        await ProfileImageCacheService.syncFromSource(
          userId: response.user!.id,
          source: response.user!.faceImage,
        );
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

  Future<bool> resetPasswordAndLogin({
    required String email,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resetResponse = await ApiService.resetPassword(
        email: email,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!resetResponse.success) {
        _error = resetResponse.message.isNotEmpty
            ? resetResponse.message
            : 'Failed to reset password.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final loginResponse = await ApiService.login(
        email: email,
        password: newPassword,
      );

      if (loginResponse.success && loginResponse.user != null) {
        _currentUser = loginResponse.user;
        await ApiService.saveCurrentUser(loginResponse.user!);
        await ProfileImageCacheService.syncFromSource(
          userId: loginResponse.user!.id,
          source: loginResponse.user!.faceImage,
        );
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _error = 'Password reset succeeded, but auto login failed.';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString().replaceAll('Exception:', '').trim();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final previous = _currentUser;
    await ApiService.logout();
    if (previous != null) {
      await ProfileImageCacheService.clearLocal(previous.id);
    }
    _currentUser = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setCurrentUser(User user) async {
    _currentUser = user;
    await ApiService.saveCurrentUser(user);
    await ProfileImageCacheService.syncFromSource(
      userId: user.id,
      source: user.faceImage,
    );
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
