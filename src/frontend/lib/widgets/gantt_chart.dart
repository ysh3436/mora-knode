import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/timeline.dart';

class GanttRow {
  final String title;
  final int depth;
  final bool hasChildren;
  final Timeline origin;
  final Timeline current;
  final Timeline real;

  const GanttRow({
    required this.title,
    required this.depth,
    required this.hasChildren,
    required this.origin,
    required this.current,
    required this.real,
  });
}

class GanttChart extends StatelessWidget {
  final List<GanttRow> rows;
  final DateTime? from;
  final DateTime? to;
  static const double rowHeight = 40;
  static const double headerHeight = 36;
  static const double labelWidth = 240;
  static const double dayWidth = 24;

  const GanttChart({super.key, required this.rows, this.from, this.to});

  ({DateTime from, DateTime to})? _resolveRange() {
    if (from != null && to != null) return (from: from!, to: to!);

    DateTime? min;
    DateTime? max;
    for (final r in rows) {
      for (final tl in [r.origin, r.current, r.real]) {
        if (tl.start != null && (min == null || tl.start!.isBefore(min))) min = tl.start;
        if (tl.end != null && (max == null || tl.end!.isAfter(max))) max = tl.end;
      }
    }
    if (min == null || max == null) return null;
    final f = DateTime.utc(min.year, min.month, min.day);
    final t = DateTime.utc(max.year, max.month, max.day).add(const Duration(days: 1));
    return (from: f, to: t);
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(child: Text('No tasks yet.'));
    }
    final range = _resolveRange();
    if (range == null) {
      return const Center(child: Text('No timeline data yet. Add Current timeline to tasks.'));
    }

    final days = range.to.difference(range.from).inDays;
    final totalHeight = headerHeight + rowHeight * rows.length;
    final timelineWidth = days * dayWidth;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: totalHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Column(
                  children: [
                    Container(
                      height: headerHeight,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                      child: const Text('Task', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    ...rows.map((r) => Container(
                          height: rowHeight,
                          padding: EdgeInsets.only(left: 12 + r.depth * 16.0, right: 12),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3))),
                          ),
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Icon(
                                r.hasChildren ? Icons.folder_open_outlined : Icons.chevron_right,
                                size: 16,
                                color: r.hasChildren
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.outline,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  r.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: r.hasChildren
                                      ? const TextStyle(fontWeight: FontWeight.w600)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: timelineWidth < constraints.maxWidth - labelWidth
                        ? constraints.maxWidth - labelWidth
                        : timelineWidth,
                    height: totalHeight,
                    child: CustomPaint(
                      painter: _GanttPainter(
                        rows: rows,
                        from: range.from,
                        to: range.to,
                        rowHeight: rowHeight,
                        headerHeight: headerHeight,
                        dayWidth: dayWidth,
                        palette: _Palette.from(Theme.of(context)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Palette {
  final Color grid;
  final Color header;
  final Color origin;
  final Color current;
  final Color real;
  final Color summary;
  final Color text;

  _Palette({
    required this.grid,
    required this.header,
    required this.origin,
    required this.current,
    required this.real,
    required this.summary,
    required this.text,
  });

  factory _Palette.from(ThemeData theme) {
    final cs = theme.colorScheme;
    return _Palette(
      grid: theme.dividerColor.withValues(alpha: 0.3),
      header: cs.surfaceContainerHighest,
      origin: cs.outline.withValues(alpha: 0.45),
      current: cs.primary.withValues(alpha: 0.85),
      real: cs.tertiary.withValues(alpha: 0.95),
      summary: cs.secondary.withValues(alpha: 0.75),
      text: cs.onSurface,
    );
  }
}

class _GanttPainter extends CustomPainter {
  final List<GanttRow> rows;
  final DateTime from;
  final DateTime to;
  final double rowHeight;
  final double headerHeight;
  final double dayWidth;
  final _Palette palette;

  _GanttPainter({
    required this.rows,
    required this.from,
    required this.to,
    required this.rowHeight,
    required this.headerHeight,
    required this.dayWidth,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final days = to.difference(from).inDays;
    final gridPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;

    final headerPaint = Paint()..color = palette.header;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, headerHeight), headerPaint);

    final df = DateFormat('M/d');
    for (var i = 0; i <= days; i++) {
      final x = i * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      if (i < days) {
        final date = from.add(Duration(days: i));
        final isWeekStart = date.weekday == DateTime.monday || i == 0;
        if (isWeekStart) {
          final tp = TextPainter(
            text: TextSpan(
              text: df.format(date.toLocal()),
              style: TextStyle(color: palette.text, fontSize: 11),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(x + 4, 4));
        }
      }
    }

    canvas.drawLine(
      Offset(0, headerHeight),
      Offset(size.width, headerHeight),
      gridPaint..color = palette.grid,
    );

    for (var r = 0; r < rows.length; r++) {
      final top = headerHeight + rowHeight * r;
      canvas.drawLine(Offset(0, top + rowHeight), Offset(size.width, top + rowHeight), gridPaint);

      final row = rows[r];
      if (row.hasChildren) {
        // Parent summary bar: single slim bar spanning the computed union range.
        _drawBar(canvas, row.current.start, row.current.end,
            top: top + 16, height: 10, color: palette.summary, radius: 3);
        // Thin bracket ticks at both ends
        _drawBracket(canvas, row.current.start, row.current.end, top: top + 16, height: 10);
      } else {
        // Leaf task: full 3-layer bars.
        _drawBar(canvas, row.origin.start, row.origin.end,
            top: top + 6, height: 6, color: palette.origin);
        _drawBar(canvas, row.current.start, row.current.end,
            top: top + 14, height: 16, color: palette.current, radius: 3);
        _drawBar(canvas, row.real.start, row.real.end,
            top: top + 32, height: 4, color: palette.real);
      }
    }
  }

  void _drawBar(
    Canvas canvas,
    DateTime? start,
    DateTime? end, {
    required double top,
    required double height,
    required Color color,
    double radius = 2,
  }) {
    if (start == null || end == null) return;
    final s = _daysSince(start);
    final e = _daysSince(end);
    if (e <= 0 || s >= to.difference(from).inDays) return;
    final clampedS = s.clamp(0, to.difference(from).inDays).toDouble();
    final clampedE = e.clamp(0, to.difference(from).inDays).toDouble();
    final left = clampedS * dayWidth;
    final right = clampedE * dayWidth;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, top, right, top + height),
      Radius.circular(radius),
    );
    canvas.drawRRect(rect, Paint()..color = color);
  }

  void _drawBracket(Canvas canvas, DateTime? start, DateTime? end,
      {required double top, required double height}) {
    if (start == null || end == null) return;
    final s = _daysSince(start).clamp(0, to.difference(from).inDays).toDouble();
    final e = _daysSince(end).clamp(0, to.difference(from).inDays).toDouble();
    final paint = Paint()
      ..color = palette.summary
      ..strokeWidth = 2;
    final left = s * dayWidth;
    final right = e * dayWidth;
    final midY = top + height / 2;
    canvas.drawLine(Offset(left, midY - 4), Offset(left, midY + 4), paint);
    canvas.drawLine(Offset(right, midY - 4), Offset(right, midY + 4), paint);
  }

  double _daysSince(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day).difference(from).inDays.toDouble();

  @override
  bool shouldRepaint(covariant _GanttPainter old) =>
      old.rows != rows || old.from != from || old.to != to;
}
