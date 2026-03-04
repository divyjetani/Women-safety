// App/frontend/mobile/lib/screens/register_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app/auth_provider.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/error_dialog.dart';
import 'onboarding_guide_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactsController = TextEditingController();

  final ImagePicker _imagePicker = ImagePicker();

  String _gender = 'female';
  DateTime? _birthdate;
  File? _faceImageFile;
  String _faceImageBase64 = '';
  bool _aadharVerified = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactsController.dispose();
    super.dispose();
  }

  Future<void> _pickFaceImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1024,
    );

    if (picked == null) return;

    final file = File(picked.path);
    final bytes = await file.readAsBytes();

    setState(() {
      _faceImageFile = file;
      _faceImageBase64 = base64Encode(bytes);
    });
  }

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 10),
    );

    if (picked != null) {
      setState(() {
        _birthdate = picked;
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_birthdate == null) {
      AppSnackBar.show(context, 'Please select birthdate.', type: AppSnackBarType.warning);
      return;
    }

    if (_faceImageBase64.isEmpty) {
      AppSnackBar.show(context, 'Please upload your face image.', type: AppSnackBarType.warning);
      return;
    }

    if (!_aadharVerified) {
      AppSnackBar.show(context, 'Please complete fake Aadhaar verification.', type: AppSnackBarType.warning);
      return;
    }

    final contacts = _contactsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      gender: _gender,
      birthdate: DateFormat('yyyy-MM-dd').format(_birthdate!),
      faceImage: _faceImageBase64,
      aadharVerified: _aadharVerified,
      emergencyContacts: contacts,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingGuideScreen()),
        (route) => false,
      );
      return;
    }

    ErrorDialog.show(
      context: context,
      title: 'Registration Failed',
      message: authProvider.error ?? 'Please try again.',
      onRetry: _register,
      buttonText: 'Retry',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Create your account', style: text.titleLarge),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter mobile number';
                    }
                    if (value.trim().length < 10) {
                      return 'Enter valid mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Enter email';
                    }
                    if (!value.contains('@')) {
                      return 'Enter valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Enter password';
                    }
                    if (value.length < 6) {
                      return 'Password should be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _gender,
                  decoration: const InputDecoration(
                    labelText: 'Gender',
                    prefixIcon: Icon(Icons.wc_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'male', child: Text('Male')),
                    DropdownMenuItem(value: 'female', child: Text('Female')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _gender = value);
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickBirthdate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Birthdate',
                      prefixIcon: Icon(Icons.cake_outlined),
                    ),
                    child: Text(
                      _birthdate == null
                          ? 'Select birthdate'
                          : DateFormat('dd MMM yyyy').format(_birthdate!),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _contactsController,
                  decoration: const InputDecoration(
                    labelText: 'Emergency Contacts (optional, comma separated)',
                    prefixIcon: Icon(Icons.contacts_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: colors.surfaceContainerHighest,
                      backgroundImage:
                          _faceImageFile != null ? FileImage(_faceImageFile!) : null,
                      child: _faceImageFile == null
                          ? const Icon(Icons.face_retouching_natural)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFaceImage,
                        icon: const Icon(Icons.upload_outlined),
                        label: const Text('Upload Face Image'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fake Aadhaar Verification', style: text.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _aadharVerified
                                  ? 'Verified successfully (demo)'
                                  : 'Not verified',
                            ),
                          ),
                          FilledButton(
                            onPressed: () {
                              setState(() => _aadharVerified = true);
                            },
                            child: const Text('Verify'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _register,
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Register'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Already a user? Login'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
