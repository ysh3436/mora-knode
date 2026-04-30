import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/providers.dart';
import 'inspector_panels/project_inspector.dart';
import 'inspector_panels/task_inspector.dart';

/// Right pane that shows the detail of whatever the user has selected. Empty
/// state when nothing is selected. Subsequent stages plug in real content for
/// each Inspection variant (TaskInspection, ProjectInspection, ...).
class Inspector extends ConsumerWidget {
  const Inspector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection = ref.watch(inspectionProvider);
    final theme = Theme.of(context);
    final l = AppL10n.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(left: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                Text(l.inspectorTitle, style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: l.topbarCloseInspector,
                  iconSize: 18,
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(inspectorOpenProvider.notifier).state = false,
                ),
              ],
            ),
          ),
          Expanded(child: _InspectorBody(inspection: inspection)),
        ],
      ),
    );
  }
}

class _InspectorBody extends StatelessWidget {
  final Inspection? inspection;
  const _InspectorBody({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);

    if (inspection == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l.inspectorEmpty,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return switch (inspection!) {
      TaskInspection(taskId: final id) => TaskInspectorPanel(taskId: id),
      ProjectInspection(projectId: final id) => ProjectInspectorPanel(projectId: id),
    };
  }
}
