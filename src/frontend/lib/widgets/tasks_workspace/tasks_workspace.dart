import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../task_editor.dart';
import 'tasks_calendar.dart';
import 'tasks_filters.dart';
import 'tasks_gantt.dart';
import 'tasks_list.dart';

/// Reusable tasks workspace — shared filter bar, sub-tabs (List / Gantt /
/// Calendar), and the active subview body. Drives both the All work section
/// (no scope) and per-project Tasks tabs (scopeProjectId set).
///
/// Behaviour with [scopeProjectId]:
/// - null → cross-project view (uses [projectFilterProvider] for project filter)
/// - non-null → forces the project filter to that one project, and child views
///   skip the project group header / project filter chip since the context is
///   already implicit in the host page.
class TasksWorkspace extends ConsumerWidget {
  final String? scopeProjectId;
  const TasksWorkspace({super.key, this.scopeProjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(tasksSubviewProvider);
    final theme = Theme.of(context);
    final l = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              SegmentedButton<TasksSubview>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: [
                  ButtonSegment(value: TasksSubview.list, label: Text(l.tabList), icon: const Icon(Icons.list, size: 16)),
                  ButtonSegment(value: TasksSubview.gantt, label: Text(l.tabGantt), icon: const Icon(Icons.view_timeline, size: 16)),
                  ButtonSegment(
                      value: TasksSubview.calendar,
                      label: Text(l.tabCalendar),
                      icon: const Icon(Icons.calendar_view_month, size: 16)),
                ],
                selected: {sub},
                onSelectionChanged: (s) => ref.read(tasksSubviewProvider.notifier).state = s.first,
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(l.newTask),
                onPressed: () => showTaskEditor(context, ref, projectId: scopeProjectId),
              ),
            ],
          ),
        ),
        TasksFilters(scopeProjectId: scopeProjectId),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: switch (sub) {
            TasksSubview.list => TasksList(scopeProjectId: scopeProjectId),
            TasksSubview.gantt => TasksGantt(scopeProjectId: scopeProjectId),
            TasksSubview.calendar => TasksCalendar(scopeProjectId: scopeProjectId),
          },
        ),
      ],
    );
  }
}
