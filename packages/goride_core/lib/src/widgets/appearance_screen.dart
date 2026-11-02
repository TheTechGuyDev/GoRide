import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import 'settings_widgets.dart';

/// Screens 81-83: theme and language.
class AppearanceScreen extends ConsumerWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final lang = ref.watch(languageProvider);

    Widget themeOption(ThemeMode m, IconData icon, String label, String sub) {
      final selected = mode == m;
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          icon,
          color: selected ? AppColors.primary : AppColors.textPrimary,
        ),
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
        trailing: selected
            ? const Icon(Icons.check_circle, color: AppColors.primary)
            : Icon(Icons.circle_outlined, color: AppColors.textHint),
        onTap: () => ref.read(themeModeProvider.notifier).set(m),
      );
    }

    return SettingsPage(
      title: 'App Appearance',
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Theme',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        SettingsGroup(
          children: [
            themeOption(
              ThemeMode.light,
              Icons.light_mode_outlined,
              'Light',
              'Bright and clear in daylight',
            ),
            themeOption(
              ThemeMode.dark,
              Icons.dark_mode_outlined,
              'Dark',
              'Easier on the eyes at night, saves battery',
            ),
            themeOption(
              ThemeMode.system,
              Icons.phone_android,
              'Same as my phone',
              'Follow your phone\'s setting',
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Language',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        SettingsGroup(
          children: [
            for (final l in AppLanguage.values)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                enabled: l.ready,
                title: Text(
                  l.nativeName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  l.ready ? l.label : '${l.label} · coming soon',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: lang == l
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () => ref.read(languageProvider.notifier).set(l),
              ),
          ],
        ),
        Text(
          'Pidgin, Yoruba, Igbo, Hausa and French will be switched on once each translation has been checked by a native speaker.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
