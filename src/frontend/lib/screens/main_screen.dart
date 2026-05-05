import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/providers.dart';
import '../widgets/agents_section.dart';
import '../widgets/app_shell.dart';
import '../widgets/matrix_section.dart';
import '../widgets/my_work_section.dart';
import '../widgets/projects_section.dart';
import '../widgets/settings_section.dart';
import '../widgets/tasks_workspace/tasks_workspace.dart';

/// Top-level screen: the AppShell wraps a section view chosen by
/// [appSectionProvider]. Each section is a placeholder for now and gets
/// filled in subsequent stages.
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final section = ref.watch(appSectionProvider);

    final (header, body) = switch (section) {
      AppSection.myWork =>
        (_HeaderTitle(l.headerMyWork, subtitle: l.headerMyWorkSub), const MyWorkSection()),
      AppSection.allWork =>
        (_HeaderTitle(l.headerAllWork), const TasksWorkspace()),
      AppSection.projects =>
        (_HeaderTitle(l.headerProjects), const ProjectsSection()),
      AppSection.resources =>
        (_HeaderTitle(l.headerResources), _Coming(label: l.comingResources)),
      AppSection.matrix =>
        (_HeaderTitle(l.headerMatrixLoad), const MatrixSection()),
      AppSection.plans =>
        (_HeaderTitle(l.headerPlans, subtitle: l.badgeM2), _Coming(label: l.comingPlanReviewQueue)),
      AppSection.audit =>
        (_HeaderTitle(l.headerAudit), _Coming(label: l.comingChangeLog)),
      AppSection.agents =>
        (_HeaderTitle(l.headerAgents), const AgentsSection()),
      AppSection.settings =>
        (_HeaderTitle(l.headerSettings), const SettingsSection()),
    };

    return AppShell(header: header, child: body);
  }
}

class _HeaderTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _HeaderTitle(this.title, {this.subtitle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (subtitle != null) ...[
          const SizedBox(width: 8),
          Text(
            '· $subtitle',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ],
    );
  }
}

class _Coming extends StatelessWidget {
  final String label;
  const _Coming({required this.label});

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
            Text(label, style: theme.textTheme.titleMedium),
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
