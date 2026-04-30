import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/project.dart';
import '../../models/resource.dart';
import '../../models/task_item.dart';
import '../../state/providers.dart';

/// Filter row shared across All work subviews (list / gantt / calendar).
/// Project, assignee, status as multi-select chips + free-text search.
class AllWorkFilters extends ConsumerWidget {
  const AllWorkFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projects = ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final resources = ref.watch(resourcesProvider).asData?.value ?? const <Resource>[];

    final projectFilter = ref.watch(projectFilterProvider);
    final assigneeFilter = ref.watch(assigneeFilterProvider);
    final statusFilter = ref.watch(statusFilterProvider);
    final search = ref.watch(searchQueryProvider);

    final humanNames = _uniqueNames(resources);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          _MultiChip<String>(
            icon: Icons.folder_outlined,
            label: 'Project',
            selected: projectFilter,
            options: projects
                .where((p) => p.id != null)
                .map((p) => (id: p.id!, label: p.name))
                .toList(),
            onChanged: (s) => ref.read(projectFilterProvider.notifier).state = s,
          ),
          const SizedBox(width: 8),
          _MultiChip<String>(
            icon: Icons.person_outline,
            label: 'Assignee',
            selected: assigneeFilter,
            options: humanNames.map((n) => (id: n, label: n)).toList(),
            onChanged: (s) => ref.read(assigneeFilterProvider.notifier).state = s,
          ),
          const SizedBox(width: 8),
          _MultiChip<TaskStatus>(
            icon: Icons.flag_outlined,
            label: 'Status',
            selected: statusFilter.map((e) => e.name).toSet(),
            options: TaskStatus.values.map((s) => (id: s.name, label: s.name)).toList(),
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
                hintText: 'Search title…',
                prefixIcon: const Icon(Icons.search, size: 16),
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              ),
              controller: TextEditingController(text: search)
                ..selection = TextSelection.collapsed(offset: search.length),
              onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
            ),
          ),
          const SizedBox(width: 8),
          if (projectFilter.isNotEmpty ||
              assigneeFilter.isNotEmpty ||
              statusFilter.isNotEmpty ||
              search.isNotEmpty)
            TextButton.icon(
              icon: const Icon(Icons.clear_all, size: 16),
              label: const Text('Clear'),
              onPressed: () {
                ref.read(projectFilterProvider.notifier).state = <String>{};
                ref.read(assigneeFilterProvider.notifier).state = <String>{};
                ref.read(statusFilterProvider.notifier).state = <TaskStatus>{};
                ref.read(searchQueryProvider.notifier).state = '';
              },
            ),
          const Spacer(),
          Text(
            '${projects.length} projects · ${resources.length} resources',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  static List<String> _uniqueNames(List<Resource> resources) {
    final names = <String>{for (final r in resources) r.name.trim()};
    final list = names.where((n) => n.isNotEmpty).toList()..sort();
    return list;
  }
}

class _MultiChip<T> extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    final empty = selected.isEmpty;
    return PopupMenuButton<String>(
      tooltip: 'Filter by $label',
      itemBuilder: (ctx) => options
          .map((o) => CheckedPopupMenuItem<String>(
                value: o.id,
                checked: selected.contains(o.id),
                child: Text(o.label, overflow: TextOverflow.ellipsis),
              ))
          .toList(),
      onSelected: (id) {
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
        label: Text(empty ? '$label: all' : '$label (${selected.length})'),
        onDeleted: empty ? null : () => onChanged(<String>{}),
      ),
    );
  }
}
