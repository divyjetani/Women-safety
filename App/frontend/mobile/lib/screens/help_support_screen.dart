// App/frontend/mobile/lib/screens/help_support_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../app/auth_provider.dart';
import '../app/theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  bool loading = true;
  List<dynamic> faqs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => loading = true);
    faqs = await ApiService.getFaqs();
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Help & Support")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.support_agent_rounded, color: AppTheme.primaryColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Need help? Check FAQs below or contact support.",
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...faqs.map((f) {
            return ExpansionTile(
              title: Text(f["q"], style: const TextStyle(fontWeight: FontWeight.w800)),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: Text(f["a"]),
                )
              ],
            );
          }).toList(),
        ],
      ),
    );
  }
}
