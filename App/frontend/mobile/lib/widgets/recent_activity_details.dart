import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/models.dart';

class RecentActivityDetailsScreen extends StatefulWidget {
  final int userId;
  const RecentActivityDetailsScreen({super.key, required this.userId});

  @override
  State<RecentActivityDetailsScreen> createState() => _RecentActivityDetailsScreenState();
}

class _RecentActivityDetailsScreenState extends State<RecentActivityDetailsScreen> {
  bool loading = true;
  List<RecentActivity> list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    list = await ApiService.getRecentActivity(widget.userId);
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recent Activity")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final a = list[i];
          return ListTile(
            title: Text(a.type),
            subtitle: Text(a.location),
            trailing: Text(a.time),
          );
        },
      ),
    );
  }
}
