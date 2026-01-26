import 'package:flutter/material.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Upgrade to Premium"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Premium Benefits", style: txt.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  _benefit("🚨 Smart Threat AI", "More accurate detection + fewer false alarms"),
                  _benefit("🗺 Live Safe Zones", "Nearby police, hospitals, crowded places"),
                  _benefit("📍 Auto Location Sharing", "Share live location in emergency instantly"),
                  _benefit("📊 Advanced Analytics", "Weekly insights + risk prediction"),
                  _benefit("👥 Unlimited Guardians", "Add unlimited emergency contacts"),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Payment integration later ✅")),
                  );
                },
                child: const Text("Continue to Payment"),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _benefit(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 10),
          Expanded(child: Text(subtitle)),
        ],
      ),
    );
  }
}
