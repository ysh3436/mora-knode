import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/timeline.dart';

/// Anchor-positioned all-day date-range picker — Linear / Notion style.
/// Shows a small floating calendar next to the tapped row instead of a full
/// dialog covering the workspace. Supports the very common "당일 (1일)"
/// case naturally: a single click sets start = end and the user just hits
/// 저장 to commit; a second click extends the end of the range.
///
/// Caller passes the [context] of the tapped widget — the popover is
/// positioned relative to that widget's global bounds and flips above /
/// below depending on available room.
Future<Timeline?> showInlineDateRangePopover(BuildContext context, Timeline current) {
  final renderBox = context.findRenderObject() as RenderBox?;
  if (renderBox == null) return Future.value(null);
  final overlay = Overlay.of(context);
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final anchorOrigin = renderBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final anchorSize = renderBox.size;

  final completer = Completer<Timeline?>();
  late OverlayEntry entry;

  void close(Timeline? value) {
    if (entry.mounted) entry.remove();
    if (!completer.isCompleted) completer.complete(value);
  }

  entry = OverlayEntry(
    builder: (ctx) => _PopoverHost(
      anchorOrigin: anchorOrigin,
      anchorSize: anchorSize,
      overlaySize: overlayBox.size,
      initial: current,
      onConfirm: (t) => close(t),
      onCancel: () => close(null),
    ),
  );
  overlay.insert(entry);
  return completer.future;
}

class _PopoverHost extends StatefulWidget {
  final Offset anchorOrigin;
  final Size anchorSize;
  final Size overlaySize;
  final Timeline initial;
  final ValueChanged<Timeline> onConfirm;
  final VoidCallback onCancel;

  const _PopoverHost({
    required this.anchorOrigin,
    required this.anchorSize,
    required this.overlaySize,
    required this.initial,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_PopoverHost> createState() => _PopoverHostState();
}

class _PopoverHostState extends State<_PopoverHost> {
  static const double _kPopoverWidth = 320;
  static const double _kPopoverHeight = 360;

  late DateTime? _start;
  late DateTime? _end;
  late DateTime _viewMonth;
  bool _hasFirstClick = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _start = widget.initial.start?.toLocal();
    _end = widget.initial.end?.toLocal();
    _viewMonth = DateTime(
      (_start ?? DateTime.now()).year,
      (_start ?? DateTime.now()).month,
      1,
    );
    _hasFirstClick = _start != null;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _pickDate(DateTime d) {
    setState(() {
      // Strip to local midnight for clean comparison.
      final picked = DateTime(d.year, d.month, d.day);
      if (!_hasFirstClick || _start == null) {
        _start = picked;
        _end = picked;
        _hasFirstClick = true;
      } else if (picked.isBefore(_start!)) {
        // Clicking before the current start re-anchors the start (and resets end to single-day).
        _start = picked;
        _end = picked;
      } else {
        // Extend end (or shrink, if user clicked between start and current end).
        _end = picked;
      }
    });
  }

  void _confirm() {
    if (_start == null || _end == null) {
      widget.onCancel();
      return;
    }
    widget.onConfirm(Timeline(
      start: DateTime.utc(_start!.year, _start!.month, _start!.day),
      end: DateTime.utc(_end!.year, _end!.month, _end!.day),
      isAllDay: true,
    ));
  }

  Offset _resolvePosition() {
    // Prefer below the anchor; flip above if it would overflow.
    const gap = 6.0;
    final preferTop = widget.anchorOrigin.dy + widget.anchorSize.height + gap;
    final spaceBelow = widget.overlaySize.height - preferTop;
    final dy = spaceBelow >= _kPopoverHeight
        ? preferTop
        : (widget.anchorOrigin.dy - _kPopoverHeight - gap).clamp(8.0, widget.overlaySize.height);
    final dx = widget.anchorOrigin.dx
        .clamp(8.0, (widget.overlaySize.width - _kPopoverWidth - 8).clamp(8.0, double.infinity));
    return Offset(dx.toDouble(), dy.toDouble());
  }

  @override
  Widget build(BuildContext context) {
    final pos = _resolvePosition();
    final theme = Theme.of(context);
    return Stack(
      children: [
        // Tap-outside scrim — fully transparent but absorbs taps so the
        // user can dismiss without committing.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onCancel,
            child: const SizedBox.expand(),
          ),
        ),
        Positioned(
          left: pos.dx,
          top: pos.dy,
          width: _kPopoverWidth,
          child: Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
                widget.onCancel();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: theme.colorScheme.surface,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: _kPopoverHeight),
                child: _CalendarBody(
                  viewMonth: _viewMonth,
                  start: _start,
                  end: _end,
                  onPick: _pickDate,
                  onPrevMonth: () => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month - 1, 1)),
                  onNextMonth: () => setState(() => _viewMonth = DateTime(_viewMonth.year, _viewMonth.month + 1, 1)),
                  onClear: () => setState(() {
                    _start = null;
                    _end = null;
                    _hasFirstClick = false;
                  }),
                  onConfirm: _confirm,
                  onCancel: widget.onCancel,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CalendarBody extends StatelessWidget {
  final DateTime viewMonth;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onPrevMonth;
  final VoidCallback onNextMonth;
  final VoidCallback onClear;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  const _CalendarBody({
    required this.viewMonth,
    required this.start,
    required this.end,
    required this.onPick,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onClear,
    required this.onConfirm,
    required this.onCancel,
  });

  String _summary(BuildContext context) {
    final df = DateFormat.yMMMd(dateLocale(context));
    if (start == null && end == null) return '—';
    if (start != null && end != null) {
      final days = end!.difference(start!).inDays + 1;
      if (days == 1) return '${df.format(start!)} · 당일';
      return '${df.format(start!)} → ${df.format(end!)} · $days일';
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthFmt = DateFormat.yMMMM(dateLocale(context));
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Range summary row
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 6),
            child: Text(
              _summary(context),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          // Month nav
          Row(
            children: [
              IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left),
                onPressed: onPrevMonth,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    monthFmt.format(viewMonth),
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              IconButton(
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right),
                onPressed: onNextMonth,
              ),
            ],
          ),
          // Weekday header (Mon-Sun, Korean color cues)
          _WeekdayHeader(),
          // 6-row calendar grid
          _Grid(
            viewMonth: viewMonth,
            start: start,
            end: end,
            onPick: onPick,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: onClear,
                child: Text(l.actionClear),
              ),
              const Spacer(),
              TextButton(
                onPressed: onCancel,
                child: Text(l.actionCancel),
              ),
              FilledButton(
                onPressed: (start == null || end == null) ? null : onConfirm,
                child: Text(l.actionSave),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Mon ... Sun. Use a fixed reference Monday so DateFormat.E renders
    // localized weekday short names regardless of current date.
    final ref = DateTime(2024, 1, 1); // Monday
    final fmt = DateFormat.E(dateLocale(context));
    return Row(
      children: List.generate(7, (i) {
        final d = ref.add(Duration(days: i));
        Color? color;
        if (d.weekday == DateTime.saturday) color = const Color(0xFF1976D2);
        if (d.weekday == DateTime.sunday) color = const Color(0xFFE53935);
        return Expanded(
          child: Center(
            child: Text(
              fmt.format(d),
              style: theme.textTheme.bodySmall?.copyWith(
                color: color ?? theme.colorScheme.outline,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _Grid extends StatelessWidget {
  final DateTime viewMonth;
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onPick;
  const _Grid({required this.viewMonth, required this.start, required this.end, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // First weekday of the displayed month (1=Mon..7=Sun).
    final firstOfMonth = DateTime(viewMonth.year, viewMonth.month, 1);
    final leadBlanks = firstOfMonth.weekday - DateTime.monday; // 0..6
    final gridStart = firstOfMonth.subtract(Duration(days: leadBlanks));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(6, (week) {
        return Row(
          children: List.generate(7, (dow) {
            final d = gridStart.add(Duration(days: week * 7 + dow));
            final inMonth = d.month == viewMonth.month;
            final today = DateTime.now();
            final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
            final isStart = start != null && _sameDay(d, start!);
            final isEnd = end != null && _sameDay(d, end!);
            final inRange = start != null &&
                end != null &&
                !d.isBefore(start!) &&
                !d.isAfter(end!);
            Color? bg;
            Color? fg;
            if (isStart || isEnd) {
              bg = theme.colorScheme.primary;
              fg = theme.colorScheme.onPrimary;
            } else if (inRange) {
              bg = theme.colorScheme.primaryContainer;
              fg = theme.colorScheme.onPrimaryContainer;
            } else {
              fg = inMonth
                  ? (d.weekday == DateTime.sunday
                      ? const Color(0xFFE53935)
                      : d.weekday == DateTime.saturday
                          ? const Color(0xFF1976D2)
                          : theme.colorScheme.onSurface)
                  : theme.colorScheme.outline;
            }
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => onPick(d),
                  child: Container(
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(4),
                      border: isToday && bg == null
                          ? Border.all(color: theme.colorScheme.primary, width: 1)
                          : null,
                    ),
                    child: Text(
                      '${d.day}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: fg,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      }),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
