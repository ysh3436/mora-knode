import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import 'all_work_filters.dart';
import 'all_work_list.dart';

/// Container for the All work section. Shared filter bar at the top, sub-tabs
/// (List / Gantt / Calendar) below, then the active subview body.
class AllWorkSection extends ConsumerWidget {
  const AllWorkSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sub = ref.watch(allWorkSubviewProvider);
    final theme = Theme.of(context);

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
                segments: const [
                  ButtonSegment(value: AllWorkSubview.list, label: Text('List'), icon: Icon(Icons.list, size: 16)),
                  ButtonSegment(value: AllWorkSubview.gantt, label: Text('Gantt'), icon: Icon(Icons.view_timeline, size: 16)),
                  ButtonSegment(
                      value: AllWorkSubview.calendar,
                      label: Text('Calendar'),
                      icon: Icon(Icons.calendar_view_month, size: 16)),
                ],
                selected: {sub},
                onSelectionChanged: (s) => ref.read(allWorkSubviewProvider.notifier).state = s.first,
              ),
            ],
          ),
        ),
        const AllWorkFilters(),
        Divider(height: 1, color: theme.dividerColor),
        Expanded(
          child: switch (sub) {
            AllWorkSubview.list => const AllWorkList(),
            AllWorkSubview.gantt => const _Stub(label: 'Gantt — coming next'),
            AllWorkSubview.calendar => const _Stub(label: 'Calendar — coming next'),
          },
        ),
      ],
    );
  }
}

class _Stub extends StatelessWidget {
  final String label;
  const _Stub({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Text(label,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline)),
    );
  }
}
