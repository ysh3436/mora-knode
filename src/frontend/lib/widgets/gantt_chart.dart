import 'package:flutter/gestures.dart'
    show
        GestureBinding,
        PointerDeviceKind,
        PointerPanZoomUpdateEvent,
        PointerScrollEvent,
        PointerSignalEvent;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../l10n/app_localizations.dart';
import '../models/holiday.dart';
import '../models/timeline.dart';

/// On Flutter Web the default ScrollBehavior excludes mouse and trackpad
/// from `dragDevices`, so two-finger horizontal trackpad swipes and
/// click-and-drag on the timeline don't initiate a scroll until something
/// inside the scroll surface has been clicked once. Re-adding both here
/// makes horizontal panning work from first paint without needing focus.
class _GanttScrollBehavior extends MaterialScrollBehavior {
  const _GanttScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

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

  /// Date to horizontally center after layout. The chart scrolls so this
  /// date lands at the viewport midpoint on first layout and whenever this
  /// value changes (parent passes a fresh DateTime when the user requests
  /// a re-center, e.g. by pressing "Today"). Defaults to "today" when null
  /// on first mount so the user lands near current work without panning.
  final DateTime? centerOn;

  /// Holiday lookup map keyed by `holidayKey(date)` — supplied by the parent
  /// (TasksGantt) which watches `holidaysProvider`. Empty map means "no
  /// holidays registered"; the chart renders weekend colors only.
  final Map<int, Holiday> holidays;

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
    this.centerOn,
    this.holidays = const {},
  });

  @override
  State<GanttChart> createState() => _GanttChartState();
}

class _GanttChartState extends State<GanttChart> {
  late final ScrollController _hHeaderCtrl;
  late final ScrollController _hBodyCtrl;
  late final ScrollController _vCtrl;
  bool _syncing = false;
  bool _initialCenterDone = false;

  // Tracks the date the cursor is over within the header strip. Only set when
  // the date is a Korean holiday — otherwise null so the tooltip overlay
  // stays hidden. The cell-x position is recomputed on every hover, so the
  // tooltip follows the pointer across days.
  ({DateTime date, double cellLeftPx, Holiday holiday})? _hoverHoliday;

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

  @override
  void didUpdateWidget(GanttChart old) {
    super.didUpdateWidget(old);
    final centerChanged = widget.centerOn != null && widget.centerOn != old.centerOn;
    final zoomChanged = widget.zoom != old.zoom;

    if (centerChanged) {
      // Today button (or any explicit centerOn caller) wins outright.
      _scheduleCenter(widget.centerOn!);
      return;
    }
    if (zoomChanged) {
      // Anchor the viewport-center date across zoom changes — feels stable
      // because the spot the user was looking at stays put. Without this
      // the same pixel offset would map to a different date under the new
      // cellWidth, snapping the view to a random region.
      final centerDate = _viewportCenterDate(old.zoom);
      if (centerDate != null) {
        _scheduleCenter(centerDate);
      }
    }
  }

  /// Date currently sitting at the horizontal center of the viewport,
  /// computed using the supplied [zoom] (so callers in [didUpdateWidget]
  /// can pass the *previous* zoom before the new cellWidth applies).
  /// Returns null when the controller hasn't laid out yet.
  DateTime? _viewportCenterDate(GanttZoom zoom) {
    if (!_hBodyCtrl.hasClients) return null;
    final position = _hBodyCtrl.position;
    if (!position.haveDimensions) return null;
    final viewport = position.viewportDimension;
    if (viewport <= 0) return null;
    final centerPx = _hBodyCtrl.offset + viewport / 2;
    final pixelsPerDay = _cellWidthFor(zoom) / _cellDaysFor(zoom);
    if (pixelsPerDay <= 0) return null;
    final virtual = _virtualRange(_resolveDataRange());
    final daysFromStart = centerPx / pixelsPerDay;
    return virtual.from.add(Duration(seconds: (daysFromStart * 86400).round()));
  }

  /// Scrolls the timeline body horizontally so [target] lands at the viewport
  /// midpoint. Computed against the virtual range (today ±5y, expanded for
  /// data outliers) so any reasonable date sits inside the scrollable extent.
  void _scheduleCenter(DateTime target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_hBodyCtrl.hasClients) return;
      final virtual = _virtualRange(_resolveDataRange());
      final viewport = _hBodyCtrl.position.viewportDimension;
      if (viewport <= 0) return;
      final maxOffset = _hBodyCtrl.position.maxScrollExtent;

      final daysFromStart = target.difference(virtual.from).inDays.toDouble();
      final x = (daysFromStart / _cellDays) * _cellWidth;
      final offset = (x - viewport / 2).clamp(0.0, maxOffset);
      _hBodyCtrl.jumpTo(offset);
    });
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

  /// Routes horizontal-dominant pointer scroll events (trackpad two-finger
  /// horizontal swipe, shift+wheel) to `_hBodyCtrl`. On Flutter Web the
  /// outer vertical SingleChildScrollView often absorbs these events before
  /// the inner horizontal one can, leaving panning unresponsive until the
  /// widget tree gets rebuilt by an unrelated button press.
  ///
  /// Claims the event via [PointerSignalResolver] so the parent Scrollable
  /// can't also act on the same delta — prevents double-scroll when both
  /// the workaround and Flutter's default routing happen to fire.
  void _routeHorizontalScroll(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!_hBodyCtrl.hasClients) return;
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    if (dx.abs() <= dy.abs()) return; // vertical-dominant; let outer handle.
    GestureBinding.instance.pointerSignalResolver.register(event, (e) {
      final pe = e as PointerScrollEvent;
      final next = (_hBodyCtrl.offset + pe.scrollDelta.dx)
          .clamp(0.0, _hBodyCtrl.position.maxScrollExtent);
      _hBodyCtrl.jumpTo(next);
    });
  }

  /// Trackpad pan-zoom updates arrive as a separate event stream from
  /// pointer signals. Some Flutter Web setups deliver horizontal trackpad
  /// gestures as PointerPanZoom rather than PointerScroll, so we route
  /// them too. `panDelta.dx > 0` means the user moved fingers right, which
  /// in scroll terms means "show what's to the left" → offset decreases.
  void _routePanZoom(PointerPanZoomUpdateEvent event) {
    if (!_hBodyCtrl.hasClients) return;
    final dx = event.panDelta.dx;
    final dy = event.panDelta.dy;
    if (dx.abs() <= dy.abs()) return;
    final next = (_hBodyCtrl.offset - dx)
        .clamp(0.0, _hBodyCtrl.position.maxScrollExtent);
    _hBodyCtrl.jumpTo(next);
  }

  /// Updates `_hoverHoliday` based on the cursor's local x inside the header
  /// strip. Only triggers a rebuild when the hovered holiday actually
  /// changes — moving across a non-holiday cell is a no-op so we don't
  /// rebuild on every mouse-move pixel.
  void _onHeaderHover(double localX, DateTime virtualFrom) {
    final pixelsPerDay = _cellWidth / _cellDays;
    if (pixelsPerDay <= 0) return;
    final daysFromStart = (localX / pixelsPerDay).floor();
    final date = virtualFrom.add(Duration(days: daysFromStart));
    final holiday = widget.holidays[date.year * 10000 + date.month * 100 + date.day];
    if (holiday == null) {
      if (_hoverHoliday != null) {
        setState(() => _hoverHoliday = null);
      }
      return;
    }
    final cellLeftPx = (daysFromStart / _cellDays) * _cellWidth;
    if (_hoverHoliday?.date == date) return; // same cell, no rebuild
    setState(() => _hoverHoliday = (
          date: date,
          cellLeftPx: cellLeftPx,
          holiday: holiday,
        ));
  }

  void _clearHover() {
    if (_hoverHoliday != null) setState(() => _hoverHoliday = null);
  }

  @override
  void dispose() {
    _hHeaderCtrl.dispose();
    _hBodyCtrl.dispose();
    _vCtrl.dispose();
    super.dispose();
  }

  double get _cellWidth => _cellWidthFor(widget.zoom);
  double get _cellDays => _cellDaysFor(widget.zoom);

  // Standalone variants so `didUpdateWidget` can resolve cell metrics for
  // the *previous* zoom (needed to translate the user's pre-rebuild scroll
  // offset back to a date).
  static double _cellWidthFor(GanttZoom z) => switch (z) {
        GanttZoom.day => 28,
        GanttZoom.week => 80,
        GanttZoom.month => 120,
      };

  static double _cellDaysFor(GanttZoom z) => switch (z) {
        GanttZoom.day => 1,
        GanttZoom.week => 7,
        GanttZoom.month => 30.4375,
      };

  /// Full union of all task timelines. Used to expand the virtual range so
  /// any data outlier sits inside the always-scrollable area.
  ({DateTime from, DateTime to})? _resolveDataRange() {
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

  /// Far bounds of the always-scrollable timeline. Always covers ±5 years
  /// from today, expanded so any task data sits inside. Replaces the prior
  /// "window + extend on edge" model — the user pans freely throughout this
  /// range from first paint without needing to trigger window growth.
  ({DateTime from, DateTime to}) _virtualRange(({DateTime from, DateTime to})? data) {
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    var from = today.subtract(const Duration(days: 365 * 5));
    var to = today.add(const Duration(days: 365 * 5));
    if (data != null) {
      if (data.from.isBefore(from)) from = data.from.subtract(const Duration(days: 365));
      if (data.to.isAfter(to)) to = data.to.add(const Duration(days: 365));
    }
    return (from: from, to: to);
  }

  /// Per-row off-screen markers — one or two `_RowArrow` widgets per row
  /// when its currentTimeline lies entirely past the *visible viewport*
  /// (not the rendered window). Updates as the user pans horizontally so
  /// arrows appear when a bar scrolls out of view and disappear when it
  /// scrolls back in. Tap pans the viewport one screenful in that
  /// direction; the auto-extend listener grows the window if the user
  /// reaches its edge.
  List<Widget> _rowOffScreenArrows(
    GanttRow row,
    int index,
    double vOff,
    ({DateTime from, DateTime to}) viewport,
  ) {
    final t = row.current;
    final hasLeft = t.end != null && t.end!.isBefore(viewport.from);
    final hasRight = t.start != null && t.start!.isAfter(viewport.to);
    if (!hasLeft && !hasRight) return const [];

    final y = GanttChart.rowHeight * index - vOff;
    // Cull rows the user can't see anyway.
    if (y < -GanttChart.rowHeight || y > 4000) return const [];
    final centerY = y + (GanttChart.rowHeight - 18) / 2;

    final out = <Widget>[];
    if (hasLeft) {
      out.add(Positioned(
        left: 8,
        top: centerY,
        child: _RowArrow(
          toLeft: true,
          onTap: () => _scrollToRowBar(row),
        ),
      ));
    }
    if (hasRight) {
      // Inset further on the right so the arrow doesn't sit underneath
      // the vertical scrollbar's gutter (~12px on most platforms).
      out.add(Positioned(
        right: 18,
        top: centerY,
        child: _RowArrow(
          toLeft: false,
          onTap: () => _scrollToRowBar(row),
        ),
      ));
    }
    return out;
  }

  /// Jumps the timeline so this row's bar lands centered in the viewport.
  /// The virtual range already covers any reasonable date, so no window
  /// extension dance — just convert the bar's date to a pixel offset and
  /// animate.
  void _scrollToRowBar(GanttRow row) {
    if (!_hBodyCtrl.hasClients) return;
    final t = row.current;
    final barDate = t.start ?? t.end;
    if (barDate == null) return;
    final virtual = _virtualRange(_resolveDataRange());
    final viewport = _hBodyCtrl.position.viewportDimension;
    if (viewport <= 0) return;
    final daysFromStart = barDate.difference(virtual.from).inDays.toDouble();
    final x = (daysFromStart / _cellDays) * _cellWidth;
    final target =
        (x - viewport / 2).clamp(0.0, _hBodyCtrl.position.maxScrollExtent);
    _hBodyCtrl.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    if (widget.rows.isEmpty) return Center(child: Text(l.ganttNoTasks));
    final data = _resolveDataRange();
    final range = _virtualRange(data);
    // First non-empty build: center on the requested date (or today) once
    // layout settles. Subsequent re-centers go through didUpdateWidget.
    if (!_initialCenterDone) {
      _initialCenterDone = true;
      _scheduleCenter(widget.centerOn ?? DateTime.now());
    }

    final theme = Theme.of(context);
    final spanDays = range.to.difference(range.from).inDays.toDouble();
    final timelineWidth = (spanDays / _cellDays) * _cellWidth;
    final headerHeight = GanttChart.headerTopHeight + GanttChart.headerBottomHeight;
    final bodyHeight = GanttChart.rowHeight * widget.rows.length;
    final palette = _Palette.from(theme);
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);

    return Focus(
      autofocus: true,
      child: ScrollConfiguration(
      behavior: const _GanttScrollBehavior(),
      child: LayoutBuilder(
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
                    child: Text(
                      l.ganttColTask,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          controller: _hHeaderCtrl,
                          child: Listener(
                            onPointerSignal: _routeHorizontalScroll,
                            onPointerPanZoomUpdate: _routePanZoom,
                            child: MouseRegion(
                              onHover: (e) => _onHeaderHover(e.localPosition.dx, range.from),
                              onExit: (_) => _clearHover(),
                              child: SizedBox(
                                width: effectiveTimelineWidth,
                                height: headerHeight,
                                child: AnimatedBuilder(
                                  animation: _hHeaderCtrl,
                                  builder: (ctx, _) {
                                    final ready = _hHeaderCtrl.hasClients &&
                                        _hHeaderCtrl.position.haveDimensions;
                                    final off = ready ? _hHeaderCtrl.offset : 0.0;
                                    final viewport = ready
                                        ? _hHeaderCtrl.position.viewportDimension
                                        : effectiveTimelineWidth;
                                    return CustomPaint(
                                      painter: _GanttHeaderPainter(
                                        from: range.from,
                                        to: range.to,
                                        zoom: widget.zoom,
                                        cellDays: _cellDays,
                                        cellWidth: _cellWidth,
                                        headerTopHeight: GanttChart.headerTopHeight,
                                        headerBottomHeight: GanttChart.headerBottomHeight,
                                        palette: palette,
                                        locale: Localizations.localeOf(context).toLanguageTag(),
                                        today: today,
                                        visibleFromPx: off,
                                        visibleToPx: off + viewport,
                                        holidays: widget.holidays,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Holiday name tooltip — overlays into the top row of
                        // the header strip (the month-name area) which is
                        // mostly empty, instead of sitting below the header.
                        // Sits outside the SingleChildScrollView so it
                        // doesn't scroll horizontally; we compute its
                        // absolute x from the cursor's day cell minus the
                        // current scroll.
                        if (_hoverHoliday != null)
                          AnimatedBuilder(
                            animation: _hHeaderCtrl,
                            builder: (ctx, _) {
                              final hOff = _hHeaderCtrl.hasClients
                                  ? _hHeaderCtrl.offset
                                  : 0.0;
                              final hover = _hoverHoliday!;
                              final cellPx = _cellWidth / _cellDays;
                              // Center of the hovered day cell, in viewport
                              // pixels. FractionalTranslation shifts the
                              // tooltip left by half its own width so the
                              // tooltip is truly centered regardless of how
                              // long the holiday name is.
                              final cellCenter = hover.cellLeftPx - hOff + cellPx / 2;
                              return Positioned(
                                top: 0,
                                left: cellCenter,
                                child: FractionalTranslation(
                                  translation: const Offset(-0.5, 0),
                                  child: IgnorePointer(
                                    child: _HolidayTooltip(name: hover.holiday.name),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
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
                              child: Listener(
                                onPointerSignal: _routeHorizontalScroll,
                                onPointerPanZoomUpdate: _routePanZoom,
                                child: SizedBox(
                                  width: effectiveTimelineWidth,
                                  height: bodyHeight,
                                  child: AnimatedBuilder(
                                    animation: _hBodyCtrl,
                                    builder: (ctx, _) {
                                      final ready = _hBodyCtrl.hasClients &&
                                          _hBodyCtrl.position.haveDimensions;
                                      final off = ready ? _hBodyCtrl.offset : 0.0;
                                      final viewport = ready
                                          ? _hBodyCtrl.position.viewportDimension
                                          : effectiveTimelineWidth;
                                      return CustomPaint(
                                        painter: _GanttBodyPainter(
                                          rows: widget.rows,
                                          from: range.from,
                                          to: range.to,
                                          cellDays: _cellDays,
                                          cellWidth: _cellWidth,
                                          rowHeight: GanttChart.rowHeight,
                                          palette: palette,
                                          today: today,
                                          visibleFromPx: off,
                                          visibleToPx: off + viewport,
                                        ),
                                      );
                                    },
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
                  // Per-row off-screen arrows — anchored at the timeline area
                  // edges (not inside the horizontal scroll, so they stay
                  // visible as the user pans). Vertical position mirrors
                  // `_vCtrl`; horizontal scroll updates the visible date
                  // range so arrows appear/disappear as the user pans across
                  // the timeline (not just when extending the window).
                  Positioned(
                    left: GanttChart.labelWidth,
                    top: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRect(
                      child: AnimatedBuilder(
                        animation: Listenable.merge([_vCtrl, _hBodyCtrl]),
                        builder: (ctx, _) {
                          // Both controllers must be attached AND measured
                          // before we can compute scroll offsets / viewport
                          // size. Otherwise `.offset` and
                          // `.viewportDimension` throw "accessed before set"
                          // on the very first frame after attach.
                          final hReady = _hBodyCtrl.hasClients &&
                              _hBodyCtrl.position.haveDimensions;
                          final vReady = _vCtrl.hasClients &&
                              _vCtrl.position.haveDimensions;
                          if (!hReady && !vReady) {
                            return const SizedBox.shrink();
                          }
                          final vOff = vReady ? _vCtrl.offset : 0.0;
                          final hOff = hReady ? _hBodyCtrl.offset : 0.0;
                          final viewportPx =
                              hReady ? _hBodyCtrl.position.viewportDimension : 0.0;
                          // Translate scroll offset → date range visible to
                          // the user right now. Used in place of the static
                          // window range so arrows follow horizontal panning.
                          final pixelsPerDay = _cellWidth / _cellDays;
                          final viewport = pixelsPerDay > 0 && viewportPx > 0
                              ? (
                                  from: range.from.add(Duration(
                                      seconds: (hOff / pixelsPerDay * 86400).round())),
                                  to: range.from.add(Duration(
                                      seconds:
                                          ((hOff + viewportPx) / pixelsPerDay * 86400).round())),
                                )
                              : range;
                          return Stack(
                            children: [
                              for (var i = 0; i < widget.rows.length; i++)
                                ..._rowOffScreenArrows(widget.rows[i], i, vOff, viewport),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
    ),
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
  final Color today;
  /// Saturday day-number color — Korean convention uses a distinct blue.
  final Color saturday;
  /// Sunday + Korean public holiday day-number color — red, the cultural cue.
  final Color holiday;

  _Palette({
    required this.grid,
    required this.header,
    required this.origin,
    required this.current,
    required this.real,
    required this.summary,
    required this.text,
    required this.textMuted,
    required this.today,
    required this.saturday,
    required this.holiday,
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
      // Soft primary tint covers the full day-column under today — same idiom
      // as GitHub Projects / Linear. Distinct from current/real bar fills
      // (which use the same primary at higher opacity).
      today: cs.primary.withValues(alpha: 0.14),
      // Korean calendar idiom: blue for Saturday, red for Sunday + holidays.
      // Picked direct CSS colors instead of theme channels so the cue stays
      // recognizable even under tinted theme variants.
      saturday: const Color(0xFF1976D2),
      holiday: const Color(0xFFE53935),
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
  final String locale;
  final DateTime today;
  // Pixel bounds of the user's currently visible viewport into the
  // (potentially huge) virtual timeline. The painter only iterates cells
  // inside this slice (+ a small buffer) instead of the entire ±5y span,
  // keeping per-frame work proportional to viewport size.
  final double visibleFromPx;
  final double visibleToPx;
  /// Date → Holiday lookup (key = year*10000+month*100+day). Empty when no
  /// subscriptions are configured.
  final Map<int, Holiday> holidays;

  _GanttHeaderPainter({
    required this.from,
    required this.to,
    required this.zoom,
    required this.cellDays,
    required this.cellWidth,
    required this.headerTopHeight,
    required this.headerBottomHeight,
    required this.palette,
    required this.locale,
    required this.today,
    required this.visibleFromPx,
    required this.visibleToPx,
    required this.holidays,
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

    // Today highlight — full day-column tint under the date header. Width is
    // always one day's pixels regardless of zoom (so coarse zooms get a
    // narrow precise band, fine zooms get a full-cell tint).
    final todayX = _todayX(size);
    if (todayX != null) {
      final dayPx = cellWidth / cellDays;
      canvas.drawRect(
        Rect.fromLTWH(todayX, 0, dayPx, headerHeight),
        Paint()..color = palette.today,
      );
    }

    // Top/bottom dividers.
    canvas.drawLine(Offset(0, headerTopHeight), Offset(size.width, headerTopHeight), gridPaint);
    canvas.drawLine(Offset(0, headerHeight - 0.5), Offset(size.width, headerHeight - 0.5),
        Paint()..color = palette.grid.withValues(alpha: 1)..strokeWidth = 1);
  }

  /// Pixel x of today's column inside this painter, or null if today is
  /// outside [from, to). Compares UTC y/m/d to match how `from` is computed.
  double? _todayX(Size size) {
    final daysFromStart = today.difference(from).inDays.toDouble();
    if (daysFromStart < 0) return null;
    final x = (daysFromStart / cellDays) * cellWidth;
    if (x < 0 || x > size.width) return null;
    return x;
  }

  /// Inclusive cell-index bounds of the current viewport. Buffer of 2 cells
  /// each side hides the seam during fling momentum without inflating cost.
  ({int start, int end}) _visibleCells(int totalCells) {
    final visStart = ((visibleFromPx / cellWidth).floor() - 2).clamp(0, totalCells);
    final visEnd = ((visibleToPx / cellWidth).ceil() + 2).clamp(0, totalCells);
    return (start: visStart, end: visEnd);
  }

  void _drawDay(Canvas canvas, Size size, Paint gridPaint) {
    // intl treats single-char pattern 'd' as a *skeleton*, which CLDR expands
    // with the locale's day-unit (Korean: "1일"). For a calendar grid the
    // column position already implies "this is a day", so we want the bare
    // numeral in every locale. NumberFormat.decimalPattern is what Flutter's
    // own CalendarDatePicker uses (via MaterialLocalizations.formatDecimal):
    // gives ASCII digits in ko/en/ja/zh and the locale's native digits in
    // Arabic/Persian/Hindi without the day-unit getting glued on.
    final dfMonth = DateFormat('MMM', locale);
    final dayFmt = NumberFormat.decimalPattern(locale);
    final spanDays = to.difference(from).inDays;
    final vis = _visibleCells(spanDays);

    DateTime? lastMonthDrawn;
    for (var i = vis.start; i <= vis.end; i++) {
      final x = (i / cellDays) * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      if (i < spanDays) {
        final date = from.add(Duration(days: i));
        if (lastMonthDrawn == null || date.month != lastMonthDrawn.month) {
          _text(canvas, dfMonth.format(date.toLocal()), x + 4, 4,
              fontSize: 11, weight: FontWeight.w600);
          lastMonthDrawn = date;
        }
        final dayColor = _dayColor(date);
        _text(canvas, dayFmt.format(date.toLocal().day), x + 4, headerTopHeight + 4,
            fontSize: 11, color: dayColor);
      }
    }
  }

  /// Korean calendar coloring: holiday and Sunday → red, Saturday → blue.
  /// Holiday wins over weekday so a holiday-on-Saturday still reads red.
  Color _dayColor(DateTime date) {
    final key = date.year * 10000 + date.month * 100 + date.day;
    if (holidays.containsKey(key)) return palette.holiday;
    if (date.weekday == DateTime.sunday) return palette.holiday;
    if (date.weekday == DateTime.saturday) return palette.saturday;
    return palette.text;
  }

  void _drawWeek(Canvas canvas, Size size, Paint gridPaint) {
    final dfMonth = DateFormat('MMM', locale);
    final spanDays = to.difference(from).inDays;
    final cellCount = (spanDays / cellDays).ceil();
    final vis = _visibleCells(cellCount);

    DateTime? lastMonthDrawn;
    for (var i = vis.start; i <= vis.end; i++) {
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
    final dfMonthShort = DateFormat('MMM', locale);
    final spanDays = to.difference(from).inDays;
    final cellCount = (spanDays / cellDays).ceil();

    final vis = _visibleCells(cellCount);
    int? lastQuarter;
    int? lastQuarterYear;
    for (var i = vis.start; i <= vis.end; i++) {
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
      old.cellWidth != cellWidth ||
      old.locale != locale ||
      old.today != today ||
      old.visibleFromPx != visibleFromPx ||
      old.visibleToPx != visibleToPx ||
      !identical(old.holidays, holidays);
}

class _GanttBodyPainter extends CustomPainter {
  final List<GanttRow> rows;
  final DateTime from;
  final DateTime to;
  final double cellDays;
  final double cellWidth;
  final double rowHeight;
  final _Palette palette;
  final DateTime today;
  // Pixel bounds of the user's currently visible viewport into the virtual
  // timeline. Painter only iterates cells + draws bars within this slice
  // (plus a small buffer) so a 10-year virtual extent doesn't cost 3650
  // grid-line draws and bar-bound checks per frame.
  final double visibleFromPx;
  final double visibleToPx;

  _GanttBodyPainter({
    required this.rows,
    required this.from,
    required this.to,
    required this.cellDays,
    required this.cellWidth,
    required this.rowHeight,
    required this.palette,
    required this.today,
    required this.visibleFromPx,
    required this.visibleToPx,
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

    // Vertical column grid lines — only the cells inside the viewport
    // (with a 2-cell buffer) get drawn.
    final spanDays = to.difference(from).inDays;
    final cellCount = (spanDays / cellDays).ceil();
    final visStart = ((visibleFromPx / cellWidth).floor() - 2).clamp(0, cellCount);
    final visEnd = ((visibleToPx / cellWidth).ceil() + 2).clamp(0, cellCount);
    for (var i = visStart; i <= visEnd; i++) {
      final x = i * cellWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Today highlight — full day-column tint under bars so they stay readable
    // on top. Width matches one day's pixels (same as header).
    final daysFromStart = today.difference(from).inDays.toDouble();
    if (daysFromStart >= 0) {
      final todayX = (daysFromStart / cellDays) * cellWidth;
      if (todayX >= 0 && todayX <= size.width) {
        final dayPx = cellWidth / cellDays;
        canvas.drawRect(
          Rect.fromLTWH(todayX, 0, dayPx, size.height),
          Paint()..color = palette.today,
        );
      }
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
    // Cull bars entirely outside the current viewport — biggest savings
    // since the virtual timeline spans years.
    if (right < visibleFromPx - 100 || left > visibleToPx + 100) return;
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
      old.visibleFromPx != visibleFromPx ||
      old.visibleToPx != visibleToPx ||
      old.cellWidth != cellWidth ||
      old.today != today;
}

/// Floating chip that surfaces the Korean holiday name for the cell the
/// cursor is currently hovering. Mirrors the visual weight of a Material
/// Tooltip — opaque background, single-line text — without the built-in
/// hover-delay (we want it to follow the pointer immediately).
class _HolidayTooltip extends StatelessWidget {
  final String name;
  const _HolidayTooltip({required this.name});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.inverseSurface,
      borderRadius: BorderRadius.circular(4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onInverseSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Per-row off-screen marker. Sits at the left or right edge of the
/// timeline area on a row whose bar lies entirely outside the active
/// display window. The chevron tells the user "your task is this way";
/// tapping extends the window one unit in that direction so the next
/// batch of off-screen tasks comes into view.
class _RowArrow extends StatelessWidget {
  final bool toLeft;
  final VoidCallback onTap;
  const _RowArrow({required this.toLeft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Icon(
            toLeft ? Icons.chevron_left : Icons.chevron_right,
            size: 14,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
