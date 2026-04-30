import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../task_editor.dart';
import 'all_work_calendar.dart';
import 'all_work_filters.dart';
import 'all_work_gantt.dart';
import 'all_work_list.dart';

/// Container for the All work section. Shared filter bar at the top, sub-tabs
/// (List / Gantt / Calendar) below, then the active subview body.
class AllWorkSection extends ConsumerWidget {
  const AllWorkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(allWorkSubviewProvider);
    final theme = Theme.of(context);
    final l = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            children: [
              SegmentedButton<AllWorkSubview>(
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                ),
                segments: [
                  ButtonSegment(value: AllWorkSubview.list, label: Text(l.tabList), icon: const Icon(Icons.list, size: 16)),
                  ButtonSegment(value: AllWorkSubview.gantt, label: Text(l.tabGantt), icon: const Icon(Icons.view_timeline, size: 16)),
                  ButtonSegment(
                      value: AllWorkSubview.calendar,
                      label: Text(l.tabCalendar),
                      icon: const Icon(Icons.calendar_view_month, size: 16)),
                ],
                selected: {sub},
                onSelectionChanged: (s) => ref.read(allWorkSubviewProvider.notifier).state = s.first,
              ),
              const Spacer(),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: Text(l.newTask),
                onPressed: () => showTaskEditor(context, ref),
              ),
            ],
          ),
        ),
        const AllWorkFilters(),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: switch (sub) {
            AllWorkSubview.list => const AllWorkList(),
            AllWorkSubview.gantt => const AllWorkGantt(),
            AllWorkSubview.calendar => const AllWorkCalendar(),
          },
        ),
      ],
    );
  }
}

