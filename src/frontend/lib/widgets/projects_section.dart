import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/project.dart';
import '../models/task_hierarchy.dart';
import '../state/providers.dart';
import 'tasks_workspace/tasks_workspace.dart';

/// Routes between the project directory (when no project is selected) and a
/// per-project page. Stage A surface — Issues / Initiatives / Documents tabs
/// are placeholders awaiting Stages B/C/D.
class ProjectsSection extends ConsumerWidget {
  const ProjectsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedProjectIdProvider);
    if (selectedId == null) return const _ProjectsDirectory();
    return _ProjectPage(projectId: selectedId);
  }
}

class _ProjectsDirectory extends ConsumerWidget {
  const _ProjectsDirectory();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final projects = ref.watch(projectsProvider);
    final hierarchies = ref.watch(allHierarchyByProjectProvider);

    return projects.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.errorPrefix(e.toString()))),
      data: (list) {
        if (list.isEmpty) {
          return Center(
            child: Text(
              l.projectsDirectoryEmpty,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
            ),
          );
        }
        final countsByProject = <String, int>{
          for (final g in hierarchies.asData?.value ?? const []) g.project.id ?? '': g.nodes.length,
        };

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(l.projectsDirectoryTitle, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final cardWidth = 280.0;
              final crossAxis = (constraints.maxWidth / cardWidth).floor().clamp(1, 6);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxis,
                childAspectRatio: 2.4,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  for (final p in list)
                    _ProjectCard(
                      project: p,
                      taskCount: countsByProject[p.id ?? ''] ?? 0,
                      onTap: p.id == null
                          ? null
                          : () => ref.read(selectedProjectIdProvider.notifier).state = p.id,
                    ),
                ],
              );
            }),
          ],
        );
      },
    );
  }
}

class _ProjectCard extends StatelessWidget {
  final Project project;
  final int taskCount;
  final VoidCallback? onTap;

  const _ProjectCard({required this.project, required this.taskCount, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.folder_outlined, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusPill(theme, project.status.name),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  (project.description ?? '').isEmpty ? '—' : project.description!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.task_alt_outlined, size: 12, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text('$taskCount', style: theme.textTheme.bodySmall),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusPill(ThemeData theme, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      );
}

class _ProjectPage extends ConsumerStatefulWidget {
  final String projectId;
  const _ProjectPage({required this.projectId});

  @override
  ConsumerState<_ProjectPage> createState() => _ProjectPageState();
}

enum _ProjectTab { overview, tasks, issues, initiatives, documents }

class _ProjectPageState extends ConsumerState<_ProjectPage> {
  _ProjectTab _tab = _ProjectTab.overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final projects = ref.watch(projectsProvider);
    final hierarchy = ref.watch(taskHierarchyProvider(widget.projectId));
    final milestones = ref.watch(milestonesProvider(widget.projectId));

    return projects.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.errorPrefix(e.toString()))),
      data: (list) {
        final project = list.where((p) => p.id == widget.projectId).cast<Project?>().firstOrNull;
        if (project == null) {
          return Center(child: Text(l.projectInspectorNotFound));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(project: project, onBack: () => ref.read(selectedProjectIdProvider.notifier).state = null),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: SegmentedButton<_ProjectTab>(
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  ButtonSegment(value: _ProjectTab.overview, label: Text(l.projectTabOverview), icon: const Icon(Icons.dashboard_outlined, size: 16)),
                  ButtonSegment(value: _ProjectTab.tasks, label: Text(l.projectTabTasks), icon: const Icon(Icons.task_alt_outlined, size: 16)),
                  ButtonSegment(value: _ProjectTab.issues, label: Text(l.projectTabIssues), icon: const Icon(Icons.bug_report_outlined, size: 16)),
                  ButtonSegment(value: _ProjectTab.initiatives, label: Text(l.projectTabInitiatives), icon: const Icon(Icons.lightbulb_outlined, size: 16)),
                  ButtonSegment(value: _ProjectTab.documents, label: Text(l.projectTabDocuments), icon: const Icon(Icons.description_outlined, size: 16)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
            Divider(height: 1, color: theme.dividerColor),
            Expanded(
              child: switch (_tab) {
                _ProjectTab.overview => _OverviewTab(
                    project: project,
                    hierarchy: hierarchy,
                    milestones: milestones,
                  ),
                _ProjectTab.tasks => TasksWorkspace(scopeProjectId: widget.projectId),
                _ProjectTab.issues => _ComingTab(title: l.projectIssuesComing),
                _ProjectTab.initiatives => _ComingTab(title: l.projectInitiativesComing),
                _ProjectTab.documents => _ComingTab(title: l.projectDocumentsComing),
              },
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final Project project;
  final VoidCallback onBack;
  const _Header({required this.project, required this.onBack});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, size: 16),
            label: Text(l.projectBackToDirectory),
          ),
          const SizedBox(width: 8),
          Icon(Icons.folder_outlined, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              project.name,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              project.status.name,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  final Project project;
  final AsyncValue<List<TaskHierarchyNode>> hierarchy;
  final AsyncValue<dynamic> milestones;

  const _OverviewTab({
    required this.project,
    required this.hierarchy,
    required this.milestones,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final nodes = hierarchy.asData?.value ?? const <TaskHierarchyNode>[];
    final milestoneList = milestones.asData?.value as List<dynamic>? ?? const [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((project.description ?? '').isNotEmpty) ...[
            Text(project.description!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],
          Text(
            l.projectOverviewCounts(nodes.length, milestoneList.length),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          if (project.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              l.projectCreated(DateFormat.yMMMd(dateLocale(context)).format(project.createdAt!.toLocal())),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
          const SizedBox(height: 24),
          _sectionHeader(theme, l.inspectorSectionTopLevel),
          if (hierarchy.isLoading)
            const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else if (nodes.where((n) => n.parentTaskId == null).isEmpty)
            Text(l.projectTasksEmpty, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: nodes.where((n) => n.parentTaskId == null).map((n) {
                return InkWell(
                  onTap: () {
                    ref.read(inspectionProvider.notifier).state = TaskInspection(n.id);
                    ref.read(inspectorOpenProvider.notifier).state = true;
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Icon(
                          n.hasChildren ? Icons.folder_open_outlined : Icons.task_alt_outlined,
                          size: 14,
                          color: theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(n.title, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
                        Text(
                          taskStatusDisplay(context, n.hasChildren ? n.computedStatus : n.status, aggregated: n.hasChildren),
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _sectionHeader(ThemeData theme, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 1.0,
            color: theme.colorScheme.outline,
          ),
        ),
      );
}

class _ComingTab extends StatelessWidget {
  final String title;
  const _ComingTab({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction, size: 32, color: theme.colorScheme.outline),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              l.comingSoon,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
