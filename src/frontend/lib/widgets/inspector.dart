import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';

/// Right pane that shows the detail of whatever the user has selected. Empty
/// state when nothing is selected. Subsequent stages plug in real content for
/// each Inspection variant (TaskInspection, ProjectInspection, ...).
class Inspector extends ConsumerWidget {
  const Inspector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspection = ref.watch(inspectionProvider);
    final theme = Theme.of(context);

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
                Text('Inspector', style: theme.textTheme.titleSmall),
                const Spacer(),
                IconButton(
                  tooltip: 'Close inspector  ]',
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

    if (inspection == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Select a task, project, or plan to see its detail here.',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return switch (inspection!) {
      TaskInspection(taskId: final id) => _Stub(label: 'Task inspector', detail: id),
      ProjectInspection(projectId: final id) => _Stub(label: 'Project inspector', detail: id),
    };
  }
}

class _Stub extends StatelessWidget {
  final String label;
  final String detail;
  const _Stub({required this.label, required this.detail});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(detail, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          const SizedBox(height: 12),
          Text('Detail panels land in the next stage.',
              style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
