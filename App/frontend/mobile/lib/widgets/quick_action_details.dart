import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class QuickActionDetailsScreen extends StatefulWidget {
  final int userId;
  final String action;
  const QuickActionDetailsScreen({super.key, required this.userId, required this.action});

  @override
  State<QuickActionDetailsScreen> createState() => _QuickActionDetailsScreenState();
}

class _QuickActionDetailsScreenState extends State<QuickActionDetailsScreen> {
  bool loading = true;
  Map<String, dynamic> data = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    data = await ApiService.getQuickActionDetails(userId: widget.userId, action: widget.action);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.action.replaceAll("_", " ").toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          data.toString(),
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }
}
