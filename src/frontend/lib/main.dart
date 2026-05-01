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

  // Force every locale variant to use `tall2021` line metrics so swapping
  // between Korean and English doesn't shift card heights. Without this,
  // Material picks `englishLike2021` for Latin (denser) and `tall2021` for
  // CJK (looser), which propagates a few pixels of difference into every
  // Text widget — visible as cards jumping vertically when toggling locale.
  // English text becomes slightly looser as a side-effect; in practice it
  // reads identical and stability wins for a settings-heavy app.
  static final Typography _typography = Typography.material2021(
    englishLike: Typography.tall2021,
    tall: Typography.tall2021,
    dense: Typography.tall2021,
  );

  // Theme instances are computed once at class-load time. Recreating them
  // inside build() means a fresh ThemeData identity on every parent rebuild,
  // which in turn invalidates every `Theme.of(context)` consumer (including
  // the gantt CustomPainter) and was the dominant source of the toggle lag.
  static final ThemeData _light = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
    useMaterial3: true,
    typography: _typography,
  );
  static final ThemeData _dark = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.indigo,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
    typography: _typography,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    // Fire the one-shot first-run holiday auto-seed. We don't await or
    // surface its result — the UI mounts regardless and the backend gates
    // on its own AppMeta flag so this is safe to re-trigger on every
    // app start / hot restart.
    ref.watch(autoSeedHolidaysProvider);
    return MaterialApp(
      title: 'Mora Knode',
      theme: _light,
      darkTheme: _dark,
      themeMode: themeMode,
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: const MainScreen(),
    );
  }
}
