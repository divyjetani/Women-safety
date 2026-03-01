import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/auth_provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/app_snackbar.dart';
import 'main_screen.dart';

class OnboardingGuideScreen extends StatefulWidget {
  const OnboardingGuideScreen({super.key});

  @override
  State<OnboardingGuideScreen> createState() => _OnboardingGuideScreenState();
}

class _OnboardingGuideScreenState extends State<OnboardingGuideScreen> {
  final PageController _pageController = PageController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();

  int _page = 0;
  bool _saving = false;
  bool _aadharVerified = false;
  bool _contactAdded = false;

  User? get _user => context.read<AuthProvider>().currentUser;

  @override
  void initState() {
    super.initState();
    final user = _user;
    _aadharVerified = user?.aadharVerified ?? false;
    _contactAdded = (user?.emergencyContacts ?? []).isNotEmpty;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _verifyAadharOneClick() async {
    final user = _user;
    if (user == null) return;

    setState(() => _saving = true);
    try {
      await ApiService.updateProfile(
        userId: user.id,
        aadharVerified: true,
      );

      final updated = User(
        id: user.id,
        username: user.username,
        email: user.email,
        phone: user.phone,
        emergencyContacts: user.emergencyContacts,
        gender: user.gender,
        birthdate: user.birthdate,
        faceImage: user.faceImage,
        aadharVerified: true,
        isPremium: user.isPremium,
      );

      await context.read<AuthProvider>().setCurrentUser(updated);
      if (!mounted) return;
      setState(() => _aadharVerified = true);
      AppSnackBar.show(context, 'Aadhaar verified (demo) ✅', type: AppSnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        e.toString().replaceAll('Exception:', '').trim(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _addEmergencyContact() async {
    final user = _user;
    if (user == null) return;

    final name = _contactNameController.text.trim();
    final phone = _contactPhoneController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      AppSnackBar.show(context, 'Enter contact name and phone', type: AppSnackBarType.warning);
      return;
    }

    setState(() => _saving = true);
    try {
      await ApiService.addEmergencyContact(
        userId: user.id,
        name: name,
        phone: phone,
        isPrimary: true,
      );

      final updatedContacts = [...user.emergencyContacts, phone];
      final updated = User(
        id: user.id,
        username: user.username,
        email: user.email,
        phone: user.phone,
        emergencyContacts: updatedContacts,
        gender: user.gender,
        birthdate: user.birthdate,
        faceImage: user.faceImage,
        aadharVerified: user.aadharVerified,
        isPremium: user.isPremium,
      );
      await context.read<AuthProvider>().setCurrentUser(updated);

      if (!mounted) return;
      setState(() {
        _contactAdded = true;
        _contactNameController.clear();
        _contactPhoneController.clear();
      });

      AppSnackBar.show(context, 'Emergency contact added ✅', type: AppSnackBarType.success);
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.show(
        context,
        e.toString().replaceAll('Exception:', '').trim(),
        type: AppSnackBarType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _finish() async {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
      (route) => false,
    );
  }

  void _next() {
    if (_page < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Start Guide'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _page = index),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome to SheSafe', style: titleStyle),
                        const SizedBox(height: 12),
                        const Text(
                          'Your Bubble is your trusted safety circle. Create a bubble with family/friends or join using a 6-digit code. Members can share live safety context and respond quickly in emergencies.',
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bubble Flow', style: TextStyle(fontWeight: FontWeight.w700)),
                              SizedBox(height: 8),
                              Text('1) Create Bubble → get code'),
                              Text('2) Share code with trusted people'),
                              Text('3) Members join and stay connected'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Complete Security Setup', style: titleStyle),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              _aadharVerified ? Icons.verified : Icons.error_outline,
                              color: _aadharVerified ? Colors.green : Colors.orange,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _aadharVerified ? 'Aadhaar Verified' : 'Aadhaar Not Verified',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: (_aadharVerified || _saving) ? null : _verifyAadharOneClick,
                            icon: const Icon(Icons.verified_user_outlined),
                            label: Text(_aadharVerified ? 'Verified' : 'Verify Aadhaar (1-click)'),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _contactNameController,
                          decoration: const InputDecoration(
                            labelText: 'Emergency Contact Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _contactPhoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Emergency Contact Phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _addEmergencyContact,
                            icon: const Icon(Icons.add_ic_call_outlined),
                            label: Text(_contactAdded ? 'Contact Added' : 'Add Emergency Contact'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('You are ready', style: titleStyle),
                        const SizedBox(height: 12),
                        const Text(
                          'Use SOS for emergencies, keep your profile updated, and manage trusted contacts from Profile any time. You can edit mobile, email, name, and profile photo later.',
                        ),
                        const SizedBox(height: 20),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          ),
                          child: const Text('Tip: Keep at least one primary emergency contact for fastest SOS response.'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(value: (_page + 1) / 3),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saving ? null : _next,
                    child: Text(_page == 2 ? 'Start App' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
