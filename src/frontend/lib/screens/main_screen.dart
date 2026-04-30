import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import '../widgets/all_work/all_work_section.dart';
import '../widgets/app_shell.dart';

/// Top-level screen: the AppShell wraps a section view chosen by
/// [appSectionProvider]. Each section is a placeholder for now and gets
/// filled in subsequent stages.
class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(appSectionProvider);

    final (header, body) = switch (section) {
      AppSection.myWork =>
        (_HeaderTitle('My work', subtitle: 'this week'), _Coming(label: 'My work')),
      AppSection.allWork =>
        (_HeaderTitle('All work'), const AllWorkSection()),
      AppSection.projects =>
        (_HeaderTitle('Projects'), _Coming(label: 'Projects directory')),
      AppSection.resources =>
        (_HeaderTitle('Resources'), _Coming(label: 'Resources')),
      AppSection.matrix =>
        (_HeaderTitle('Matrix load'), _Coming(label: 'Resource matrix')),
      AppSection.plans =>
        (_HeaderTitle('Plans', subtitle: 'M2'), _Coming(label: 'Plan review queue (M2)')),
      AppSection.audit =>
        (_HeaderTitle('Audit'), _Coming(label: 'Change log')),
      AppSection.agents =>
        (_HeaderTitle('Agents', subtitle: 'M2'), _Coming(label: 'Agent identity & RBAC (M2)')),
      AppSection.settings =>
        (_HeaderTitle('Settings'), _Coming(label: 'WorkCalendar + preferences')),
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
              'Coming in the next stage of the redesign.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
