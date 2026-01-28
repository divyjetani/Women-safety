// lib/widgets/create_bubble_dialog.dart
import 'package:flutter/material.dart';

class CreateBubbleDialog extends StatefulWidget {
  final Function(String name, IconData icon, Color color) onCreate;

  const CreateBubbleDialog({super.key, required this.onCreate});

  @override
  State<CreateBubbleDialog> createState() => _CreateBubbleDialogState();
}

class _CreateBubbleDialogState extends State<CreateBubbleDialog> {
  final TextEditingController _nameCtrl = TextEditingController();

  IconData _selectedIcon = Icons.groups;
  Color _selectedColor = Colors.deepPurple;

  final icons = [
    Icons.groups,
    Icons.family_restroom,
    Icons.school,
    Icons.work,
    Icons.favorite,
    Icons.sports_soccer,
    Icons.travel_explore,
    Icons.local_cafe,
  ];

  final colors = [
    Colors.deepPurple,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.brown,
    Colors.cyan,
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create Bubble"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Icon"),
            Wrap(
              spacing: 8,
              children: icons.map((i) {
                return ChoiceChip(
                  label: Icon(i),
                  selected: _selectedIcon == i,
                  onSelected: (_) => setState(() => _selectedIcon = i),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),
            const Text("Color"),
            Wrap(
              spacing: 8,
              children: colors.map((c) {
                return ChoiceChip(
                  selectedColor: c,
                  label: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                    ),
                  ),
                  selected: _selectedColor == c,
                  onSelected: (_) => setState(() => _selectedColor = c),
                );
              }).toList(),
            ),

            const SizedBox(height: 14),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                hintText: "Bubble name",
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onCreate(
              _nameCtrl.text.trim(),
              _selectedIcon,
              _selectedColor,
            );
            Navigator.pop(context);
          },
          child: const Text("Create"),
        ),
      ],
    );
  }
}
