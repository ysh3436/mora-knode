import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/providers.dart';
import 'inspector.dart';
import 'sidebar.dart';

/// Three-pane desktop layout (wireframes.md §3 candidate A):
/// sidebar (default open) + main content + inspector (default closed).
/// `[` toggles sidebar, `]` toggles inspector — see §6.
class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final Widget? header;

  /// ADR-008 commits the app to desktop-only sizing. We pin the layout
  /// to this minimum width and let the browser scroll horizontally
  /// when the viewport is narrower, instead of letting child widgets
  /// fight for shrinking space and emit RenderFlex overflow assertions.
  /// Picked at 1200 because the gantt + inspector (520) + sidebar (220)
  /// already sums to ~960 and we want some slack for the centre pane.
  static const double _minLayoutWidth = 1200;

  const AppShell({super.key, required this.child, this.header});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  /// Owned by the state so the Scrollbar's thumbVisibility flag has
  /// a stable controller across rebuilds — sharing a controller with
  /// the SingleChildScrollView is what makes the always-visible
  /// horizontal scrollbar work.
  late final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sidebarOpen = ref.watch(sidebarOpenProvider);
    final inspectorOpen = ref.watch(inspectorOpenProvider);
    final inspectorWidth = ref.watch(inspectorWidthProvider);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // If the viewport is narrower than the design minimum,
              // pin to _minLayoutWidth and let the user scroll
              // horizontally. When wider, take the full viewport.
              const minWidth = AppShell._minLayoutWidth;
              final layoutWidth = constraints.maxWidth < minWidth
                  ? minWidth
                  : constraints.maxWidth;
              final maxW = (layoutWidth - 360).clamp(360.0, 1200.0);
              final w = inspectorWidth.clamp(360.0, maxW);
              final shell = SizedBox(
                width: layoutWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (sidebarOpen) const Sidebar(),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(header: widget.header),
                          Expanded(child: widget.child),
                        ],
                      ),
                    ),
                    if (inspectorOpen) ...[
                      _InspectorResizeHandle(
                        onDelta: (dx) {
                          // Drag right = handle moves right = inspector shrinks.
                          final next = (w - dx).clamp(360.0, maxW);
                          ref.read(inspectorWidthProvider.notifier).state = next;
                        },
                      ),
                      SizedBox(width: w, child: const Inspector()),
                    ],
                  ],
                ),
              );
              if (constraints.maxWidth < minWidth) {
                // Scrollbar with thumbVisibility forces the bar to
                // render even before the user touches anything — Flutter
                // web's default is to only show on interaction, which
                // would leave a narrow-window user wondering whether
                // anything is hidden off-screen. Bar shares the
                // controller owned by _AppShellState so the visibility
                // assertion is satisfied across rebuilds.
                return Scrollbar(
                  thumbVisibility: true,
                  controller: _hScroll,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _hScroll,
                    child: shell,
                  ),
                );
              }
              return shell;
            },
          ),
        ),
      ),
    );
  }
}

class _InspectorResizeHandle extends StatefulWidget {
  final void Function(double dx) onDelta;
  const _InspectorResizeHandle({required this.onDelta});

  @override
  State<_InspectorResizeHandle> createState() => _InspectorResizeHandleState();
}

class _InspectorResizeHandleState extends State<_InspectorResizeHandle> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (d) => widget.onDelta(d.delta.dx),
        child: Container(
          width: 6,
          decoration: BoxDecoration(
            color: _hover
                ? theme.colorScheme.primary.withValues(alpha: 0.25)
                : theme.dividerColor,
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
    final l = AppL10n.of(context);
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
            tooltip: sidebarOpen ? l.topbarCloseSidebar : l.topbarOpenSidebar,
            iconSize: 18,
            icon: Icon(sidebarOpen ? Icons.menu_open : Icons.menu),
            onPressed: () => ref.read(sidebarOpenProvider.notifier).update((s) => !s),
          ),
          const SizedBox(width: 4),
          Expanded(child: header ?? const SizedBox.shrink()),
          IconButton(
            tooltip: inspectorOpen ? l.topbarCloseInspector : l.topbarOpenInspector,
            iconSize: 18,
            icon: Icon(inspectorOpen ? Icons.vertical_split : Icons.view_sidebar_outlined),
            onPressed: () => ref.read(inspectorOpenProvider.notifier).update((s) => !s),
          ),
        ],
      ),
    );
  }
}
