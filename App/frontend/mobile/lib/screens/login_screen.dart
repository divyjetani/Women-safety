// App/frontend/mobile/lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/auth_provider.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/error_dialog.dart';
import 'main_screen.dart';
import 'register_screen.dart';
import '../conn_url.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _launchEmergencyCall() async {
    const url = 'tel:112';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (mounted) {
      AppSnackBar.show(context, 'Could not launch emergency call', type: AppSnackBarType.error);
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('ip_address');
    if (ip == null || ip.isEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const IpPromptScreen()),
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    } else {
      ErrorDialog.show(
        context: context,
        title: 'Login Failed',
        message: authProvider.error ?? 'Invalid email/password or network error',
        onRetry: _login,
        buttonText: 'Try Again',
      );
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      AppSnackBar.show(context, 'Enter your email first.', type: AppSnackBarType.warning);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final message = await authProvider.forgotPassword(email);

    if (!mounted) return;
    if (message != null) {
      AppSnackBar.show(context, message, type: AppSnackBarType.success);
      await _showResetPasswordDialog(email);
      return;
    }

    ErrorDialog.show(
      context: context,
      title: 'Forgot Password Failed',
      message: authProvider.error ?? 'Please try again.',
      onRetry: _forgotPassword,
      buttonText: 'Retry',
    );
  }

  Future<void> _showResetPasswordDialog(String email) async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final authProvider = ctx.watch<AuthProvider>();

            return AlertDialog(
              title: const Text('Reset Password'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set a new password for $email',
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: authProvider.isLoading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: authProvider.isLoading
                      ? null
                      : () async {
                          final auth = context.read<AuthProvider>();
                          final newPassword = newPasswordController.text;
                          final confirmPassword = confirmPasswordController.text;

                          if (newPassword.isEmpty || confirmPassword.isEmpty) {
                            AppSnackBar.show(ctx, 'Please fill both password fields.', type: AppSnackBarType.warning);
                            return;
                          }

                          if (newPassword.length < 6) {
                            AppSnackBar.show(ctx, 'Password must be at least 6 characters.', type: AppSnackBarType.warning);
                            return;
                          }

                          if (newPassword != confirmPassword) {
                            AppSnackBar.show(ctx, 'Passwords do not match.', type: AppSnackBarType.warning);
                            return;
                          }

                          final success = await auth.resetPasswordAndLogin(
                                email: email,
                                newPassword: newPassword,
                                confirmPassword: confirmPassword,
                              );
                          if (!mounted) return;

                          if (success) {
                            final rootNavigator = Navigator.of(context, rootNavigator: true);
                            if (rootNavigator.canPop()) {
                              rootNavigator.pop();
                            }
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const MainScreen()),
                              (route) => false,
                            );
                            return;
                          }

                          AppSnackBar.show(
                            context,
                            auth.error ?? 'Failed to reset password.',
                            type: AppSnackBarType.error,
                          );
                        },
                  child: authProvider.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    );

    newPasswordController.dispose();
    confirmPasswordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),

                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colors.primary,
                              colors.primary.withValues(alpha: 0.7),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.3),
                              blurRadius: 20,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/logo2.png',
                          width: 100,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('She Safe', style: text.displayMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Your Personal Safety Companion',
                        style: text.bodyMedium,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 60),

                Text('Login', style: text.titleLarge),
                const SizedBox(height: 8),
                Text(
                  'Enter your email and password to continue',
                  style: text.bodyMedium,
                ),

                const SizedBox(height: 24),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: text.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'you@example.com',
                            hintStyle: text.bodyMedium,
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.email_outlined, color: colors.primary),
                            contentPadding: const EdgeInsets.all(20),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          style: text.bodyLarge,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle: text.bodyMedium,
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
                            contentPadding: const EdgeInsets.all(20),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: authProvider.isLoading ? null : _forgotPassword,
                    child: const Text('Forgot Password?'),
                  ),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _login,
                    child: authProvider.isLoading
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.login),
                        SizedBox(width: 8),
                        Text(
                          'Login',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                OutlinedButton(
                  onPressed: _launchEmergencyCall,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.error,
                    side: BorderSide(color: colors.error),
                    backgroundColor: colors.surface,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.emergency),
                      SizedBox(width: 8),
                      Text(
                        'Emergency Call (112)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New here?',
                        style: text.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen()),
                            );
                          },
                          child: const Text('Create Register Account'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const IpPromptScreen(),
                        ),
                      );
                    },
                    child: const Text('Server IP'),
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

