import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'screens/main_screen.dart';
import 'state/providers.dart';

void main() {
  runApp(const ProviderScope(child: MoraKnodeApp()));
}

class MoraKnodeApp extends ConsumerWidget {
  const MoraKnodeApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    // Fire the one-shot first-run holiday auto-seed. We don't await or
    // surface its result — the UI mounts regardless and the backend gates
    // on its own AppMeta flag so this is safe to re-trigger on every
    // app start / hot restart.
    ref.watch(autoSeedHolidaysProvider);
    return MaterialApp(
      title: 'Mora Knode',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const MainScreen(),
    );
  }
}
