import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/app_localizations.dart';
import '../models/resource.dart';
import '../state/providers.dart';

/// Agent management surface: list of every Resource of Kind=Agent + a
/// "+ new agent" affordance + per-row actions (rotate, revoke). The
/// raw token from create / rotate is the load-bearing one-time-only
/// secret — it gets surfaced in a modal that forces the user to
/// confirm copy before dismissing, since the backend cannot recover it.
class AgentsSection extends ConsumerWidget {
  const AgentsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final agents = ref.watch(agentsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.agentsSectionLead,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => _showCreateAgentDialog(context, ref),
                label: Text(l.agentsCreateButton),
              ),
            ],
          ),
          const SizedBox(height: 16),
          agents.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(l.errorPrefix(e.toString()))),
            ),
            data: (list) {
              if (list.isEmpty) return const _EmptyState();
              return Column(
                children: [
                  for (final agent in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AgentCard(agent: agent),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.smart_toy_outlined, size: 32, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(l.agentsEmptyTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            l.agentsEmptyHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AgentCard extends ConsumerStatefulWidget {
  final Resource agent;
  const _AgentCard({required this.agent});

  @override
  ConsumerState<_AgentCard> createState() => _AgentCardState();
}

class _AgentCardState extends ConsumerState<_AgentCard> {
  bool _expanded = false;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final agent = widget.agent;
    final agentId = agent.id;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              agent.name,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _RbacPill(rbac: agent.rbac),
                        ],
                      ),
                      if (agent.agentDescription != null && agent.agentDescription!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          agent.agentDescription!,
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                if (agentId != null) ...[
                  IconButton(
                    tooltip: l.agentsRotateTooltip,
                    icon: const Icon(Icons.autorenew, size: 18),
                    onPressed: _busy ? null : () => _rotate(context, agentId),
                  ),
                  IconButton(
                    tooltip: l.agentsRevokeTooltip,
                    icon: const Icon(Icons.block, size: 18),
                    onPressed: _busy ? null : () => _revoke(context, agentId),
                  ),
                  IconButton(
                    tooltip: _expanded ? l.agentsCollapseTokens : l.agentsExpandTokens,
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 20),
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ],
            ),
          ),
          if (_expanded && agentId != null) ...[
            const Divider(height: 1),
            _TokensList(agentId: agentId),
          ],
        ],
      ),
    );
  }

  Future<void> _rotate(BuildContext context, String agentId) async {
    final l = AppL10n.of(context);
    final api = ref.read(apiClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final rotated = await api.rotateAgentToken(agentId);
      ref.invalidate(agentTokensProvider(agentId));
      if (!context.mounted) return;
      await _showRawTokenDialog(
        context,
        title: l.agentsRotatedTitle,
        rawToken: rotated.rawToken,
        lastFour: rotated.lastFour,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorPrefix(e.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(BuildContext context, String agentId) async {
    final l = AppL10n.of(context);
    final api = ref.read(apiClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.agentsRevokeConfirmTitle),
        content: Text(l.agentsRevokeConfirmBody(widget.agent.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.agentsRevokeConfirmAction),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      final n = await api.revokeAgentTokens(agentId);
      ref.invalidate(agentTokensProvider(agentId));
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.agentsRevokedToast(n))));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorPrefix(e.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _TokensList extends ConsumerWidget {
  final String agentId;
  const _TokensList({required this.agentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final tokens = ref.watch(agentTokensProvider(agentId));
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 8, 16, 14),
      child: tokens.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
        error: (e, _) => Text(l.errorPrefix(e.toString()),
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
        data: (rows) {
          if (rows.isEmpty) {
            return Text(l.agentsTokensEmpty,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline));
          }
          final fmt = DateFormat.yMd().add_Hm();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final t in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: t.isActive ? Colors.green : theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('mk_…${t.lastFour}', style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      Text(
                        t.isActive
                            ? l.agentsTokenActive
                            : l.agentsTokenRevokedAt(fmt.format(t.revokedAt!.toLocal())),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                      const Spacer(),
                      Text(
                        l.agentsTokenCreatedAt(fmt.format(t.createdAt.toLocal())),
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _RbacPill extends StatelessWidget {
  final RbacPresetFE rbac;
  const _RbacPill({required this.rbac});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (rbac) {
      RbacPresetFE.manager => Colors.purple,
      RbacPresetFE.reviewer => Colors.indigo,
      RbacPresetFE.developer => Colors.blue,
      RbacPresetFE.qa => Colors.teal,
      RbacPresetFE.human => theme.colorScheme.outline,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        rbac.label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

Future<void> _showCreateAgentDialog(BuildContext context, WidgetRef ref) async {
  final l = AppL10n.of(context);
  final api = ref.read(apiClientProvider);
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final roleCtrl = TextEditingController();
  RbacPresetFE rbac = RbacPresetFE.developer;
  String? errorText;
  bool busy = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text(l.agentsCreateDialogTitle),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(labelText: l.agentsFieldName),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: roleCtrl,
                decoration: InputDecoration(labelText: l.agentsFieldRole),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l.agentsFieldDescription,
                  hintText: l.agentsFieldDescriptionHint,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RbacPresetFE>(
                initialValue: rbac,
                decoration: InputDecoration(labelText: l.agentsFieldRbac),
                items: [
                  for (final preset in [
                    RbacPresetFE.manager,
                    RbacPresetFE.reviewer,
                    RbacPresetFE.developer,
                    RbacPresetFE.qa,
                  ])
                    DropdownMenuItem(
                      value: preset,
                      // Reuse the same pill the card row renders so the
                      // dropdown choice and the resulting card pill match
                      // visually one-for-one.
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _RbacPill(rbac: preset),
                      ),
                    ),
                ],
                onChanged: busy ? null : (v) => setState(() => rbac = v ?? rbac),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Text(errorText!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy ? null : () => Navigator.of(ctx).pop(),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      setState(() => errorText = l.agentsFieldNameRequired);
                      return;
                    }
                    setState(() {
                      busy = true;
                      errorText = null;
                    });
                    try {
                      final created = await api.createAgent(
                        name: name,
                        role: roleCtrl.text.trim().isEmpty ? null : roleCtrl.text.trim(),
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                        rbac: rbac,
                      );
                      ref.invalidate(agentsProvider);
                      if (!ctx.mounted) return;
                      Navigator.of(ctx).pop();
                      await _showRawTokenDialog(
                        context,
                        title: l.agentsCreatedTitle,
                        rawToken: created.rawToken,
                        lastFour: created.lastFour,
                      );
                    } catch (e) {
                      setState(() {
                        busy = false;
                        errorText = l.errorPrefix(e.toString());
                      });
                    }
                  },
            child: busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l.agentsCreateConfirm),
          ),
        ],
      ),
    ),
  );
}

/// Shared one-time-token reveal modal. Used by both create + rotate so the
/// "this is your only chance" warning is consistent.
Future<void> _showRawTokenDialog(
  BuildContext context, {
  required String title,
  required String rawToken,
  required String lastFour,
}) async {
  final l = AppL10n.of(context);
  bool copied = false;

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.key, color: Theme.of(ctx).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.errorContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_outlined,
                        color: Theme.of(ctx).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l.agentsTokenRevealWarning,
                        style: TextStyle(color: Theme.of(ctx).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        rawToken,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                      ),
                    ),
                    IconButton(
                      tooltip: l.actionCopy,
                      icon: Icon(copied ? Icons.check : Icons.copy, size: 18),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: rawToken));
                        setState(() => copied = true);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.agentsTokenRevealHint(lastFour),
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.agentsTokenRevealAcknowledge),
          ),
        ],
      ),
    ),
  );
}
