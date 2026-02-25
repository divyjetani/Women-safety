// lib/screens/bubbles_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile/providers/bubble_provider.dart';
import 'package:mobile/screens/bubble_members_screen.dart';
import 'package:mobile/screens/create_bubble_screen.dart';
import 'package:mobile/screens/join_bubble_screen.dart';

class BubblesListScreen extends StatefulWidget {
  const BubblesListScreen({Key? key}) : super(key: key);

  @override
  State<BubblesListScreen> createState() => _BubblesListScreenState();
}

class _BubblesListScreenState extends State<BubblesListScreen> {
  @override
  void initState() {
    super.initState();
    // Load bubbles on screen init
    Future.microtask(() {
      context.read<BubbleProvider>().fetchUserBubbles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Bubbles'),
        elevation: 0,
        backgroundColor: const Color(0xFF1A1F2E),
        foregroundColor: Colors.white,
      ),
      body: Consumer<BubbleProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.bubbles.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchUserBubbles(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.bubbles.length,
              itemBuilder: (context, index) {
                final bubble = provider.bubbles[index];
                final isAdmin = bubble.adminId == provider.userId;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: const Color(0xFF1A1F2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF2A3540)),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              BubbleMembersScreen(initialBubble: bubble),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ HEADER
                          Row(
                            children: [
                              // Bubble Icon
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Color(bubble.color),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  ['🛡️', '👥', '🚨', '📍', '🔐', '⚡'][
                                      bubble.icon % 6],
                                  style: const TextStyle(fontSize: 20),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Bubble Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bubble.name,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Code: ${bubble.code}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFFF1744),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Admin badge
                              if (isAdmin)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00E676),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'Admin',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          const Divider(color: Color(0xFF2A3540)),
                          const SizedBox(height: 12),

                          // ✅ MEMBERS INFO
                          Row(
                            children: [
                              Icon(
                                Icons.people,
                                size: 16,
                                color: Color(bubble.color),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${bubble.members.length} members',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFFB4BCD0),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Active members
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${bubble.members.where((m) => m.lat != null).length} sharing',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),

                          if (bubble.members.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            const Text(
                              'Members:',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFB4BCD0),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: bubble.members
                                  .take(5)
                                  .map((member) => Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF151B23),
                                          border: Border.all(
                                            color: Color(bubble.color),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${member.name} 🔋${member.battery}%',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ))
                                  .toList(),
                            ),
                            if (bubble.members.length > 5)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  '+${bubble.members.length - 5} more',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFB4BCD0),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],

                          // ✅ DELETE BUTTON (ADMIN ONLY)
                          if (isAdmin) ...[
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () =>
                                    _showDeleteConfirmation(context, bubble.code),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade900,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text(
                                  'Delete Bubble',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const JoinBubbleScreen(),
                ),
              ).then((bubble) {
                if (bubble != null) {
                  context.read<BubbleProvider>().setCurrentBubble(bubble);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BubbleMembersScreen(initialBubble: bubble),
                    ),
                  );
                }
              });
            },
            backgroundColor: const Color(0xFF00E676),
            label: const Text(
              'Join Bubble',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.person_add),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateBubbleScreen(),
                ),
              ).then((bubble) {
                if (bubble != null) {
                  context.read<BubbleProvider>().fetchUserBubbles();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          BubbleMembersScreen(initialBubble: bubble),
                    ),
                  );
                }
              });
            },
            backgroundColor: const Color(0xFFFF1744),
            label: const Text(
              'Create Bubble',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  // ✅ EMPTY STATE
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF151B23),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text('🫧', style: TextStyle(fontSize: 64)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Bubbles Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a bubble or join an existing one\nto start sharing location safely',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFFB4BCD0),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CreateBubbleScreen(),
                ),
              ).then((bubble) {
                if (bubble != null) {
                  context.read<BubbleProvider>().fetchUserBubbles();
                }
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Create Your First Bubble'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF1744),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ DELETE CONFIRMATION DIALOG
  void _showDeleteConfirmation(BuildContext context, String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1F2E),
        title: const Text(
          'Delete Bubble',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure? This will remove the bubble for all members.',
          style: TextStyle(color: Color(0xFFB4BCD0)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<BubbleProvider>().deleteBubble(code);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bubble deleted'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
