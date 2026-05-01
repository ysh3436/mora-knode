import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/resource.dart';
import '../state/providers.dart';

/// Dev-mode "logged in as" picker — top of the sidebar, right below the
/// app title. Cycles between human resources so the X-Dev-User-Id header
/// (and therefore RBAC + view scoping on the backend) follows. Per
/// seed-scenarios.md §4 this is a stand-in for token auth that lands in M2.
class UserSwitcher extends ConsumerWidget {
  const UserSwitcher({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final resources = ref.watch(resourcesProvider);
    final currentId = ref.watch(currentUserIdProvider);

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: resources.when(
        loading: () => Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l.userSwitcherLoading, style: const TextStyle(fontSize: 12)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(12),
          child: Text(l.errorPrefix(e.toString()),
              style: const TextStyle(fontSize: 12, color: Colors.redAccent)),
        ),
        data: (all) {
          final humans = all.where((r) => r.kind == ResourceKindFE.human).toList();
          final current = humans.firstWhere(
            (r) => r.id == currentId,
            orElse: () => Resource(name: l.userSwitcherAnonymous, kind: ResourceKindFE.human),
          );
          return PopupMenuButton<String?>(
            tooltip: l.userSwitcherTooltip,
            position: PopupMenuPosition.over,
            onSelected: (id) => ref.read(currentUserIdProvider.notifier).state = id,
            itemBuilder: (ctx) => [
              CheckedPopupMenuItem<String?>(
                value: null,
                checked: currentId == null,
                child: Text(l.userSwitcherAnonymousAdmin),
              ),
              const PopupMenuDivider(),
              ...humans.map((r) => CheckedPopupMenuItem<String?>(
                    value: r.id,
                    checked: r.id == currentId,
                    child: Row(
                      children: [
                        Text(r.name),
                        const SizedBox(width: 8),
                        Text(r.rbac.label,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                  )),
            ],
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: const Icon(Icons.person, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentId == null ? l.userSwitcherAnonymous : current.name,
                          style: theme.textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          currentId == null ? l.userSwitcherAdminCaption : current.rbac.label,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.unfold_more, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
