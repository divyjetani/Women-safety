import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:provider/provider.dart';
import '../app/theme.dart';
import 'package:mobile/app/auth_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    await authProvider.logout();

    if (!context.mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }


  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Settings"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: "Privacy & Security",
            subtitle: "Manage app permissions and privacy settings",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Privacy screen coming soon ✅")),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.language_rounded,
            title: "Language",
            subtitle: "Change app language",
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Language feature coming soon ✅")),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.policy_outlined,
            title: "Terms & Policies",
            subtitle: "Read terms and privacy policy",
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Terms & Policies"),
                  content: const Text(
                    "This is dummy content. Add real terms and privacy policy text here later.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    )
                  ],
                ),
              );
            },
          ),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: "App Version",
            subtitle: "SafeGuard v1.0.0",
            onTap: () {},
          ),

          const SizedBox(height: 18),

          Text(
            "Account",
            style: txt.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),

          _SettingsTile(
            icon: Icons.logout_rounded,
            title: "Logout",
            subtitle: "Sign out from this device",
            iconColor: AppTheme.dangerColor,
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? iconColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (iconColor ?? Theme.of(context).primaryColor).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: iconColor ?? Theme.of(context).primaryColor,
          ),
        ),
        title: Text(title, style: txt.bodyLarge?.copyWith(fontWeight: FontWeight.w900)),
        subtitle: Text(
          subtitle,
          style: txt.bodySmall?.copyWith(
            color: txt.bodySmall?.color?.withValues(alpha: 0.7),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: txt.bodySmall?.color?.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
