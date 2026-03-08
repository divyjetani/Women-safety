// App/frontend/mobile/lib/screens/edit_profile_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app/auth_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/profile_image_cache_service.dart';
import '../widgets/app_snackbar.dart';

class EditProfileScreen extends StatefulWidget {
  final int userId;
  final String initialName;
  final String initialEmail;
  final String initialPhone;
  final String initialFaceImage;

  const EditProfileScreen({
    super.key,
    required this.userId,
    required this.initialName,
    required this.initialEmail,
    required this.initialPhone,
    required this.initialFaceImage,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController nameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController phoneCtrl;

  final ImagePicker _picker = ImagePicker();
  String _faceImageValue = '';
  File? _pickedImage;
  bool _removedPhoto = false;
  String? _localFaceImagePath;
  bool saving = false;

  String _normalizeBase64Image(String value) {
    final raw = value.trim();
    if (raw.startsWith('data:image/') && raw.contains(',')) {
      return raw.split(',')[1].trim();
    }
    return raw;
  }

  String _normalizeImageSource(String value) {
    return value.trim().replaceAll('\\', '/');
  }

  Widget _buildRemoteOrBase64Avatar() {
    final normalized = _normalizeImageSource(_faceImageValue);
    if (normalized.isEmpty) {
      return const CircleAvatar(
        radius: 42,
        child: Icon(Icons.person_rounded, size: 36),
      );
    }

    try {
      if (normalized.startsWith('/profile_pics/') ||
          normalized.startsWith('profile_pics/') ||
          normalized.startsWith('http://') ||
          normalized.startsWith('https://')) {
        final resolvedUrl = normalized.startsWith('http')
            ? normalized
            : '${ApiService.baseUrl}${normalized.startsWith('/') ? '' : '/'}$normalized';
        return ClipOval(
          child: Image.network(
            resolvedUrl,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const CircleAvatar(
              radius: 42,
              child: Icon(Icons.person_rounded, size: 36),
            ),
          ),
        );
      }

      return ClipOval(
        child: Image.memory(
          base64Decode(_normalizeBase64Image(normalized)),
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const CircleAvatar(
            radius: 42,
            child: Icon(Icons.person_rounded, size: 36),
          ),
        ),
      );
    } catch (_) {
      return const CircleAvatar(
        radius: 42,
        child: Icon(Icons.person_rounded, size: 36),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.initialName);
    emailCtrl = TextEditingController(text: widget.initialEmail);
    phoneCtrl = TextEditingController(text: widget.initialPhone);
    _faceImageValue = widget.initialFaceImage;
    _initLocalImage();
  }

  Future<void> _initLocalImage() async {
    final local = await ProfileImageCacheService.getLocalPath(widget.userId);
    if (!mounted) return;
    setState(() {
      _localFaceImagePath = local;
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );

    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();

    setState(() {
      _pickedImage = file;
      _faceImageValue = base64Encode(bytes);
      _removedPhoto = false;
    });
  }

  void _removeProfileImage() {
    setState(() {
      _pickedImage = null;
      _faceImageValue = '';
      _removedPhoto = true;
      _localFaceImagePath = null;
    });
  }

  Future<void> _save() async {
    if (nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
      AppSnackBar.show(context, 'Please fill all required fields', type: AppSnackBarType.warning);
      return;
    }

    try {
      setState(() => saving = true);

      await ApiService.updateProfile(
        userId: widget.userId,
        name: nameCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        faceImage: _faceImageValue,
      );

      final profileJson = await ApiService.getProfile(widget.userId);
      final storedFaceImage = (profileJson['face_image'] ?? '').toString();

      final localPath = await ProfileImageCacheService.syncFromSource(
        userId: widget.userId,
        source: storedFaceImage,
      );
      if (_removedPhoto) {
        await ProfileImageCacheService.clearLocal(widget.userId);
      }

      final authProvider = context.read<AuthProvider>();
      final current = authProvider.currentUser;
      if (current != null) {
        final updatedUser = User(
          id: current.id,
          username: nameCtrl.text.trim(),
          email: emailCtrl.text.trim(),
          phone: phoneCtrl.text.trim(),
          emergencyContacts: current.emergencyContacts,
          gender: current.gender,
          birthdate: current.birthdate,
          faceImage: storedFaceImage,
          aadharVerified: current.aadharVerified,
          isPremium: current.isPremium,
        );
        await authProvider.setCurrentUser(updatedUser);
      }

      if (mounted) {
        setState(() {
          _localFaceImagePath = localPath;
        });
      }

      if (!mounted) return;
      setState(() => saving = false);

      AppSnackBar.show(context, 'Profile updated ✅', type: AppSnackBarType.success);

      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        AppSnackBar.show(
          context,
          e.toString().replaceAll('Exception:', '').trim(),
          type: AppSnackBarType.error,
        );
      }
    }
  }

  Widget _buildAvatarPreview() {
    if (_pickedImage != null) {
      return ClipOval(
        child: Image.file(
          _pickedImage!,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const CircleAvatar(
            radius: 42,
            child: Icon(Icons.person_rounded, size: 36),
          ),
        ),
      );
    }

    if (_localFaceImagePath != null && _localFaceImagePath!.trim().isNotEmpty) {
      final local = File(_localFaceImagePath!);
      if (local.existsSync()) {
        return ClipOval(
          child: Image.file(
            local,
            width: 84,
            height: 84,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _localFaceImagePath = null;
                });
              });
              return _buildRemoteOrBase64Avatar();
            },
          ),
        );
      }
    }

    return _buildRemoteOrBase64Avatar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: _buildAvatarPreview()),
              const SizedBox(height: 10),
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: saving ? null : _pickProfileImage,
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Change Profile Photo'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: saving ? null : _removeProfileImage,
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: saving ? null : _save,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
