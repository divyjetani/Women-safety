import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../app/auth_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool loading = true;
  List<dynamic> history = [];
  bool _resolving = false;

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
    try {
      history = await ApiService.getHistory(userId: user.id);
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _resolveSos(String eventId) async {
    if (_resolving) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;
    if (user == null) return;

    setState(() => _resolving = true);
    try {
      await ApiService.resolveSosEvent(
        userId: user.id,
        eventId: eventId,
        reason: 'Marked resolved from history screen',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to resolve SOS: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _resolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : history.isEmpty
          ? const Center(child: Text("No history available"))
          : ListView.builder(
        itemCount: history.length,
        itemBuilder: (context, i) {
          final h = history[i];
          final isSos = (h['type'] ?? '').toString() == 'sos';
          final resolved = h['resolved'] == true;
          final eventId = (h['id'] ?? '').toString();

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          h['title']?.toString() ?? 'History',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (isSos)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            color: resolved ? Colors.green.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
                          ),
                          child: Text(
                            resolved ? 'Resolved' : 'Active',
                            style: TextStyle(
                              color: resolved ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(h['desc']?.toString() ?? ''),
                  const SizedBox(height: 8),
                  Text(
                    h['time']?.toString() ?? '',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (isSos) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Trigger: ${(h['trigger_type'] ?? '-').toString()} • Reason: ${(h['trigger_reason'] ?? '-').toString()}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!resolved)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _resolving ? null : () => _resolveSos(eventId),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Mark Resolved'),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
