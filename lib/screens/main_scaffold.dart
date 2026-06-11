import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/nav_provider.dart';
import 'add_food_screen.dart';
import 'camera_estimate_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Alt menülü ana kabuk: sekmeler IndexedStack ile korunur.
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  static const _pages = [
    HomeScreen(),
    HistoryScreen(),
    AddFoodScreen(),
    CameraEstimateScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final index = context.watch<NavProvider>().index;
    return Scaffold(
      body: IndexedStack(index: index, children: _pages),
      bottomNavigationBar: const _BottomNav(),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavProvider>();
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Ana Sayfa',
                index: 0,
                nav: nav,
              ),
              _NavItem(
                icon: Icons.history_rounded,
                activeIcon: Icons.history_rounded,
                label: 'Geçmiş',
                index: 1,
                nav: nav,
              ),
              _AddButton(nav: nav),
              _NavItem(
                icon: Icons.add_photo_alternate_outlined,
                activeIcon: Icons.add_photo_alternate_rounded,
                label: 'AI Kam',
                index: 3,
                nav: nav,
              ),
              _NavItem(
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
                label: 'Ayarlar',
                index: 4,
                nav: nav,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final NavProvider nav;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.nav,
  });

  @override
  Widget build(BuildContext context) {
    final selected = nav.index == index;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = scheme.onSurfaceVariant.withValues(alpha: 0.8);

    final highlightBg =
        isDark ? scheme.primary.withValues(alpha: 0.18) : scheme.secondary;
    final selectedIconColor = isDark ? scheme.primary : scheme.onSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => nav.go(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? highlightBg : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(selected ? activeIcon : icon,
                  color: selected ? selectedIconColor : muted, size: 24),
            ),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: selected ? scheme.primary : muted,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}

/// Ortadaki belirgin "Ekle" butonu (her zaman dolu yeşil daire).
class _AddButton extends StatelessWidget {
  final NavProvider nav;

  const _AddButton({required this.nav});

  @override
  Widget build(BuildContext context) {
    final selected = nav.index == 2;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final circleBg = isDark ? scheme.secondary : scheme.primary;
    final iconColor = isDark ? scheme.onSecondary : Colors.white;

    return Expanded(
      child: InkWell(
        onTap: () => nav.go(2),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: circleBg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: circleBg.withValues(alpha: 0.4),
                    blurRadius: selected ? 12 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(Icons.add, color: iconColor, size: 26),
            ),
            const SizedBox(height: 2),
            Text('Ekle',
                style: TextStyle(
                    fontSize: 11,
                    color: scheme.primary,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
