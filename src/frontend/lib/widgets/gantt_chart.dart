import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../models/timeline.dart';

enum GanttZoom { day, week, month }

class GanttRow {
  /// Identifies the underlying entity (e.g., task id) so callers can wire row
  /// clicks to selection. null for purely visual rows like project group
  /// headers — those receive no click affordance.
  final String? id;
  final String title;
  final int depth;
  final bool hasChildren;
  final Timeline origin;
  final Timeline current;
  final Timeline real;

  /// When true, this row's label pins to the top of the label gutter while
  /// its descendants scroll past — like a section header. The next sticky
  /// row pushes the previous one off.
  final bool isStickyHeader;

  const GanttRow({
    this.id,
    required this.title,
    required this.depth,
    required this.hasChildren,
    required this.origin,
    required this.current,
    required this.real,
    this.isStickyHeader = false,
  });
}

/// Gantt rendering with Day / Week / Month zoom levels per
/// wireframes.md §4.3.1. The top date header stays pinned while task rows
/// scroll vertically. Horizontal scroll between header and body is synced.
class GanttChart extends StatefulWidget {
  final List<GanttRow> rows;
  final DateTime? from;
  final DateTime? to;
  final GanttZoom zoom;
  final String? selectedId;
  final void Function(String id)? onRowTap;

  /// IDs of `hasChildren` rows whose subtree is collapsed. Caller is expected
  /// to filter `rows` accordingly; the chart only uses this to render the
  /// chevron state. null disables the toggle entirely.
  final Set<String>? collapsed;
  final void Function(String id)? onToggleCollapse;

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
    this.selectedId,
    this.onRowTap,
    this.collapsed,
    this.onToggleCollapse,
  });

  @override
  State<GanttChart> createState() => _GanttChartState();
}

class _GanttChartState extends State<GanttChart> {
  late final ScrollController _hHeaderCtrl;
  late final ScrollController _hBodyCtrl;
  late final ScrollController _vCtrl;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _hHeaderCtrl = ScrollController();
    _hBodyCtrl = ScrollController();
    _vCtrl = ScrollController();
    // Mirror horizontal offset both ways so dragging the bars area also moves
    // the date header (and vice versa, for completeness).
    _hHeaderCtrl.addListener(() => _mirror(from: _hHeaderCtrl, to: _hBodyCtrl));
    _hBodyCtrl.addListener(() => _mirror(from: _hBodyCtrl, to: _hHeaderCtrl));
  }

  void _mirror({required ScrollController from, required ScrollController to}) {
    if (_syncing || !to.hasClients) return;
    if (from.offset == to.offset) return;
    _syncing = true;
    to.jumpTo(from.offset.clamp(
      to.position.minScrollExtent,
      to.position.maxScrollExtent,
    ));
    _syncing = false;
  }

  @override
  void dispose() {
    _hHeaderCtrl.dispose();
    _hBodyCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  double get _cellWidth => switch (widget.zoom) {
        GanttZoom.day => 28,
        GanttZoom.week => 80,
        GanttZoom.month => 120,
      };

  double get _cellDays => switch (widget.zoom) {
        GanttZoom.day => 1,
        GanttZoom.week => 7,
        GanttZoom.month => 30.4375,
      };

  ({DateTime from, DateTime to})? _resolveRange() {
    if (widget.from != null && widget.to != null) return (from: widget.from!, to: widget.to!);

    DateTime? min;
    DateTime? max;
    for (final r in widget.rows) {
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
    if (widget.rows.isEmpty) return const Center(child: Text('No tasks yet.'));
    final range = _resolveRange();
    if (range == null) {
      return const Center(child: Text('No timeline data yet. Add Current timeline to tasks.'));
    }

    final theme = Theme.of(context);
    final spanDays = range.to.difference(range.from).inDays.toDouble();
    final timelineWidth = (spanDays / _cellDays) * _cellWidth;
    final headerHeight = GanttChart.headerTopHeight + GanttChart.headerBottomHeight;
    final bodyHeight = GanttChart.rowHeight * widget.rows.length;
    final palette = _Palette.from(theme);

    return LayoutBuilder(
      builder: (context, constraints) {
        final timelineAreaWidth = constraints.maxWidth - GanttChart.labelWidth;
        final effectiveTimelineWidth =
            timelineWidth < timelineAreaWidth ? timelineAreaWidth : timelineWidth;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Pinned header strip: "Task" label cell + horizontally-scrollable date row.
            SizedBox(
              height: headerHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: GanttChart.labelWidth,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border(
                        right: BorderSide(color: theme.dividerColor),
                        bottom: BorderSide(color: theme.dividerColor),
                      ),
                    ),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: const Text(
                      'Task',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _hHeaderCtrl,
                      child: SizedBox(
                        width: effectiveTimelineWidth,
                        height: headerHeight,
                        child: CustomPaint(
                          painter: _GanttHeaderPainter(
                            from: range.from,
                            to: range.to,
                            zoom: widget.zoom,
                            cellDays: _cellDays,
                            cellWidth: _cellWidth,
                            headerTopHeight: GanttChart.headerTopHeight,
                            headerBottomHeight: GanttChart.headerBottomHeight,
                            palette: palette,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Body: scrolls vertically. Inside, the timeline area scrolls horizontally.
            // Stack lets us overlay a sticky group label at the top of the
            // label gutter when scrolled past a section header.
            Expanded(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    controller: _vCtrl,
                    child: SizedBox(
                      height: bodyHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: GanttChart.labelWidth,
                            height: bodyHeight,
                            child: _LabelGutter(
                              rows: widget.rows,
                              selectedId: widget.selectedId,
                              onRowTap: widget.onRowTap,
                              collapsed: widget.collapsed,
                              onToggleCollapse: widget.onToggleCollapse,
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _hBodyCtrl,
                              child: SizedBox(
                                width: effectiveTimelineWidth,
                                height: bodyHeight,
                                child: CustomPaint(
                                  painter: _GanttBodyPainter(
                                    rows: widget.rows,
                                    from: range.from,
                                    to: range.to,
                                    cellDays: _cellDays,
                                    cellWidth: _cellWidth,
                                    rowHeight: GanttChart.rowHeight,
                                    palette: palette,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Sticky group label overlay. Sits on top of the label gutter
                  // and shows the active project group while its tasks scroll.
                  Positioned(
                    top: 0,
                    left: 0,
                    width: GanttChart.labelWidth,
                    child: AnimatedBuilder(
                      animation: _vCtrl,
                      builder: (ctx, _) {
                        final off = _vCtrl.hasClients ? _vCtrl.offset : 0.0;
                        return _StickyAncestorStack(
                          rows: widget.rows,
                          rowHeight: GanttChart.rowHeight,
                          scrollOffset: off,
                          collapsed: widget.collapsed,
                          onTap: widget.onRowTap,
                          onToggleCollapse: widget.onToggleCollapse,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Multi-level sticky stack for the label gutter. Walks `rows` forward and
/// maintains a stack of sticky-eligible ancestors of the row currently at
/// scrollOffset, so any parent (project + nested parent tasks) stays pinned
/// while its descendants scroll past. Each slot pushes the one above it up
/// when the next same-depth sibling approaches.
class _StickyAncestorStack extends StatelessWidget {
  final List<GanttRow> rows;
  final double rowHeight;
  final double scrollOffset;
  final Set<String>? collapsed;
  final void Function(String id)? onTap;
  final void Function(String id)? onToggleCollapse;

  const _StickyAncestorStack({
    required this.rows,
    required this.rowHeight,
    required this.scrollOffset,
    required this.collapsed,
    required this.onTap,
    required this.onToggleCollapse,
  });

  /// Standard multi-level sticky algorithm (iOS-Calendar / Slack-channels):
  /// 1. Walk rows in order, building a depth-stack of "in-scope" sticky
  ///    ancestors of the current scroll position.
  /// 2. A sticky row pins when its top has scrolled past the bottom of its
  ///    would-be slot (rTop - slotY <= scrollOffset).
  /// 3. A sticky row pops once its entire subtree is above viewport top.
  /// 4. Refinement: drop a pinned row whose entire subtree is already covered
  ///    by the overlay — the user no longer sees any of its content, so the
  ///    breadcrumb is no longer meaningful.
  List<int> _computeStack() {
    if (rows.isEmpty) return const [];
    final stack = <int>[];

    for (var i = 0; i < rows.length; i++) {
      final r = rows[i];
      final rTop = i * rowHeight;

      while (stack.isNotEmpty) {
        final lastIdx = stack.last;
        final lastEnd = _subtreeEnd(lastIdx) * rowHeight;
        if (scrollOffset >= lastEnd) {
          stack.removeLast();
        } else {
          break;
        }
      }

      if (r.isStickyHeader) {
        if (stack.isNotEmpty && rows[stack.last].depth >= r.depth) break;
        final slotY = stack.length * rowHeight;
        if (scrollOffset >= rTop - slotY) {
          stack.add(i);
        } else {
          break;
        }
      } else {
        if (rTop > scrollOffset) break;
      }
    }

    while (stack.length > 1) {
      final lastIdx = stack.last;
      final lastEnd = _subtreeEnd(lastIdx) * rowHeight;
      final stackHeight = stack.length * rowHeight;
      if (lastEnd > scrollOffset + stackHeight) break;
      stack.removeLast();
    }

    return stack;
  }

  /// Returns idx-just-past-last-descendant (exclusive end) of row [idx].
  int _subtreeEnd(int idx) {
    final d = rows[idx].depth;
    for (var j = idx + 1; j < rows.length; j++) {
      if (rows[j].depth <= d) return j;
    }
    return rows.length;
  }

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final stack = _computeStack();
    if (stack.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    // Push-up: if the *next* sticky-eligible row of equal-or-shallower depth
    // is approaching the bottom slot, slide the whole stack up so the deepest
    // pinned label gets pushed off cleanly as the next one takes its spot.
    double topOffset = 0;
    final deepestDepth = rows[stack.last].depth;
    final stackHeight = stack.length * rowHeight;
    for (var i = stack.last + 1; i < rows.length; i++) {
      if (!rows[i].isStickyHeader) continue;
      if (rows[i].depth > deepestDepth) continue;
      final delta = (i * rowHeight) - scrollOffset;
      if (delta < stackHeight) topOffset = delta - stackHeight;
      break;
    }

    return Transform.translate(
      offset: Offset(0, topOffset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final idx in stack) _stickyRow(theme, rows[idx]),
        ],
      ),
    );
  }

  Widget _stickyRow(ThemeData theme, GanttRow r) {
    final isCollapsed = r.id != null && (collapsed?.contains(r.id) ?? false);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      child: InkWell(
        onTap: r.id != null && onTap != null ? () => onTap!(r.id!) : null,
        child: Container(
          height: rowHeight,
          padding: EdgeInsets.only(left: 8 + r.depth * 14.0, right: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor),
              right: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              if (r.id != null && onToggleCollapse != null)
                InkWell(
                  onTap: () => onToggleCollapse!(r.id!),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      isCollapsed ? Icons.chevron_right : Icons.expand_more,
                      size: 14,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                )
              else
                const SizedBox(width: 18),
              Icon(Icons.folder_open_outlined, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  r.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LabelGutter extends StatelessWidget {
  final List<GanttRow> rows;
  final String? selectedId;
  final void Function(String id)? onRowTap;
  final Set<String>? collapsed;
  final void Function(String id)? onToggleCollapse;
  const _LabelGutter({
    required this.rows,
    this.selectedId,
    this.onRowTap,
    this.collapsed,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        ...rows.map((r) {
          final clickable = r.id != null && onRowTap != null;
          final isSelected = r.id != null && r.id == selectedId;
          final canCollapse = r.hasChildren && r.id != null && onToggleCollapse != null;
          final isCollapsed = canCollapse && (collapsed?.contains(r.id) ?? false);

          final inner = Container(
            height: GanttChart.rowHeight,
            padding: EdgeInsets.only(left: 8 + r.depth * 14.0, right: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.6)
                  : null,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
                right: BorderSide(color: theme.dividerColor),
              ),
            ),
            alignment: Alignment.centerLeft,
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: canCollapse
                      ? InkWell(
                          onTap: () => onToggleCollapse!(r.id!),
                          borderRadius: BorderRadius.circular(4),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              isCollapsed ? Icons.chevron_right : Icons.expand_more,
                              size: 14,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        )
                      : null,
                ),
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
          );
          if (!clickable) return inner;
          return InkWell(onTap: () => onRowTap!(r.id!), child: inner);
        }),
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

class _GanttHeaderPainter extends CustomPainter {
  final DateTime from;
  final DateTime to;
  final GanttZoom zoom;
  final double cellDays;
  final double cellWidth;
  final double headerTopHeight;
  final double headerBottomHeight;
  final _Palette palette;

  _GanttHeaderPainter({
    required this.from,
    required this.to,
    required this.zoom,
    required this.cellDays,
    required this.cellWidth,
    required this.headerTopHeight,
    required this.headerBottomHeight,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final headerHeight = headerTopHeight + headerBottomHeight;
    final gridPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, headerHeight), Paint()..color = palette.header);

    switch (zoom) {
      case GanttZoom.day:
        _drawDay(canvas, size, gridPaint);
        break;
      case GanttZoom.week:
        _drawWeek(canvas, size, gridPaint);
        break;
      case GanttZoom.month:
        _drawMonth(canvas, size, gridPaint);
        break;
    }

    // Top/bottom dividers.
    canvas.drawLine(Offset(0, headerTopHeight), Offset(size.width, headerTopHeight), gridPaint);
    canvas.drawLine(Offset(0, headerHeight - 0.5), Offset(size.width, headerHeight - 0.5),
        Paint()..color = palette.grid.withValues(alpha: 1)..strokeWidth = 1);
  }

  void _drawDay(Canvas canvas, Size size, Paint gridPaint) {
    final dfDay = DateFormat('d');
    final dfMonth = DateFormat('MMM');
    final spanDays = to.difference(from).inDays;

    DateTime? lastMonthDrawn;
    for (var i = 0; i <= spanDays; i++) {
      final x = (i / cellDays) * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      if (i < spanDays) {
        final date = from.add(Duration(days: i));
        if (lastMonthDrawn == null || date.month != lastMonthDrawn.month) {
          _text(canvas, dfMonth.format(date.toLocal()), x + 4, 4,
              fontSize: 11, weight: FontWeight.w600);
          lastMonthDrawn = date;
        }
        final dayColor = (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)
            ? palette.textMuted
            : palette.text;
        _text(canvas, dfDay.format(date.toLocal()), x + 4, headerTopHeight + 4,
            fontSize: 11, color: dayColor);
      }
    }
  }

  void _drawWeek(Canvas canvas, Size size, Paint gridPaint) {
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
  }

  void _drawMonth(Canvas canvas, Size size, Paint gridPaint) {
    final dfMonthShort = DateFormat('MMM');
    final spanDays = to.difference(from).inDays;
    final cellCount = (spanDays / cellDays).ceil();

    int? lastQuarter;
    int? lastQuarterYear;
    for (var i = 0; i <= cellCount; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      if (i < cellCount) {
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

  @override
  bool shouldRepaint(covariant _GanttHeaderPainter old) =>
      old.from != from ||
      old.to != to ||
      old.zoom != zoom ||
      old.cellWidth != cellWidth;
}

class _GanttBodyPainter extends CustomPainter {
  final List<GanttRow> rows;
  final DateTime from;
  final DateTime to;
  final double cellDays;
  final double cellWidth;
  final double rowHeight;
  final _Palette palette;

  _GanttBodyPainter({
    required this.rows,
    required this.from,
    required this.to,
    required this.cellDays,
    required this.cellWidth,
    required this.rowHeight,
    required this.palette,
  });

  double _xFromDate(DateTime d) {
    final days = d.toUtc().difference(from).inHours / 24.0;
    return (days / cellDays) * cellWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = palette.grid
      ..strokeWidth = 1;

    // Vertical column grid lines at every cell. Reuse the date math from header.
    final spanDays = to.difference(from).inDays;
    final cellCount = (spanDays / cellDays).ceil();
    for (var i = 0; i <= cellCount; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    for (var r = 0; r < rows.length; r++) {
      final top = rowHeight * r;
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
  bool shouldRepaint(covariant _GanttBodyPainter old) =>
      old.rows != rows ||
      old.from != from ||
      old.to != to ||
      old.cellWidth != cellWidth;
}
