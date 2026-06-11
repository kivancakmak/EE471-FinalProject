import 'package:flutter/material.dart';

/// Ana sayfa ve Geçmiş'te kullanılan "NutriTrack" başlığı (avatar + zil).
class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.secondary.withValues(alpha: 0.2),
            child: Icon(Icons.person, color: scheme.secondary),
          ),
          const SizedBox(width: 12),
          Text(
            'NutriTrack',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
              color: scheme.primary,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bildirimler yakında')),
              );
            },
          ),
        ],
      ),
    );
  }
}
