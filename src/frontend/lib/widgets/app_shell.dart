import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'inspector.dart';
import 'sidebar.dart';

/// Three-pane desktop layout (wireframes.md §3 candidate A):
/// sidebar (default open) + main content + inspector (default closed).
/// `[` toggles sidebar, `]` toggles inspector — see §6.
class AppShell extends ConsumerWidget {
  final Widget child;
  final Widget? header;

  const AppShell({super.key, required this.child, this.header});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sidebarOpen = ref.watch(sidebarOpenProvider);
    final inspectorOpen = ref.watch(inspectorOpenProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.bracketLeft): () =>
              ref.read(sidebarOpenProvider.notifier).update((s) => !s),
          const SingleActivator(LogicalKeyboardKey.bracketRight): () =>
              ref.read(inspectorOpenProvider.notifier).update((s) => !s),
        },
        child: Focus(
          autofocus: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (sidebarOpen) const Sidebar(),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(header: header),
                    Expanded(child: child),
                  ],
                ),
              ),
              if (inspectorOpen) const SizedBox(width: 520, child: Inspector()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  final Widget? header;
  const _TopBar({this.header});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sidebarOpen = ref.watch(sidebarOpenProvider);
    final inspectorOpen = ref.watch(inspectorOpenProvider);

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: sidebarOpen ? 'Close sidebar  [' : 'Open sidebar  [',
            iconSize: 18,
            icon: Icon(sidebarOpen ? Icons.menu_open : Icons.menu),
            onPressed: () => ref.read(sidebarOpenProvider.notifier).update((s) => !s),
          ),
          const SizedBox(width: 4),
          Expanded(child: header ?? const SizedBox.shrink()),
          IconButton(
            tooltip: inspectorOpen ? 'Close inspector  ]' : 'Open inspector  ]',
            iconSize: 18,
            icon: Icon(inspectorOpen ? Icons.vertical_split : Icons.view_sidebar_outlined),
            onPressed: () => ref.read(inspectorOpenProvider.notifier).update((s) => !s),
          ),
        ],
      ),
    );
  }
}
