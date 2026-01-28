import 'package:flutter/material.dart';
import '../models/bubble_model.dart';

class BubbleInfoSheet extends StatelessWidget {
  final SafetyGroup group;

  const BubbleInfoSheet({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(group.name,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ...group.members.map((m) => ListTile(
            leading: CircleAvatar(
              child: Text(m.name[0].toUpperCase()),
            ),
            title: Text(m.name),
          )),
        ],
      ),
    );
  }
}
