import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cassa1/logic/providers/theme_provider.dart';
import 'package:cassa1/utils/constants.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: AppColors.primary,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                Text(
                  AppStrings.appName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                      ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => context.go('/'),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text(AppStrings.subjects),
            onTap: () => context.go('/subjects'),
          ),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text(AppStrings.groups),
            onTap: () => context.go('/groups'),
          ),
          ListTile(
            leading: const Icon(Icons.receipt),
            title: const Text(AppStrings.entries),
            onTap: () => context.go('/entries'),
          ),
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: const Text(AppStrings.transactions),
            onTap: () => context.go('/transactions'),
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: const Text('Tutti i movimenti'),
            onTap: () => context.go('/all-transactions'),
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text(AppStrings.reports),
            onTap: () => context.go('/reports'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Chiusura mensile'),
            onTap: () => context.go('/monthly-closing'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Tema scuro'),
            value: isDark,
            onChanged: (_) {
              ref.read(themeModeProvider.notifier).setTheme(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  );
            },
          ),
        ],
      ),
    );
  }
}
