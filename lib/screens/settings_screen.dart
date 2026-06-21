import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../widgets/app_header.dart';
import 'nutrition_coach_screen.dart';

/// Ayarlar: profil, hedefler, uygulama ayarları, yapay zeka, hesap, destek.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const AppHeader(),
            _profileCard(context, settings),
            _label('HEDEFLER'),
            _group(context, [
              _Tile(
                icon: Icons.auto_awesome_outlined,
                title: 'Beslenme Koçu',
                value: settings.nutritionGoal.label,
                valueColor: scheme.secondary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NutritionCoachScreen(),
                  ),
                ),
              ),
              _Tile(
                icon: Icons.monitor_weight_outlined,
                title: 'Kilo Hedefi',
                value: '${settings.weightGoal} kg',
                onTap: () => _editInt(
                  context,
                  title: 'Kilo Hedefi (kg)',
                  initial: settings.weightGoal,
                  onSave: settings.setWeightGoal,
                ),
              ),
              _Tile(
                icon: Icons.local_fire_department_outlined,
                title: 'Günlük Kalori Hedefi',
                value: '${settings.calorieGoal} kcal',
                onTap: () => _editInt(
                  context,
                  title: 'Günlük Kalori Hedefi (kcal)',
                  initial: settings.calorieGoal,
                  onSave: settings.setCalorieGoal,
                ),
              ),
            ]),
            _label('UYGULAMA AYARLARI'),
            _group(context, [
              _Tile(
                icon: Icons.notifications_none_rounded,
                title: 'Bildirimler',
                trailing: Switch(
                  value: settings.notifications,
                  onChanged: settings.setNotifications,
                ),
              ),
              _Tile(
                icon: Icons.dark_mode_outlined,
                title: 'Koyu Tema',
                trailing: Switch(
                  value: isDark,
                  onChanged: (v) => settings.setThemeMode(
                    v ? ThemeMode.dark : ThemeMode.light,
                  ),
                ),
              ),
              _Tile(
                icon: Icons.straighten,
                title: 'Birimler',
                value: 'Metrik (kg/kcal)',
                onTap: () => _soon(context),
              ),
            ]),
            _label('YAPAY ZEKA'),
            _group(context, [
              _Tile(
                icon: Icons.cloud_outlined,
                title: 'Beslenme AI Backend',
                value: settings.coachBackendUrl,
                onTap: () => _editBackendUrl(context, settings),
              ),
              _Tile(
                icon: Icons.smart_toy_outlined,
                title: 'Gemini API Anahtarı',
                value: settings.hasApiKey ? 'Ayarlı' : 'Ayarlı değil',
                valueColor: settings.hasApiKey ? scheme.secondary : null,
                onTap: () => _editApiKey(context, settings),
              ),
            ]),
            _label('HESAP'),
            _group(context, [
              _Tile(
                icon: Icons.workspace_premium_outlined,
                title: 'Abonelik',
                trailing: _proBadge(context),
                onTap: () => _soon(context),
              ),
              _Tile(
                icon: Icons.download_outlined,
                title: 'Veriyi Dışa Aktar',
                onTap: () => _soon(context),
              ),
            ]),
            _label('DESTEK'),
            _group(context, [
              _Tile(
                icon: Icons.help_outline,
                title: 'Yardım Merkezi',
                onTap: () => _soon(context),
              ),
              _Tile(
                icon: Icons.chat_bubble_outline,
                title: 'Geri Bildirim',
                onTap: () => _soon(context),
              ),
            ]),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => _soon(context),
                child: Text(
                  'Çıkış Yap',
                  style: TextStyle(
                    color: scheme.error,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'NutriTrack • EE471 Final Projesi',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileCard(BuildContext context, SettingsProvider settings) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: scheme.secondary.withValues(alpha: 0.2),
                child: Icon(Icons.person, size: 32, color: scheme.secondary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.userName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () => _editName(context, settings),
                      child: Text(
                        'Profili Düzenle',
                        style: TextStyle(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _proBadge(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'PRO',
        style: TextStyle(
          color: scheme.onSecondary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        letterSpacing: 0.6,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8A958E),
      ),
    ),
  );

  Widget _group(BuildContext context, List<Widget> tiles) {
    final children = <Widget>[];
    for (var i = 0; i < tiles.length; i++) {
      children.add(tiles[i]);
      if (i < tiles.length - 1) {
        children.add(const Divider(indent: 56, height: 1));
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(child: Column(children: children)),
    );
  }

  void _soon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bu özellik yakında eklenecek')),
    );
  }

  Future<void> _editInt(
    BuildContext context, {
    required String title,
    required int initial,
    required Future<void> Function(int) onSave,
  }) async {
    final c = TextEditingController(text: initial.toString());
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok == true) {
      final v = int.tryParse(c.text.trim());
      if (v != null && v > 0) await onSave(v);
    }
  }

  Future<void> _editName(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final c = TextEditingController(text: settings.userName);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('İsim'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok == true) await settings.setUserName(c.text);
  }

  Future<void> _editApiKey(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final c = TextEditingController(text: settings.geminiApiKey);
    var obscure = true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Gemini API Anahtarı'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Fotoğraftan kalori için Google AI Studio\'dan ücretsiz alınır.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: c,
                obscureText: obscure,
                decoration: InputDecoration(
                  labelText: 'Anahtar',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await settings.setGeminiApiKey(c.text);
  }

  Future<void> _editBackendUrl(
    BuildContext context,
    SettingsProvider settings,
  ) async {
    final controller = TextEditingController(text: settings.coachBackendUrl);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Beslenme AI Backend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Android emülatörü için http://10.0.2.2:8000 kullan. '
              'Gerçek telefonda bilgisayarının yerel IP adresini yaz.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Backend URL',
                hintText: 'http://10.0.2.2:8000',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (ok == true) await settings.setCoachBackendUrl(controller.text);
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final Color? valueColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    this.value,
    this.valueColor,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: scheme.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (trailing != null)
              trailing!
            else ...[
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(color: valueColor ?? muted, fontSize: 14),
                ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Icon(Icons.chevron_right, color: muted, size: 20),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
