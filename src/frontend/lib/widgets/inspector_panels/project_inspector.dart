import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../models/project.dart';
import '../../state/providers.dart';

/// Detail panel for a ProjectInspection.
class ProjectInspectorPanel extends ConsumerWidget {
  final String projectId;
  const ProjectInspectorPanel({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final projects = ref.watch(projectsProvider);
    final hierarchy = ref.watch(taskHierarchyProvider(projectId));
    final milestones = ref.watch(milestonesProvider(projectId));

    return projects.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _err(theme, '$e'),
      data: (list) {
        final p = list.where((p) => p.id == projectId).cast<Project?>().firstOrNull;
        if (p == null) return _err(theme, 'Project not found (or hidden by view scope).');

        final hierarchyData = hierarchy.asData?.value ?? const [];
        final leafCount = hierarchyData.where((n) => !n.hasChildren).length;
        final parentCount = hierarchyData.length - leafCount;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      p.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _statusPill(theme, p.status.name),
              const SizedBox(height: 16),
              if ((p.description ?? '').isNotEmpty) ...[
                Text(p.description!, style: theme.textTheme.bodySmall),
                const SizedBox(height: 16),
              ],
              _sectionHeader(theme, 'Stats'),
              Text(
                '$leafCount leaf tasks · $parentCount group tasks',
                style: theme.textTheme.bodySmall,
              ),
              if (p.createdAt != null)
                Text(
                  'created ${DateFormat.yMMMd().format(p.createdAt!.toLocal())}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              const SizedBox(height: 16),
              _sectionHeader(theme, 'Milestones'),
              milestones.when(
                loading: () => const SizedBox(
                    height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Text('$e', style: TextStyle(color: theme.colorScheme.error)),
                data: (ms) => ms.isEmpty
                    ? Text('—', style: theme.textTheme.bodySmall)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: ms.map((m) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Icon(Icons.flag_outlined, size: 12, color: theme.colorScheme.outline),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(m.title, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                                ),
                                Text(
                                  '${DateFormat.yMMMd().format(m.date.toLocal())} · ${m.status.name}',
                                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _sectionHeader(theme, 'Top-level tasks'),
              if (hierarchy.isLoading)
                const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (hierarchyData.where((n) => n.parentTaskId == null).isEmpty)
                Text('—', style: theme.textTheme.bodySmall)
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: hierarchyData
                      .where((n) => n.parentTaskId == null)
                      .map((n) => InkWell(
                            onTap: () {
                              ref.read(inspectionProvider.notifier).state = TaskInspection(n.id);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Icon(
                                    n.hasChildren ? Icons.folder_open_outlined : Icons.task_alt_outlined,
                                    size: 12,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(n.title, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis),
                                  ),
                                  Text(
                                    (n.hasChildren ? n.computedStatus : n.status).name,
                                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                                  ),
                                ],
                              ),
                            ),
                          ))
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _err(ThemeData theme, String msg) =>
      Padding(padding: const EdgeInsets.all(16), child: Text(msg, style: TextStyle(color: theme.colorScheme.error)));

  Widget _sectionHeader(ThemeData theme, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: theme.colorScheme.outline,
          ),
        ),
      );

  Widget _statusPill(ThemeData theme, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
}
