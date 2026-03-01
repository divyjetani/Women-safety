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
  List<Map<String, dynamic>> emergencyContacts = [];
  String? loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      loadError = null;
    });

    try {
      if (widget.action == "emergency_contacts") {
        final contacts = await ApiService.getEmergencyContacts(widget.userId);
        emergencyContacts = contacts
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        data = await ApiService.getQuickActionDetails(
          userId: widget.userId,
          action: widget.action,
        );
      }
    } catch (e) {
      loadError = e.toString().replaceAll("Exception:", "").trim();
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.action.replaceAll("_", " ").toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      loadError!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : widget.action == "emergency_contacts"
                  ? _buildEmergencyContacts()
                  : Padding(
                      padding: const EdgeInsets.all(18),
                      child: Text(
                        data.toString(),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
    );
  }

  Widget _buildEmergencyContacts() {
    if (emergencyContacts.isEmpty) {
      return const Center(child: Text("No emergency contacts found"));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: emergencyContacts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final c = emergencyContacts[i];
        final name = c["name"]?.toString() ?? "Unknown";
        final phone = c["phone"]?.toString() ?? "N/A";
        final isPrimary = c["isPrimary"] == true;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              CircleAvatar(
                child: Text(name.isNotEmpty ? name[0].toUpperCase() : "?"),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (isPrimary)
                          const Icon(Icons.star_rounded, size: 18, color: Colors.amber),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(phone),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
