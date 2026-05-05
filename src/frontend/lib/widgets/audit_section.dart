import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../api/api_client.dart' show ChangeLogPage;
import '../l10n/app_localizations.dart';
import '../models/change_log.dart';
import '../models/project.dart';
import '../models/resource.dart';
import '../models/task_hierarchy.dart';
import '../state/providers.dart';

/// Audit feed. Backend ScheduleChangeLog already records every status /
/// IsWaiting / timeline / plan transition; this surface just rolls them
/// up in one place so "who did what when" is answerable without dropping
/// into mongo. Filters: entity type chip + page size cap. Each row
/// resolves the entity to a friendly label (MK-N · title for tasks,
/// project name for projects) by piggy-backing on the providers that
/// already power the rest of the app.
class AuditSection extends ConsumerWidget {
  const AuditSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final filter = ref.watch(auditFilterProvider);
    final logs = ref.watch(auditLogsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.auditSectionLead,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _TypeChip(label: l.auditFilterAll, value: null, current: filter.entityType),
              _TypeChip(label: l.auditFilterTask, value: ChangeEntityType.Task, current: filter.entityType),
              _TypeChip(label: l.auditFilterProject, value: ChangeEntityType.Project, current: filter.entityType),
              _TypeChip(label: l.auditFilterMilestone, value: ChangeEntityType.Milestone, current: filter.entityType),
            ],
          ),
          const SizedBox(height: 12),
          // Detail filters (project / date range / page size / refresh) on
          // their own row so a narrow main pane can wrap them without the
          // entity-type chips disappearing off the edge.
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const _ProjectDropdown(),
              _DateButton(
                label: l.auditFilterFrom,
                value: filter.fromDate,
                onPick: (d) => ref.read(auditFilterProvider.notifier).state =
                    filter.copyWith(fromDate: d, offset: 0),
              ),
              _DateButton(
                label: l.auditFilterTo,
                value: filter.toDate,
                onPick: (d) => ref.read(auditFilterProvider.notifier).state =
                    filter.copyWith(toDate: d, offset: 0),
              ),
              if (filter.fromDate != null || filter.toDate != null || filter.projectId != null)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => ref.read(auditFilterProvider.notifier).state =
                      filter.copyWith(fromDate: null, toDate: null, projectId: null, offset: 0),
                  label: Text(l.auditFilterClear),
                ),
              _LimitDropdown(current: filter.limit),
              IconButton(
                tooltip: l.auditRefresh,
                onPressed: () => ref.invalidate(auditLogsProvider),
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          logs.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(l.errorPrefix(e.toString()))),
            ),
            data: (page) {
              if (page.rows.isEmpty) return const _EmptyState();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LogList(logs: page.rows, total: page.total),
                  const SizedBox(height: 12),
                  _Pager(page: page, filter: filter),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ProjectDropdown extends ConsumerWidget {
  const _ProjectDropdown();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final projects = ref.watch(projectsProvider).asData?.value ?? const <Project>[];
    final filter = ref.watch(auditFilterProvider);
    // Same guard as the matrix filter dropdown: feeding initialValue
    // with an id that doesn't (yet) match any item trips the
    // DropdownButton assertion. Pass null until the list lands.
    final initial = filter.projectId != null && projects.any((p) => p.id == filter.projectId)
        ? filter.projectId
        : null;
    return SizedBox(
      width: 240,
      child: DropdownButtonFormField<String?>(
        initialValue: initial,
        isDense: true,
        // Without isExpanded the Row inside the picker tries to size to
        // the longest project name, blowing past the 240px width when
        // names are long. With it the inner Text falls back to ellipsis.
        isExpanded: true,
        decoration: InputDecoration(
          labelText: l.auditFilterProjectScope,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(l.auditFilterAll)),
          for (final p in projects)
            if (p.id != null)
              DropdownMenuItem<String?>(
                value: p.id,
                child: Text(p.name, overflow: TextOverflow.ellipsis),
              ),
        ],
        onChanged: (v) => ref.read(auditFilterProvider.notifier).state =
            filter.copyWith(projectId: v, offset: 0),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onPick;
  const _DateButton({required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat.yMd();
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today, size: 16),
      label: Text(value == null ? label : '$label · ${fmt.format(value!)}'),
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) onPick(picked);
        // Allow clearing by long-press on the button itself — fall through
        // when null so the parent's clear-all button is the obvious path.
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: value == null ? theme.colorScheme.onSurface : theme.colorScheme.primary,
      ),
    );
  }
}

class _Pager extends ConsumerWidget {
  final ChangeLogPage page;
  final AuditFilter filter;
  const _Pager({required this.page, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    // Page index is 1-based for display only.
    final pageIndex = page.limit == 0 ? 1 : (page.offset ~/ page.limit) + 1;
    final pageCount = page.limit == 0
        ? 1
        : ((page.total + page.limit - 1) ~/ page.limit).clamp(1, 1 << 30);
    final hasPrev = page.offset > 0;
    final hasNext = page.offset + page.rows.length < page.total;

    void go(int newOffset) =>
        ref.read(auditFilterProvider.notifier).state = filter.copyWith(offset: newOffset);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l.auditPageRange(
            page.offset + 1,
            page.offset + page.rows.length,
            page.total,
          ),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: l.auditPagePrev,
              onPressed: hasPrev ? () => go((page.offset - page.limit).clamp(0, 1 << 30)) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              l.auditPageOf(pageIndex, pageCount),
              style: theme.textTheme.bodySmall,
            ),
            IconButton(
              tooltip: l.auditPageNext,
              onPressed: hasNext ? () => go(page.offset + page.limit) : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeChip extends ConsumerWidget {
  final String label;
  final ChangeEntityType? value;
  final ChangeEntityType? current;
  const _TypeChip({required this.label, required this.value, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ChoiceChip(
      label: Text(label),
      selected: current == value,
      onSelected: (_) => ref.read(auditFilterProvider.notifier).state =
          ref.read(auditFilterProvider).copyWith(entityType: value),
    );
  }
}

class _LimitDropdown extends ConsumerWidget {
  final int current;
  const _LimitDropdown({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return DropdownButton<int>(
      value: current,
      items: [
        for (final n in const [50, 100, 200, 500])
          DropdownMenuItem(value: n, child: Text(l.auditLimitN(n))),
      ],
      onChanged: (v) {
        if (v == null) return;
        ref.read(auditFilterProvider.notifier).state =
            ref.read(auditFilterProvider).copyWith(limit: v);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history_toggle_off, size: 32, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(l.auditEmptyTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            l.auditEmptyHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _LogList extends ConsumerWidget {
  final List<ChangeLog> logs;
  final int total;
  const _LogList({required this.logs, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final allHier = ref.watch(allHierarchyByProjectProvider).asData?.value ?? const [];
    final projects = ref.watch(projectsProvider).asData?.value ?? const [];
    final resources = ref.watch(resourcesProvider).asData?.value ?? const [];

    // Build lookup maps once per build instead of nested O(n*m) per row.
    final taskById = <String, TaskHierarchyNode>{};
    final taskProjectName = <String, String>{};
    for (final g in allHier) {
      for (final n in g.nodes) {
        taskById[n.id] = n;
        taskProjectName[n.id] = g.project.name;
      }
    }
    final projectById = {for (final p in projects) p.id ?? '': p};
    final resourceById = {for (final r in resources) r.id ?? '': r};

    final fmt = DateFormat.yMd().add_Hm();

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          for (var i = 0; i < logs.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _LogRow(
              log: logs[i],
              fmt: fmt,
              taskById: taskById,
              taskProjectName: taskProjectName,
              projectById: projectById,
              resourceById: resourceById,
              fallbackChangedBy: l.auditChangedByUnknown,
            ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l.auditCountOf(logs.length, total),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final ChangeLog log;
  final DateFormat fmt;
  final Map<String, TaskHierarchyNode> taskById;
  final Map<String, String> taskProjectName;
  final Map<String, dynamic> projectById;
  final Map<String, Resource> resourceById;
  final String fallbackChangedBy;

  const _LogRow({
    required this.log,
    required this.fmt,
    required this.taskById,
    required this.taskProjectName,
    required this.projectById,
    required this.resourceById,
    required this.fallbackChangedBy,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final (entityLabel, entityHint) = _resolveEntity(l);
    final changedBy = _resolveChangedBy();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _EntityBadge(type: log.entityType),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entityLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                fmt.format(log.changedAt.toLocal()),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
            ],
          ),
          if (entityHint != null) ...[
            const SizedBox(height: 2),
            Text(entityHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
          ],
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '${log.field}: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(
                  text: log.beforeValue ?? l.auditValueNone,
                  style: TextStyle(color: theme.colorScheme.outline),
                ),
                const TextSpan(text: '  →  '),
                TextSpan(text: log.afterValue ?? l.auditValueNone),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 12,
            runSpacing: 2,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_outline, size: 14, color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(changedBy,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                ],
              ),
              if (log.reason != null && log.reason!.trim().isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.subject, size: 14, color: theme.colorScheme.outline),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(log.reason!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  (String label, String? hint) _resolveEntity(AppL10n l) {
    switch (log.entityType) {
      case ChangeEntityType.Task:
        final t = taskById[log.entityId];
        if (t == null) return (l.auditEntityTaskUnknown(log.entityId), null);
        final project = taskProjectName[log.entityId];
        return ('MK-${t.number} · ${t.title}', project);
      case ChangeEntityType.Project:
        final p = projectById[log.entityId];
        if (p == null) return (l.auditEntityProjectUnknown(log.entityId), null);
        return ((p as dynamic).name as String, null);
      case ChangeEntityType.Milestone:
        return (l.auditEntityMilestone(log.entityId), null);
    }
  }

  String _resolveChangedBy() {
    final raw = log.changedBy?.trim();
    if (raw == null || raw.isEmpty) return fallbackChangedBy;
    if (raw == 'system') return raw;
    // Backend currently writes the resource Name into ChangedBy (see
    // TaskRepository / AgentEndpoints), so most rows display as-is.
    // If a resource id slipped through, resolve it to a name.
    final r = resourceById[raw];
    return r?.name ?? raw;
  }
}

class _EntityBadge extends StatelessWidget {
  final ChangeEntityType type;
  const _EntityBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final (color, label) = switch (type) {
      ChangeEntityType.Task => (Colors.blue, l.auditFilterTask),
      ChangeEntityType.Project => (Colors.purple, l.auditFilterProject),
      ChangeEntityType.Milestone => (Colors.teal, l.auditFilterMilestone),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
