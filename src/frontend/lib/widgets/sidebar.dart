import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'user_switcher.dart';

/// Left rail. Top-level sections + a collapsible Projects subtree.
/// Bottom edge holds the dev user switcher.
class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final section = ref.watch(appSectionProvider);
    final projects = ref.watch(projectsProvider);
    final isAdmin = ref.watch(isAdminProvider);

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              children: [
                Icon(Icons.hub, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('mora-knode', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _NavItem(
                  icon: Icons.inbox,
                  label: 'My work',
                  selected: section == AppSection.myWork,
                  onTap: () => ref.read(appSectionProvider.notifier).state = AppSection.myWork,
                ),
                _NavItem(
                  icon: Icons.list_alt,
                  label: 'All work',
                  selected: section == AppSection.allWork,
                  onTap: () => ref.read(appSectionProvider.notifier).state = AppSection.allWork,
                ),
                _ExpandableProjects(
                  selected: section == AppSection.projects,
                  onSectionTap: () => ref.read(appSectionProvider.notifier).state = AppSection.projects,
                  projects: projects,
                  onPick: (id) {
                    ref.read(appSectionProvider.notifier).state = AppSection.projects;
                    ref.read(inspectionProvider.notifier).state = ProjectInspection(id);
                    ref.read(inspectorOpenProvider.notifier).state = true;
                  },
                ),
                _NavItem(
                  icon: Icons.people,
                  label: 'Resources',
                  selected: section == AppSection.resources,
                  onTap: () => ref.read(appSectionProvider.notifier).state = AppSection.resources,
                ),
                _NavItem(
                  icon: Icons.grid_view,
                  label: 'Matrix',
                  selected: section == AppSection.matrix,
                  onTap: () => ref.read(appSectionProvider.notifier).state = AppSection.matrix,
                ),
                _NavItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Plans',
                  selected: section == AppSection.plans,
                  badge: 'M2',
                  onTap: () => ref.read(appSectionProvider.notifier).state = AppSection.plans,
                ),
                _NavItem(
                  icon: Icons.history,
                  label: 'Audit',
                  selected: section == AppSection.audit,
                  onTap: () => ref.read(appSectionProvider.notifier).state = AppSection.audit,
                ),
                _NavItem(
                  icon: Icons.smart_toy_outlined,
                  label: 'Agents',
                  selected: section == AppSection.agents,
                  badge: 'M2',
                  onTap: () => ref.read(appSectionProvider.notifier).state = AppSection.agents,
                ),
                if (isAdmin) ...[
                  const Divider(),
                  _NavItem(
                    icon: Icons.settings_outlined,
                    label: 'Settings',
                    selected: section == AppSection.settings,
                    onTap: () => ref.read(appSectionProvider.notifier).state = AppSection.settings,
                  ),
                ],
              ],
            ),
          ),
          const UserSwitcher(),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      child: Material(
        color: selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Icon(icon, size: 18, color: selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurface),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 10, color: theme.colorScheme.outline),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExpandableProjects extends ConsumerStatefulWidget {
  final bool selected;
  final VoidCallback onSectionTap;
  final AsyncValue<dynamic> projects;
  final void Function(String projectId) onPick;

  const _ExpandableProjects({
    required this.selected,
    required this.onSectionTap,
    required this.projects,
    required this.onPick,
  });

  @override
  ConsumerState<_ExpandableProjects> createState() => _ExpandableProjectsState();
}

class _ExpandableProjectsState extends ConsumerState<_ExpandableProjects> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final list = widget.projects.asData?.value as List<dynamic>? ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          child: Material(
            color: widget.selected ? theme.colorScheme.secondaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: widget.onSectionTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => setState(() => _expanded = !_expanded),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          _expanded ? Icons.expand_more : Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.folder_outlined, size: 18,
                        color: widget.selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurface),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Projects',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w400,
                          color: widget.selected ? theme.colorScheme.onSecondaryContainer : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      '${list.length}',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_expanded)
          ...list.map((p) {
            final id = (p as dynamic).id as String?;
            final name = (p).name as String;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: id == null ? null : () => widget.onPick(id),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(38, 4, 10, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        name,
                        style: theme.textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}
