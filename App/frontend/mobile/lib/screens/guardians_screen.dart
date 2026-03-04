// App/frontend/mobile/lib/screens/guardians_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../app/auth_provider.dart';
import '../app/theme.dart';

class GuardiansScreen extends StatefulWidget {
  const GuardiansScreen({super.key});

  @override
  State<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends State<GuardiansScreen> {
  bool loading = true;
  List<dynamic> guardians = [];

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
    guardians = await ApiService.getGuardians(userId: user.id);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Guardians")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : guardians.isEmpty
          ? const Center(child: Text("No guardians found"))
          : ListView.builder(
        itemCount: guardians.length,
        itemBuilder: (context, i) {
          final g = guardians[i];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
              child: Icon(Icons.person, color: AppTheme.primaryColor),
            ),
            title: Text(g["name"]),
            subtitle: Text(g["phone"]),
            trailing: Text(g["status"]),
          );
        },
      ),
    );
  }
}
