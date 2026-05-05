import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../l10n/app_localizations.dart';
import '../../l10n/labels.dart' show dateLocale;
import '../../models/task_comment.dart';
import '../../state/providers.dart';

/// Comments thread + composer for a task. Newest first; the latest entry
/// stays expanded by default, prior entries collapse to a one-line preview
/// and expand on tap. The composer above the thread posts plain markdown
/// (image references via `![](url)` syntax already render inline). Image
/// upload UI from the composer ships separately — see follow-up task.
class TaskCommentsSection extends ConsumerWidget {
  final String taskId;
  const TaskCommentsSection({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final comments = ref.watch(taskCommentsProvider(taskId));

    return comments.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Text('$e', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
      data: (list) {
        // Newest first: composer sits above the thread so a fresh entry
        // appears just below where it was typed. Latest = first entry,
        // expanded by default; earlier entries collapse.
        final reversed = list.reversed.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentComposer(taskId: taskId),
            const SizedBox(height: 12),
            if (reversed.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(l.commentsEmpty, style: theme.textTheme.bodySmall),
              )
            else
              for (var i = 0; i < reversed.length; i++)
                _CommentEntry(
                  comment: reversed[i],
                  taskId: taskId,
                  isLatest: i == 0,
                ),
          ],
        );
      },
    );
  }
}

/// One entry in the thread. Latest is rendered fully expanded with edit /
/// delete buttons in-line. Earlier entries render a single-line preview; tap
/// to expand. The expanded body parses markdown image syntax loosely so
/// `![](url)` chunks render as actual images and the surrounding text stays
/// as plain text — full markdown rendering is a follow-up.
class _CommentEntry extends ConsumerStatefulWidget {
  final TaskComment comment;
  final String taskId;
  final bool isLatest;
  const _CommentEntry({required this.comment, required this.taskId, required this.isLatest});

  @override
  ConsumerState<_CommentEntry> createState() => _CommentEntryState();
}

class _CommentEntryState extends ConsumerState<_CommentEntry> {
  late bool _expanded;
  bool _editing = false;
  late TextEditingController _editCtrl;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isLatest;
    _editCtrl = TextEditingController(text: widget.comment.body);
  }

  @override
  void didUpdateWidget(covariant _CommentEntry old) {
    super.didUpdateWidget(old);
    if (old.comment.id != widget.comment.id) {
      _editCtrl.text = widget.comment.body;
      _expanded = widget.isLatest;
      _editing = false;
    }
  }

  @override
  void dispose() {
    _editCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = ref.read(apiClientProvider);
    final next = _editCtrl.text;
    if (next.trim().isEmpty) return;
    await api.updateTaskComment(widget.comment.id, body: next, kind: widget.comment.kind);
    ref.invalidate(taskCommentsProvider(widget.taskId));
    if (mounted) setState(() => _editing = false);
  }

  Future<void> _delete() async {
    final l = AppL10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.commentDeleteConfirmTitle),
        content: Text(l.commentDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.commentCancelButton)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commentDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).deleteTaskComment(widget.comment.id);
      ref.invalidate(taskCommentsProvider(widget.taskId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppL10n.of(context).commentDeleteFailed(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final df = DateFormat('M/d HH:mm', dateLocale(context));
    final currentUser = ref.watch(currentUserProvider);
    // Strict author check — admins can still moderate via API, but the
    // inspector hides the buttons so they don't accidentally clobber other
    // people's review threads.
    final canEdit = currentUser != null &&
        currentUser.id == widget.comment.authorResourceId;

    final author = ref.watch(resourcesProvider).maybeWhen(
          data: (rs) =>
              rs.where((r) => r.id == widget.comment.authorResourceId).firstOrNull,
          orElse: () => null,
        );
    final authorName = author?.name ?? '?';
    final authorRoleLabel = author?.rbac.label;
    final timeLabel = df.format(widget.comment.createdAt.toLocal());
    final preview = widget.comment.body.replaceAll(RegExp(r'!\[.*?\]\(.*?\)'), '🖼')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header — author + timestamp + kind chip + collapse toggle for non-latest
          Row(
            children: [
              if (widget.comment.kind != null) ...[
                _KindChip(kind: widget.comment.kind!),
                const SizedBox(width: 6),
              ],
              Text(authorName,
                  style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
              if (authorRoleLabel != null) ...[
                const SizedBox(width: 6),
                Text(authorRoleLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                      fontSize: 10,
                    )),
              ],
              const SizedBox(width: 8),
              Text(timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
              const Spacer(),
              if (!widget.isLatest)
                IconButton(
                  tooltip: _expanded ? l.commentCollapse : l.commentExpand,
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ),
            ],
          ),
          if (!_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 2),
              child: Text(
                preview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            )
          else if (_editing)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _editCtrl,
                    maxLines: null,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Spacer(),
                      TextButton(
                        onPressed: () => setState(() {
                          _editing = false;
                          _editCtrl.text = widget.comment.body;
                        }),
                        child: Text(l.commentCancelButton),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(onPressed: _save, child: Text(l.commentSaveButton)),
                    ],
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 2),
              child: _CommentBody(body: widget.comment.body),
            ),
          if (_expanded && !_editing && canEdit)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() => _editing = true),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: Text(l.commentEdit, style: theme.textTheme.bodySmall),
                ),
                TextButton(
                  onPressed: _delete,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: theme.colorScheme.error,
                  ),
                  child: Text(l.commentDelete, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Renders the body as plain selectable text. Markdown rendering — images
/// in particular — ships separately under the image-attach follow-up task.
class _CommentBody extends StatelessWidget {
  final String body;
  const _CommentBody({required this.body});

  @override
  Widget build(BuildContext context) {
    return SelectableText(body, style: Theme.of(context).textTheme.bodySmall);
  }
}

class _KindChip extends StatelessWidget {
  final String kind;
  const _KindChip({required this.kind});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final (color, label) = switch (kind.toLowerCase()) {
      'review' => (Colors.indigo, l.commentKindReview),
      'bug' => (Colors.red, l.commentKindBug),
      'qa' => (Colors.teal, l.commentKindQa),
      _ => (theme.colorScheme.outline, l.commentKindNote),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          )),
    );
  }
}

/// Composer at the bottom of the thread. Listens for clipboard paste events
/// at the window level (web only) — when the textarea is focused and the
/// pasted clipboard data has an image, the bytes are uploaded and the
/// returned URL is spliced in as `![](url)` at the caret.
class _CommentComposer extends ConsumerStatefulWidget {
  final String taskId;
  const _CommentComposer({required this.taskId});

  @override
  ConsumerState<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends ConsumerState<_CommentComposer> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String? _kind;
  bool _busy = false;

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(apiClientProvider).postTaskComment(
            widget.taskId,
            body: body,
            kind: _kind,
          );
      _ctrl.clear();
      ref.invalidate(taskCommentsProvider(widget.taskId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final user = ref.watch(currentUserProvider);

    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.errorContainer.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline, size: 14, color: theme.colorScheme.error),
            const SizedBox(width: 6),
            Expanded(
              child: Text(l.commentLoginRequired,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Shortcuts(
          shortcuts: <ShortcutActivator, Intent>{
            const SingleActivator(LogicalKeyboardKey.enter, control: true): const _PostIntent(),
            const SingleActivator(LogicalKeyboardKey.enter, meta: true): const _PostIntent(),
          },
          child: Actions(
            actions: <Type, Action<Intent>>{
              _PostIntent: CallbackAction<_PostIntent>(onInvoke: (_) {
                _post();
                return null;
              }),
            },
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              maxLines: null,
              minLines: 2,
              enabled: !_busy,
              decoration: InputDecoration(
                hintText: l.commentAddHint,
                isDense: true,
                border: const OutlineInputBorder(),
                helperText: _busy ? l.commentSavingHint : null,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            DropdownButton<String?>(
              value: _kind,
              underline: const SizedBox.shrink(),
              isDense: true,
              hint: Text(l.commentKindNote, style: theme.textTheme.bodySmall),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text(l.commentKindNote)),
                DropdownMenuItem<String?>(value: 'review', child: Text(l.commentKindReview)),
                DropdownMenuItem<String?>(value: 'bug', child: Text(l.commentKindBug)),
                DropdownMenuItem<String?>(value: 'qa', child: Text(l.commentKindQa)),
              ],
              onChanged: _busy ? null : (v) => setState(() => _kind = v),
            ),
            const Spacer(),
            FilledButton(
              onPressed: _busy ? null : _post,
              child: Text(l.commentPostButton),
            ),
          ],
        ),
      ],
    );
  }
}

class _PostIntent extends Intent {
  const _PostIntent();
}
