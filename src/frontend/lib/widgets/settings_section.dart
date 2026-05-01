import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:intl/intl.dart' show DateFormat;

import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
import '../models/holiday.dart';
import '../models/work_calendar.dart';
import '../state/providers.dart';

/// Settings section. WorkCalendar editor is the M1 entry; non-admin users
/// (Developer / QA) see a permission-blocked message because the same gate
/// is enforced visually in the sidebar (this is a defense-in-depth
/// fallback when settings is reached via deep link or section state).
class SettingsSection extends ConsumerWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final theme = Theme.of(context);
    final l = AppL10n.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _LanguageCard(),
          const SizedBox(height: 16),
          const _ThemeCard(),
          if (!isAdmin) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border.all(color: theme.dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, size: 32, color: theme.colorScheme.outline),
                  const SizedBox(height: 12),
                  Text(l.settingsAdminOnlyTitle, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(
                    l.settingsAdminOnlyHint,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 24),
            const _WorkCalendarEditor(),
            const SizedBox(height: 32),
            const _HolidaySourcesEditor(kind: HolidayKind.holiday),
            const SizedBox(height: 24),
            const _HolidaySourcesEditor(kind: HolidayKind.observance),
          ],
        ],
      ),
    );
  }
}

class _LanguageCard extends ConsumerWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final locale = ref.watch(localeProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.translate, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(l.settingsLanguage, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.settingsLanguageHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            // Fixed-width labels so the button group width stays stable when
            // the selected language changes — otherwise the segments resize
            // and visibly shift surrounding layout.
            segments: [
              ButtonSegment(value: 'ko', label: SizedBox(width: 60, child: Text(l.languageKorean, textAlign: TextAlign.center))),
              ButtonSegment(value: 'en', label: SizedBox(width: 60, child: Text(l.languageEnglish, textAlign: TextAlign.center))),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (s) =>
                ref.read(localeProvider.notifier).state = Locale(s.first),
          ),
        ],
      ),
    );
  }
}

/// Theme picker. Lives in Settings (not the sidebar) because the per-frame
/// rebuild cost during Material's animated theme transition is noticeable
/// when the gantt is on screen — burying the toggle behind a settings click
/// keeps that cost out of frequent paths. Default is dark for long dev
/// sessions.
class _ThemeCard extends ConsumerWidget {
  const _ThemeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final mode = ref.watch(themeModeProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                switch (mode) {
                  ThemeMode.system => Icons.brightness_auto,
                  ThemeMode.light => Icons.light_mode_outlined,
                  ThemeMode.dark => Icons.dark_mode_outlined,
                },
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(l.settingsTheme, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            // Fixed-width labels so the button group width stays stable across
            // ko ↔ en switches (시스템/라이트/다크 vs System/Light/Dark differ
            // enough to visibly shift surrounding layout otherwise).
            segments: [
              ButtonSegment(
                value: ThemeMode.system,
                label: SizedBox(width: 56, child: Text(l.themeSystem, textAlign: TextAlign.center)),
                icon: const Icon(Icons.brightness_auto, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: SizedBox(width: 56, child: Text(l.themeLight, textAlign: TextAlign.center)),
                icon: const Icon(Icons.light_mode_outlined, size: 16),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: SizedBox(width: 56, child: Text(l.themeDark, textAlign: TextAlign.center)),
                icon: const Icon(Icons.dark_mode_outlined, size: 16),
              ),
            ],
            selected: {mode},
            onSelectionChanged: (s) =>
                ref.read(themeModeProvider.notifier).state = s.first,
          ),
        ],
      ),
    );
  }
}

class _WorkCalendarEditor extends ConsumerStatefulWidget {
  const _WorkCalendarEditor();

  @override
  ConsumerState<_WorkCalendarEditor> createState() => _WorkCalendarEditorState();
}

class _WorkCalendarEditorState extends ConsumerState<_WorkCalendarEditor> {
  WorkCalendar? _draft;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loaded = ref.watch(workCalendarProvider);

    final l = AppL10n.of(context);
    return loaded.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(l.errorPrefix(e.toString()))),
      data: (resp) {
        // Initialize the draft on first paint, or after a save.
        _draft ??= resp.calendar;
        final draft = _draft!;
        final isFallback = resp.isFallback && !_isDirty(resp.calendar);

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFallback)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l.settingsWorkCalendarFallback,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              Text(l.settingsWorkCalendar, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                l.settingsWorkCalendarHint,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 24),
              _section(theme, l.settingsWorkDays),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: WorkDays.ordered.map((entry) {
                  final selected = (draft.workDays & entry.$2) != 0;
                  return FilterChip(
                    label: Text(workDayLabel(context, entry.$1)),
                    selected: selected,
                    onSelected: (s) {
                      setState(() {
                        _draft = draft.copyWith(
                          workDays: s ? (draft.workDays | entry.$2) : (draft.workDays & ~entry.$2),
                        );
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              _section(theme, l.settingsDailyHoursLocal),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TimeField(
                    label: l.settingsTimeStart,
                    minutes: draft.dailyStartMinutes,
                    onPick: (m) => setState(() => _draft = draft.copyWith(dailyStartMinutes: m)),
                  ),
                  const SizedBox(width: 24),
                  _TimeField(
                    label: l.settingsTimeEnd,
                    minutes: draft.dailyEndMinutes,
                    onPick: (m) => setState(() => _draft = draft.copyWith(dailyEndMinutes: m)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _section(theme, l.settingsTimezone),
              const SizedBox(height: 8),
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    hintText: l.settingsTimezoneHint,
                  ),
                  controller: TextEditingController(text: draft.timezone)
                    ..selection = TextSelection.collapsed(offset: draft.timezone.length),
                  onChanged: (v) => _draft = draft.copyWith(timezone: v),
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  FilledButton(
                    onPressed: _saving || !_isValid(draft) ? null : () => _save(),
                    child: Text(_saving ? l.actionSaving : l.actionSave),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _saving ? null : () => setState(() => _draft = resp.calendar),
                    child: Text(l.actionReset),
                  ),
                  const Spacer(),
                  if (_isDirty(resp.calendar))
                    Text(
                      l.stateUnsavedChanges,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  bool _isDirty(WorkCalendar saved) {
    final d = _draft;
    if (d == null) return false;
    return d.workDays != saved.workDays ||
        d.dailyStartMinutes != saved.dailyStartMinutes ||
        d.dailyEndMinutes != saved.dailyEndMinutes ||
        d.timezone != saved.timezone;
  }

  bool _isValid(WorkCalendar d) =>
      d.dailyEndMinutes > d.dailyStartMinutes &&
      d.dailyStartMinutes >= 0 &&
      d.dailyEndMinutes <= 24 * 60 &&
      d.timezone.trim().isNotEmpty;

  Future<void> _save() async {
    final d = _draft;
    if (d == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).updateWorkCalendar(d);
      ref.invalidate(workCalendarProvider);
      // Matrix load and calendar week view depend on the calendar; refetch
      // them so the next render reflects the new work hours.
      ref.invalidate(matrixLoadProvider);
    } catch (e) {
      setState(() {
        _error = 'Failed to save: $e';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _section(ThemeData theme, String title) => Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
          color: theme.colorScheme.outline,
        ),
      );
}

class _TimeField extends StatelessWidget {
  final String label;
  final int minutes;
  final void Function(int minutes) onPick;
  const _TimeField({required this.label, required this.minutes, required this.onPick});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final text = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          icon: const Icon(Icons.access_time, size: 16),
          label: Text(text, style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
          onPressed: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: h, minute: m),
              initialEntryMode: TimePickerEntryMode.input,
            );
            if (picked != null) onPick(picked.hour * 60 + picked.minute);
          },
        ),
      ],
    );
  }
}

/// One-click presets so users don't have to look up well-known .ics URLs.
/// Holiday-section presets cover legal public holidays for major locales.
/// Add more as we identify trustworthy public feeds.
const _holidayPresetsHoliday = <({String name, String url})>[
  (
    name: '한국 공휴일 (Google)',
    url:
        'https://calendar.google.com/calendar/ical/ko.south_korea%23holiday%40group.v.calendar.google.com/public/basic.ics',
  ),
];

/// Observance presets — 절기·기념일 등 표시 전용. 사용자가 본인 GitHub Pages
/// 등에 .ics 호스팅 후 일반 추가 흐름으로 등록하는 게 기본 시나리오라 현재
/// preset 비어있음. 신뢰할 만한 공개 .ics 가 확인되면 추가.
const _holidayPresetsObservance = <({String name, String url})>[];

/// Settings section for managing iCalendar holiday subscriptions. One
/// instance per [HolidayKind] — the kind determines section title, default
/// kind for new subscriptions added here, list filter, and which preset
/// chips show. Lists each source with last-fetch status, supports add
/// (via preset or custom URL), edit (rename, change URL), delete, and
/// on-demand refresh. Backend fetches each .ics on add + on-demand and
/// exposes the merged result via /api/holidays for the gantt + calendar.
class _HolidaySourcesEditor extends ConsumerWidget {
  final HolidayKind kind;
  const _HolidaySourcesEditor({required this.kind});

  bool get _isHoliday => kind == HolidayKind.holiday;

  String get _title => _isHoliday ? '공휴일 / 휴무일 구독' : '절기 / 기념일 표시 구독';

  IconData get _icon => _isHoliday ? Icons.calendar_month : Icons.event_note;

  String get _hint => _isHoliday
      ? '.ics 캘린더 URL을 등록하면 그 일정의 휴일/기념일이 간트와 캘린더에 빨간색으로 표시됩니다. '
          '회사·국가·팀별로 여러 개 추가 가능.'
      : '.ics URL을 등록하면 셀 색상은 그대로 두고 회색 라벨로만 표시됩니다. '
          '24절기, 회사 기념일 등 휴무는 아니지만 표시하고 싶은 일자.';

  String get _emptyHint => _isHoliday
      ? '아래 preset 으로 한 번에 추가하거나 "구독 추가" 버튼으로 직접 URL을 입력하세요.'
      : '"구독 추가" 버튼으로 .ics URL을 직접 등록하세요. (예: 본인 GitHub Pages 호스팅 .ics)';

  List<({String name, String url})> get _presets =>
      _isHoliday ? _holidayPresetsHoliday : _holidayPresetsObservance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sources = ref.watch(holidaySourcesProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_icon, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(_title, style: theme.textTheme.titleMedium),
              const Spacer(),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('구독 추가'),
                onPressed: () => _openAddDialog(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _hint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
          const SizedBox(height: 16),
          sources.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '구독 목록을 불러오지 못했습니다: $e',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
            data: (full) {
              final list = full.where((s) => s.kind == kind).toList();
              if (list.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '아직 구독이 없습니다.',
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _emptyHint,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  for (final s in list) _SourceRow(source: s),
                ],
              );
            },
          ),
          if (_presets.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('빠른 추가', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final preset in _presets)
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 14),
                    label: Text(preset.name),
                    onPressed: () => _addSource(
                      ref,
                      HolidaySource(name: preset.name, url: preset.url, kind: kind),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _openAddDialog(BuildContext context, WidgetRef ref) {
    final nameC = TextEditingController();
    final urlC = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_isHoliday ? '새 공휴일 구독 추가' : '새 표시 구독 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: InputDecoration(
                labelText: '이름',
                hintText: _isHoliday ? '예: 우리회사 휴무일' : '예: 24절기',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlC,
              decoration: const InputDecoration(
                labelText: '.ics URL',
                hintText: 'https://...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              if (urlC.text.trim().isEmpty) return;
              _addSource(
                ref,
                HolidaySource(
                  name: nameC.text.trim().isEmpty ? urlC.text.trim() : nameC.text.trim(),
                  url: urlC.text.trim(),
                  kind: kind,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  Future<void> _addSource(WidgetRef ref, HolidaySource src) async {
    try {
      await ref.read(apiClientProvider).createHolidaySource(src);
    } catch (_) {
      // Surface error in next refresh; ignore here.
    }
    ref.invalidate(holidaySourcesProvider);
    ref.invalidate(holidaysProvider);
  }
}

class _SourceRow extends ConsumerStatefulWidget {
  final HolidaySource source;
  const _SourceRow({required this.source});

  @override
  ConsumerState<_SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends ConsumerState<_SourceRow> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    final theme = Theme.of(context);
    final df = DateFormat.yMMMd().add_Hm();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Switch(
            value: s.enabled,
            onChanged: _busy ? null : (v) => _patch(s.copyWith(enabled: v)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  s.url,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (s.lastError != null)
                  Text(
                    '에러: ${s.lastError}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else if (s.lastFetchedAt != null)
                  Text(
                    '마지막 갱신: ${df.format(s.lastFetchedAt!.toLocal())}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  )
                else
                  Text(
                    '아직 갱신되지 않음',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: '지금 갱신',
            iconSize: 18,
            icon: _busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _busy ? null : _refresh,
          ),
          IconButton(
            tooltip: '편집',
            iconSize: 18,
            icon: const Icon(Icons.edit_outlined),
            onPressed: _busy ? null : _openEditDialog,
          ),
          IconButton(
            tooltip: '삭제',
            iconSize: 18,
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : _delete,
          ),
        ],
      ),
    );
  }

  void _openEditDialog() {
    final s = widget.source;
    final nameC = TextEditingController(text: s.name);
    final urlC = TextEditingController(text: s.url);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('구독 편집'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameC,
              decoration: const InputDecoration(labelText: '이름'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlC,
              decoration: const InputDecoration(labelText: '.ics URL'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          FilledButton(
            onPressed: () {
              final name = nameC.text.trim();
              final url = urlC.text.trim();
              if (name.isEmpty || url.isEmpty) return;
              Navigator.pop(ctx);
              _patch(s.copyWith(name: name, url: url));
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _patch(HolidaySource patch) async {
    final id = widget.source.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).updateHolidaySource(id, patch);
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(holidaySourcesProvider);
      ref.invalidate(holidaysProvider);
    }
  }

  Future<void> _refresh() async {
    final id = widget.source.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).refreshHolidaySource(id);
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(holidaySourcesProvider);
      ref.invalidate(holidaysProvider);
    }
  }

  Future<void> _delete() async {
    final id = widget.source.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).deleteHolidaySource(id);
    } finally {
      if (mounted) setState(() => _busy = false);
      ref.invalidate(holidaySourcesProvider);
      ref.invalidate(holidaysProvider);
    }
  }
}
