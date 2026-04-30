import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/timeline.dart';

enum GanttZoom { day, week, month }

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

/// Gantt rendering with Day / Week / Month zoom levels per
/// wireframes.md §4.3.1. Header has two tiers (top = coarse time band,
/// bottom = unit label). Bars keep a minimum 4px width so sub-unit segments
/// stay visible at coarser zooms.
class GanttChart extends StatelessWidget {
  final List<GanttRow> rows;
  final DateTime? from;
  final DateTime? to;
  final GanttZoom zoom;

  static const double rowHeight = 32;
  static const double headerTopHeight = 22;
  static const double headerBottomHeight = 22;
  static const double labelWidth = 240;

  const GanttChart({
    super.key,
    required this.rows,
    this.from,
    this.to,
    this.zoom = GanttZoom.day,
  });

  double get _cellWidth => switch (zoom) {
        GanttZoom.day => 28,
        GanttZoom.week => 80,
        GanttZoom.month => 120,
      };

  /// Average number of calendar days per cell. Days in months vary so this is
  /// a fractional approximation — fine for visual layout, never used for
  /// task math.
  double get _cellDays => switch (zoom) {
        GanttZoom.day => 1,
        GanttZoom.week => 7,
        GanttZoom.month => 30.4375,
      };

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
    if (rows.isEmpty) return const Center(child: Text('No tasks yet.'));
    final range = _resolveRange();
    if (range == null) {
      return const Center(child: Text('No timeline data yet. Add Current timeline to tasks.'));
    }

    final spanDays = range.to.difference(range.from).inDays.toDouble();
    final timelineWidth = (spanDays / _cellDays) * _cellWidth;
    final headerHeight = headerTopHeight + headerBottomHeight;
    final totalHeight = headerHeight + rowHeight * rows.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: totalHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: _LabelGutter(rows: rows, headerHeight: headerHeight),
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
                        zoom: zoom,
                        cellDays: _cellDays,
                        cellWidth: _cellWidth,
                        rowHeight: rowHeight,
                        headerTopHeight: headerTopHeight,
                        headerBottomHeight: headerBottomHeight,
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

class _LabelGutter extends StatelessWidget {
  final List<GanttRow> rows;
  final double headerHeight;
  const _LabelGutter({required this.rows, required this.headerHeight});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          height: headerHeight,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: const Text('Task', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
        ),
        ...rows.map((r) => Container(
              height: GanttChart.rowHeight,
              padding: EdgeInsets.only(left: 12 + r.depth * 16.0, right: 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3))),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Icon(
                    r.hasChildren ? Icons.folder_open_outlined : Icons.chevron_right,
                    size: 14,
                    color: r.hasChildren ? theme.colorScheme.primary : theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      r.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: r.hasChildren ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
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
  final Color textMuted;

  _Palette({
    required this.grid,
    required this.header,
    required this.origin,
    required this.current,
    required this.real,
    required this.summary,
    required this.text,
    required this.textMuted,
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
      textMuted: cs.outline,
    );
  }
}

class _GanttPainter extends CustomPainter {
  final List<GanttRow> rows;
  final DateTime from;
  final DateTime to;
  final GanttZoom zoom;
  final double cellDays;
  final double cellWidth;
  final double rowHeight;
  final double headerTopHeight;
  final double headerBottomHeight;
  final _Palette palette;

  _GanttPainter({
    required this.rows,
    required this.from,
    required this.to,
    required this.zoom,
    required this.cellDays,
    required this.cellWidth,
    required this.rowHeight,
    required this.headerTopHeight,
    required this.headerBottomHeight,
    required this.palette,
  });

  double _xFromDate(DateTime d) {
    final days = d.toUtc().difference(from).inHours / 24.0;
    return (days / cellDays) * cellWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final headerHeight = headerTopHeight + headerBottomHeight;
    final gridPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;

    // Header background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, headerHeight), Paint()..color = palette.header);

    _drawHeaders(canvas, size);

    // Horizontal divider after header
    canvas.drawLine(
      Offset(0, headerHeight),
      Offset(size.width, headerHeight),
      gridPaint,
    );

    // Row dividers + bars
    for (var r = 0; r < rows.length; r++) {
      final top = headerHeight + rowHeight * r;
      canvas.drawLine(Offset(0, top + rowHeight), Offset(size.width, top + rowHeight), gridPaint);

      final row = rows[r];
      if (row.hasChildren) {
        _drawBar(canvas, row.current.start, row.current.end,
            top: top + 14, height: 8, color: palette.summary, radius: 2);
      } else {
        _drawBar(canvas, row.origin.start, row.origin.end,
            top: top + 4, height: 4, color: palette.origin);
        _drawBar(canvas, row.current.start, row.current.end,
            top: top + 10, height: 14, color: palette.current, radius: 3);
        _drawBar(canvas, row.real.start, row.real.end,
            top: top + 26, height: 4, color: palette.real);
      }
    }
  }

  void _drawHeaders(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;

    switch (zoom) {
      case GanttZoom.day:
        _drawDayHeaders(canvas, size, gridPaint);
        break;
      case GanttZoom.week:
        _drawWeekHeaders(canvas, size, gridPaint);
        break;
      case GanttZoom.month:
        _drawMonthHeaders(canvas, size, gridPaint);
        break;
    }
  }

  void _drawDayHeaders(Canvas canvas, Size size, Paint gridPaint) {
    final dfDay = DateFormat('d');
    final dfMonth = DateFormat('MMM');
    final spanDays = to.difference(from).inDays;

    DateTime? lastMonthDrawn;
    for (var i = 0; i <= spanDays; i++) {
      final x = (i / cellDays) * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      if (i < spanDays) {
        final date = from.add(Duration(days: i));
        // Top tier: month label at first day or month boundary
        if (lastMonthDrawn == null || date.month != lastMonthDrawn.month) {
          _text(canvas, dfMonth.format(date.toLocal()), x + 4, 4,
              fontSize: 11, weight: FontWeight.w600);
          lastMonthDrawn = date;
        }
        // Bottom tier: day number, weekend muted
        final dayColor = (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)
            ? palette.textMuted
            : palette.text;
        _text(canvas, dfDay.format(date.toLocal()), x + 4, headerTopHeight + 4,
            fontSize: 11, color: dayColor);
      }
    }
    canvas.drawLine(Offset(0, headerTopHeight),
        Offset(size.width, headerTopHeight), gridPaint);
  }

  void _drawWeekHeaders(Canvas canvas, Size size, Paint gridPaint) {
    final dfMonth = DateFormat('MMM');
    final spanDays = to.difference(from).inDays;
    final cellCount = (spanDays / cellDays).ceil();

    DateTime? lastMonthDrawn;
    for (var i = 0; i <= cellCount; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      if (i < cellCount) {
        final cellStart = from.add(Duration(days: (i * 7)));
        if (lastMonthDrawn == null || cellStart.month != lastMonthDrawn.month) {
          _text(canvas, dfMonth.format(cellStart.toLocal()), x + 4, 4,
              fontSize: 11, weight: FontWeight.w600);
          lastMonthDrawn = cellStart;
        }
        final week = _isoWeek(cellStart);
        _text(canvas, 'W$week', x + 4, headerTopHeight + 4, fontSize: 11);
      }
    }
    canvas.drawLine(Offset(0, headerTopHeight),
        Offset(size.width, headerTopHeight), gridPaint);
  }

  void _drawMonthHeaders(Canvas canvas, Size size, Paint gridPaint) {
    final dfMonthShort = DateFormat('MMM');
    final spanDays = to.difference(from).inDays;
    final cellCount = (spanDays / cellDays).ceil();

    int? lastQuarter;
    int? lastQuarterYear;
    for (var i = 0; i <= cellCount; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      if (i < cellCount) {
        // Approximate cell start by adding average days/cell.
        final cellStartApprox = from.add(Duration(days: (i * cellDays).round()));
        final quarter = ((cellStartApprox.month - 1) ~/ 3) + 1;
        if (lastQuarter == null ||
            quarter != lastQuarter ||
            cellStartApprox.year != lastQuarterYear) {
          _text(canvas, '${cellStartApprox.year} Q$quarter', x + 4, 4,
              fontSize: 11, weight: FontWeight.w600);
          lastQuarter = quarter;
          lastQuarterYear = cellStartApprox.year;
        }
        _text(canvas, dfMonthShort.format(cellStartApprox.toLocal()),
            x + 4, headerTopHeight + 4, fontSize: 11);
      }
    }
    canvas.drawLine(Offset(0, headerTopHeight),
        Offset(size.width, headerTopHeight), gridPaint);
  }

  /// ISO 8601 week number (1..53).
  int _isoWeek(DateTime date) {
    final thursday = date.add(Duration(days: 4 - (date.weekday == 7 ? 7 : date.weekday)));
    final firstThursday = DateTime.utc(thursday.year, 1, 4);
    final firstWeekStart = firstThursday.subtract(
        Duration(days: firstThursday.weekday - 1));
    return ((thursday.difference(firstWeekStart).inDays) ~/ 7) + 1;
  }

  void _text(
    Canvas canvas,
    String text,
    double x,
    double y, {
    double fontSize = 11,
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color ?? palette.text, fontSize: fontSize, fontWeight: weight),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: cellWidth - 6);
    tp.paint(canvas, Offset(x, y));
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
    final left = _xFromDate(start);
    final right = _xFromDate(end);
    if (right <= 0) return;
    final width = (right - left).clamp(4.0, double.infinity);
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, top, left + width, top + height),
      Radius.circular(radius),
    );
    canvas.drawRRect(rect, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _GanttPainter old) =>
      old.rows != rows ||
      old.from != from ||
      old.to != to ||
      old.zoom != zoom ||
      old.cellWidth != cellWidth;
}
