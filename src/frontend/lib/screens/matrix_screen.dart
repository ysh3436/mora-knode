import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/resource_load.dart';
import '../state/providers.dart';

class MatrixScreen extends ConsumerStatefulWidget {
  const MatrixScreen({super.key});
  @override
  ConsumerState<MatrixScreen> createState() => _MatrixScreenState();
}

class _MatrixScreenState extends ConsumerState<MatrixScreen> {
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final start = DateTime.utc(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    _from = start;
    _to = start.add(const Duration(days: 14));
  }

  @override
  Widget build(BuildContext context) {
    final range = MatrixRange(_from, _to);
    final load = ref.watch(matrixLoadProvider(range));
    final df = DateFormat('M/d');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Matrix Resource Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(matrixLoadProvider(range)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Text('${df.format(_from.toLocal())}  →  ${df.format(_to.toLocal())}'),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.date_range),
                  label: const Text('Change range'),
                  onPressed: _pickRange,
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {
                    final now = DateTime.now();
                    final start = DateTime.utc(now.year, now.month, now.day)
                        .subtract(Duration(days: now.weekday - 1));
                    setState(() {
                      _from = start;
                      _to = start.add(const Duration(days: 14));
                    });
                  },
                  child: const Text('This + next week'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: load.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(child: Text('No resources yet.'));
                }
                return _MatrixTable(rows: rows, from: _from, to: _to);
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 3),
      initialDateRange: DateTimeRange(start: _from.toLocal(), end: _to.toLocal()),
    );
    if (picked != null) {
      setState(() {
        _from = DateTime.utc(picked.start.year, picked.start.month, picked.start.day);
        _to = DateTime.utc(picked.end.year, picked.end.month, picked.end.day);
      });
    }
  }
}

class _MatrixTable extends StatelessWidget {
  final List<ResourceLoad> rows;
  final DateTime from;
  final DateTime to;
  const _MatrixTable({required this.rows, required this.from, required this.to});

  static const double nameColWidth = 180;
  static const double cellWidth = 44;
  static const double cellHeight = 40;
  static const double headerHeight = 28;

  @override
  Widget build(BuildContext context) {
    final days = to.difference(from).inDays;
    final df = DateFormat('M/d');
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: nameColWidth + days * cellWidth + 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  SizedBox(
                    width: nameColWidth,
                    child: Container(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      color: cs.surfaceContainerHighest,
                      child: const Text('Resource', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  ...List.generate(days, (i) {
                    final d = from.add(Duration(days: i));
                    final isWeekend = d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;
                    return Container(
                      width: cellWidth,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isWeekend
                            ? cs.surfaceContainerHighest.withValues(alpha: 0.5)
                            : cs.surfaceContainerHighest,
                        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      child: Text(df.format(d.toLocal()), style: const TextStyle(fontSize: 11)),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: 1),
            // Rows
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: rows.map((r) {
                    return SizedBox(
                      height: cellHeight,
                      child: Row(
                        children: [
                          SizedBox(
                            width: nameColWidth,
                            child: Container(
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(r.resourceName, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(
                                    '${r.resourceRole ?? '—'} · ${r.capacityPercent}%',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ...r.days.map((bucket) => _LoadCell(bucket: bucket, capacity: r.capacityPercent)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadCell extends StatelessWidget {
  final ResourceLoadBucket bucket;
  final int capacity;
  const _LoadCell({required this.bucket, required this.capacity});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = bucket.loadPercent;
    Color bg;
    if (pct == 0) {
      bg = Colors.transparent;
    } else if (bucket.overloaded) {
      bg = cs.error.withValues(alpha: 0.7);
    } else if (pct >= capacity * 0.75) {
      bg = cs.primary.withValues(alpha: 0.55);
    } else if (pct >= capacity * 0.4) {
      bg = cs.primary.withValues(alpha: 0.35);
    } else {
      bg = cs.primary.withValues(alpha: 0.18);
    }

    return Container(
      width: _MatrixTable.cellWidth,
      height: _MatrixTable.cellHeight,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          left: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
          bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.4)),
        ),
      ),
      alignment: Alignment.center,
      child: pct == 0
          ? const SizedBox.shrink()
          : Text(
              '$pct',
              style: TextStyle(
                color: bucket.overloaded ? cs.onError : cs.onSurface,
                fontSize: 11,
                fontWeight: bucket.overloaded ? FontWeight.bold : FontWeight.normal,
              ),
            ),
    );
  }
}
