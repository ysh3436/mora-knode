import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

    if (!isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 32, color: theme.colorScheme.outline),
              const SizedBox(height: 12),
              Text('Settings are visible to admin roles only.', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Switch to the ysh user from the sidebar to edit WorkCalendar and other org-level settings.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return const _WorkCalendarEditor();
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

    return loaded.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
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
                          'No WorkCalendar configured yet. Showing the 24/7 fallback. '
                          'Saving will create the document and start scoping matrix load to work hours.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              Text('Work Calendar', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Drives matrix load calculation, calendar week-mode hour grid, and gantt overlays.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
              ),
              const SizedBox(height: 24),
              _section(theme, 'Work days'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: WorkDays.ordered.map((entry) {
                  final selected = (draft.workDays & entry.$2) != 0;
                  return FilterChip(
                    label: Text(entry.$1),
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
              _section(theme, 'Daily hours (local)'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _TimeField(
                    label: 'Start',
                    minutes: draft.dailyStartMinutes,
                    onPick: (m) => setState(() => _draft = draft.copyWith(dailyStartMinutes: m)),
                  ),
                  const SizedBox(width: 24),
                  _TimeField(
                    label: 'End',
                    minutes: draft.dailyEndMinutes,
                    onPick: (m) => setState(() => _draft = draft.copyWith(dailyEndMinutes: m)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _section(theme, 'Timezone'),
              const SizedBox(height: 8),
              SizedBox(
                width: 280,
                child: TextField(
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                    hintText: 'e.g. Asia/Seoul',
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
                    child: _saving ? const Text('Saving…') : const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _saving ? null : () => setState(() => _draft = resp.calendar),
                    child: const Text('Reset'),
                  ),
                  const Spacer(),
                  if (_isDirty(resp.calendar))
                    Text(
                      'Unsaved changes',
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
