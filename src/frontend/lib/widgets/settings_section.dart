import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../l10n/labels.dart';
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
            segments: [
              ButtonSegment(value: 'ko', label: Text(l.languageKorean)),
              ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
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
