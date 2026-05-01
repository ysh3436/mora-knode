import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/labels.dart';
import '../../models/project.dart';
import '../../models/resource.dart';
import '../../models/task_hierarchy.dart' show TaskSortKey;
import '../../models/task_item.dart';
import '../../state/providers.dart';

/// Filter row shared across tasks subviews. Each multi-select dropdown has a
/// "Show all (clear)" entry at the top, and a Notion-style pill strip below
/// renders every active selection with an inline ✕ for one-tap removal.
///
/// When [scopeProjectId] is set (per-project Tasks tab), the Project chip and
/// project pills are hidden — the project context is implicit from the host
/// page, and forcing a single value would just be redundant UI.
class TasksFilters extends ConsumerWidget {
  final String? scopeProjectId;
  const TasksFilters({super.key, this.scopeProjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final projects = ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final resources = ref.watch(resourcesProvider).asData?.value ?? const <Resource>[];

    final projectFilter = ref.watch(projectFilterProvider);
    final assigneeFilter = ref.watch(assigneeFilterProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final search = ref.watch(searchQueryProvider);

    final humanNames = _uniqueNames(resources);
    final projectsById = {for (final p in projects) if (p.id != null) p.id!: p};

    final scoped = scopeProjectId != null;
    final hasAny = (!scoped && projectFilter.isNotEmpty) ||
        assigneeFilter.isNotEmpty ||
        statusFilter.isNotEmpty ||
        search.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!scoped) ...[
                _MultiChip(
                  icon: Icons.folder_outlined,
                  label: l.filterProject,
                  selected: projectFilter,
                  options: projects
                      .where((p) => p.id != null)
                      .map((p) => (id: p.id!, label: p.name))
                      .toList(),
                  onChanged: (s) => ref.read(projectFilterProvider.notifier).state = s,
                ),
                const SizedBox(width: 8),
              ],
              _MultiChip(
                icon: Icons.person_outline,
                label: l.filterAssignee,
                selected: assigneeFilter,
                options: humanNames.map((n) => (id: n, label: n)).toList(),
                onChanged: (s) => ref.read(assigneeFilterProvider.notifier).state = s,
              ),
              const SizedBox(width: 8),
              _MultiChip(
                icon: Icons.flag_outlined,
                label: l.filterStatus,
                selected: statusFilter.map((e) => e.name).toSet(),
                options: TaskStatus.values
                    .map((s) => (id: s.name, label: taskStatusLabel(context, s)))
                    .toList(),
                onChanged: (raw) {
                  final values = raw
                      .map((n) => TaskStatus.values.where((s) => s.name == n).cast<TaskStatus?>().firstOrNull)
                      .whereType<TaskStatus>()
                      .toSet();
                  ref.read(statusFilterProvider.notifier).state = values;
                },
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: l.filterSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 16),
                    suffixIcon: search.isEmpty
                        ? null
                        : IconButton(
                            iconSize: 14,
                            tooltip: l.filterClearSearch,
                            icon: const Icon(Icons.close),
                            onPressed: () => ref.read(searchQueryProvider.notifier).state = '',
                          ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  controller: TextEditingController(text: search)
                    ..selection = TextSelection.collapsed(offset: search.length),
                  onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
                ),
              ),
              const SizedBox(width: 8),
              if (hasAny)
                TextButton.icon(
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: Text(l.filterClearAll),
                  onPressed: () {
                    if (!scoped) {
                      ref.read(projectFilterProvider.notifier).state = <String>{};
                    }
                    ref.read(assigneeFilterProvider.notifier).state = <String>{};
                    ref.read(statusFilterProvider.notifier).state = <TaskStatus>{};
                    ref.read(searchQueryProvider.notifier).state = '';
                  },
                ),
              const Spacer(),
              Text(
                l.filterCounter(projects.length, resources.length),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(width: 8),
              const _SortControl(),
            ],
          ),
          if (hasAny) ...[
            const SizedBox(height: 8),
            _ActivePills(
              projectsById: projectsById,
              projectFilter: scoped ? const <String>{} : projectFilter,
              assigneeFilter: assigneeFilter,
              statusFilter: statusFilter,
              search: search,
              onRemoveProject: (id) {
                final next = Set<String>.from(projectFilter)..remove(id);
                ref.read(projectFilterProvider.notifier).state = next;
              },
              onRemoveAssignee: (name) {
                final next = Set<String>.from(assigneeFilter)..remove(name);
                ref.read(assigneeFilterProvider.notifier).state = next;
              },
              onRemoveStatus: (s) {
                final next = Set<TaskStatus>.from(statusFilter)..remove(s);
                ref.read(statusFilterProvider.notifier).state = next;
              },
              onClearSearch: () => ref.read(searchQueryProvider.notifier).state = '',
            ),
          ],
        ],
      ),
    );
  }

  static List<String> _uniqueNames(List<Resource> resources) {
    final names = <String>{for (final r in resources) r.name.trim()};
    return names.where((n) => n.isNotEmpty).toList()..sort();
  }
}

/// Sort key picker + direction toggle. Sits in the filter row alongside
/// the multi-chips. Direction button is a single tap that flips ASC/DESC
/// for the active key — quick and discoverable.
class _SortControl extends ConsumerWidget {
  const _SortControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final theme = Theme.of(context);
    final key = ref.watch(taskSortKeyProvider);
    final asc = ref.watch(taskSortAscProvider);

    String labelOf(TaskSortKey k) => switch (k) {
          TaskSortKey.defaultOrder => l.sortKeyDefault,
          TaskSortKey.priority => l.sortKeyPriority,
          TaskSortKey.dueDate => l.sortKeyDueDate,
          TaskSortKey.status => l.sortKeyStatus,
        };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PopupMenuButton<TaskSortKey>(
          tooltip: l.sortBy,
          itemBuilder: (ctx) => [
            for (final k in TaskSortKey.values)
              CheckedPopupMenuItem<TaskSortKey>(
                value: k,
                checked: k == key,
                child: Text(labelOf(k)),
              ),
          ],
          onSelected: (k) => ref.read(taskSortKeyProvider.notifier).state = k,
          child: InputChip(
            avatar: const Icon(Icons.sort, size: 14),
            label: Text('${l.sortBy}: ${labelOf(key)}'),
          ),
        ),
        const SizedBox(width: 4),
        // Direction toggle is hidden for the default order — direction has
        // no semantic meaning when the sort key is the implicit fallback.
        if (key != TaskSortKey.defaultOrder)
          IconButton(
            tooltip: asc ? l.sortAscending : l.sortDescending,
            iconSize: 18,
            icon: Icon(asc ? Icons.arrow_upward : Icons.arrow_downward, color: theme.colorScheme.outline),
            onPressed: () => ref.read(taskSortAscProvider.notifier).state = !asc,
          ),
      ],
    );
  }
}

class _MultiChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Set<String> selected;
  final List<({String id, String label})> options;
  final ValueChanged<Set<String>> onChanged;

  const _MultiChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  static const _allSentinel = '__all__';

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final empty = selected.isEmpty;
    return PopupMenuButton<String>(
      tooltip: l.filterByLabel(label),
      itemBuilder: (ctx) => [
        // "Show all" entry — selects nothing (clears the filter for this column).
        CheckedPopupMenuItem<String>(
          value: _allSentinel,
          checked: empty,
          child: Text(l.filterShowAll),
        ),
        const PopupMenuDivider(),
        ...options.map((o) => CheckedPopupMenuItem<String>(
              value: o.id,
              checked: selected.contains(o.id),
              child: Text(o.label, overflow: TextOverflow.ellipsis),
            )),
      ],
      onSelected: (id) {
        if (id == _allSentinel) {
          onChanged(<String>{});
          return;
        }
        final next = Set<String>.from(selected);
        if (next.contains(id)) {
          next.remove(id);
        } else {
          next.add(id);
        }
        onChanged(next);
      },
      child: InputChip(
        avatar: Icon(icon, size: 14),
        label: Text(empty ? l.filterAllSuffix(label) : l.filterCountSuffix(label, selected.length)),
      ),
    );
  }
}

/// Notion-style filter pill row. One pill per active selection, each with
/// an inline ✕ that removes that single value (without touching the rest).
class _ActivePills extends StatelessWidget {
  final Map<String, Project> projectsById;
  final Set<String> projectFilter;
  final Set<String> assigneeFilter;
  final Set<TaskStatus> statusFilter;
  final String search;
  final void Function(String id) onRemoveProject;
  final void Function(String name) onRemoveAssignee;
  final void Function(TaskStatus s) onRemoveStatus;
  final VoidCallback onClearSearch;

  const _ActivePills({
    required this.projectsById,
    required this.projectFilter,
    required this.assigneeFilter,
    required this.statusFilter,
    required this.search,
    required this.onRemoveProject,
    required this.onRemoveAssignee,
    required this.onRemoveStatus,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final id in projectFilter)
          _Pill(
            icon: Icons.folder_outlined,
            label: projectsById[id]?.name ?? id,
            onRemove: () => onRemoveProject(id),
          ),
        for (final n in assigneeFilter)
          _Pill(icon: Icons.person_outline, label: n, onRemove: () => onRemoveAssignee(n)),
        for (final s in statusFilter)
          _Pill(icon: Icons.flag_outlined, label: taskStatusLabel(context, s), onRemove: () => onRemoveStatus(s)),
        if (search.isNotEmpty)
          _Pill(icon: Icons.search, label: '"$search"', onRemove: onClearSearch),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onRemove;
  const _Pill({required this.icon, required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(8, 3, 4, 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 2),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close, size: 12, color: theme.colorScheme.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
