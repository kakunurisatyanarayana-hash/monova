import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Everything kept private on this phone: passwords and notes, and saved cards. One place from Home.
class VaultHubScreen extends StatelessWidget {
  const VaultHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.monova;
    Widget tile(IconData icon, String title, String subtitle, String route) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: MonovaCard(
            padding: const EdgeInsets.all(14),
            onTap: () => context.push(route),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: c.accentStart.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: c.accentStart),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: c.muted, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: c.muted),
              ],
            ),
          ),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          MonovaCard(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Stored only on this phone, in its secure storage. Nothing is uploaded.',
              style: TextStyle(color: c.muted, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          tile(Icons.key_rounded, 'Passwords and notes', 'Logins, PINs, account numbers and private notes', '/vault'),
          tile(Icons.credit_card_rounded, 'Cards', 'Card name, bank, last four digits and a photo', '/saved-cards'),
        ],
      ),
    );
  }
}
