import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../l10n/app_localizations.dart';
import '../models/agent_plan.dart';
import '../models/resource.dart';
import '../models/task_hierarchy.dart';
import '../state/providers.dart';

/// Plan review queue. Default view = PendingReview (the human's actual
/// inbox). Filter chips switch to Approved / Rejected / all so the same
/// surface doubles as plan history. Each card supports inline approve /
/// reject — backend enforces the human-only RBAC gate, here we just
/// surface the buttons.
class PlansSection extends ConsumerWidget {
  const PlansSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final filter = ref.watch(planReviewFilterProvider);
    final plans = ref.watch(agentPlansProvider);

    final currentUser = ref.watch(currentUserProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.plansSectionLead,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.outline),
          ),
          if (currentUser == null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: theme.colorScheme.tertiary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.onTertiaryContainer),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.plansAuthBannerTitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(l.plansAuthBannerHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onTertiaryContainer)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              _FilterChip(label: l.plansFilterPending, value: PlanStatus.pendingReview, current: filter),
              _FilterChip(label: l.plansFilterApproved, value: PlanStatus.approved, current: filter),
              _FilterChip(label: l.plansFilterRejected, value: PlanStatus.rejected, current: filter),
              _FilterChip(label: l.plansFilterAll, value: null, current: filter),
            ],
          ),
          const SizedBox(height: 16),
          plans.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text(l.errorPrefix(e.toString()))),
            ),
            data: (list) {
              if (list.isEmpty) return _EmptyState(filter: filter);
              return Column(
                children: [
                  for (final plan in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PlanCard(plan: plan),
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

class _FilterChip extends ConsumerWidget {
  final String label;
  final PlanStatus? value;
  final PlanStatus? current;
  const _FilterChip({required this.label, required this.value, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => ref.read(planReviewFilterProvider.notifier).state = value,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final PlanStatus? filter;
  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final (icon, title, hint) = switch (filter) {
      PlanStatus.pendingReview => (Icons.inbox_outlined, l.plansEmptyPendingTitle, l.plansEmptyPendingHint),
      PlanStatus.approved => (Icons.check_circle_outline, l.plansEmptyApprovedTitle, l.plansEmptyApprovedHint),
      PlanStatus.rejected => (Icons.block, l.plansEmptyRejectedTitle, l.plansEmptyRejectedHint),
      null => (Icons.fact_check_outlined, l.plansEmptyAllTitle, l.plansEmptyAllHint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends ConsumerStatefulWidget {
  final AgentPlan plan;
  const _PlanCard({required this.plan});

  @override
  ConsumerState<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends ConsumerState<_PlanCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final plan = widget.plan;

    final allHier = ref.watch(allHierarchyByProjectProvider).asData?.value ?? const [];
    final resources = ref.watch(resourcesProvider).asData?.value ?? const [];
    TaskHierarchyNode? taskNode;
    String? projectName;
    for (final g in allHier) {
      for (final n in g.nodes) {
        if (n.id == plan.taskId) {
          taskNode = n;
          projectName = g.project.name;
          break;
        }
      }
      if (taskNode != null) break;
    }
    final submitter = resources.firstWhere(
      (r) => r.id == plan.submittedByResourceId,
      orElse: () => const Resource(name: '?'),
    );
    final reviewer = plan.reviewedByResourceId == null
        ? null
        : resources.firstWhere(
            (r) => r.id == plan.reviewedByResourceId,
            orElse: () => const Resource(name: '?'),
          );

    final currentUser = ref.watch(currentUserProvider);
    final canRevert = plan.status != PlanStatus.pendingReview &&
        currentUser != null &&
        (currentUser.id == plan.reviewedByResourceId ||
            currentUser.rbac == RbacPresetFE.manager);
    final canDecide = plan.status == PlanStatus.pendingReview && currentUser != null;

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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _StatusPill(status: plan.status),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        taskNode != null
                            ? 'MK-${taskNode.number} · ${taskNode.title}'
                            : l.plansTaskUnknown(plan.taskId),
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      DateFormat.yMd().add_Hm().format(plan.createdAt.toLocal()),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_outline, size: 14, color: theme.colorScheme.outline),
                        const SizedBox(width: 4),
                        Text(submitter.name,
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                      ],
                    ),
                    if (projectName != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_outlined, size: 14, color: theme.colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(projectName,
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    if (plan.estimateMinutes != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.schedule, size: 14, color: theme.colorScheme.outline),
                          const SizedBox(width: 4),
                          Text(l.plansEstimateMinutes(plan.estimateMinutes!),
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    if (reviewer != null && plan.reviewedAt != null)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            plan.status == PlanStatus.approved ? Icons.check_circle : Icons.cancel,
                            size: 14,
                            color: plan.status == PlanStatus.approved
                                ? Colors.green
                                : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l.plansReviewedBy(
                              reviewer.name,
                              DateFormat.yMd().add_Hm().format(plan.reviewedAt!.toLocal()),
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(plan.title, style: theme.textTheme.bodyLarge),
                if (plan.steps.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(l.plansStepsHeader,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  for (var i = 0; i < plan.steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 22,
                            child: Text('${i + 1}.',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                          ),
                          Expanded(child: Text(plan.steps[i].description, style: theme.textTheme.bodyMedium)),
                          if (plan.steps[i].estimateMinutes != null)
                            Text(' · ${l.plansEstimateMinutes(plan.steps[i].estimateMinutes!)}',
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
                        ],
                      ),
                    ),
                ],
                if (plan.notes != null && plan.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(l.plansNotesHeader,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(plan.notes!, style: theme.textTheme.bodyMedium),
                ],
                if (plan.reviewerComment != null && plan.reviewerComment!.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.plansReviewerCommentHeader,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                              fontWeight: FontWeight.w600,
                            )),
                        const SizedBox(height: 4),
                        Text(plan.reviewerComment!, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (plan.status == PlanStatus.pendingReview) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Tooltip(
                    message: canDecide ? '' : l.plansAuthBannerHint,
                    child: TextButton.icon(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: (_busy || !canDecide) ? null : () => _reject(context, plan.id),
                      style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
                      label: Text(l.plansActionReject),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: canDecide ? '' : l.plansAuthBannerHint,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check, size: 18),
                      onPressed: (_busy || !canDecide) ? null : () => _approve(context, plan.id),
                      label: Text(l.plansActionApprove),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (canRevert) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.undo, size: 18),
                    onPressed: _busy ? null : () => _revert(context, plan.id),
                    label: Text(l.plansActionRevert),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approve(BuildContext context, String planId) async {
    final l = AppL10n.of(context);
    final api = ref.read(apiClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await api.approveAgentPlan(planId);
      ref.invalidate(agentPlansProvider);
      ref.invalidate(allHierarchyByProjectProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.plansApprovedToast)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorPrefix(e.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revert(BuildContext context, String planId) async {
    final l = AppL10n.of(context);
    final api = ref.read(apiClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.plansRevertConfirmTitle),
        content: Text(l.plansRevertConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.actionCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.plansRevertConfirmAction),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await api.revertAgentPlan(planId);
      ref.invalidate(agentPlansProvider);
      ref.invalidate(allHierarchyByProjectProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.plansRevertedToast)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorPrefix(e.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject(BuildContext context, String planId) async {
    final l = AppL10n.of(context);
    final api = ref.read(apiClientProvider);
    final messenger = ScaffoldMessenger.of(context);
    final commentCtrl = TextEditingController();
    String? errorText;
    final comment = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l.plansRejectDialogTitle),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.plansRejectDialogHint,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.outline)),
                const SizedBox(height: 12),
                TextField(
                  controller: commentCtrl,
                  autofocus: true,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: l.plansRejectFieldComment,
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 8),
                  Text(errorText!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l.actionCancel),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
              onPressed: () {
                final txt = commentCtrl.text.trim();
                if (txt.isEmpty) {
                  setState(() => errorText = l.plansRejectFieldRequired);
                  return;
                }
                Navigator.of(ctx).pop(txt);
              },
              child: Text(l.plansRejectConfirm),
            ),
          ],
        ),
      ),
    );
    if (comment == null) return;
    setState(() => _busy = true);
    try {
      await api.rejectAgentPlan(planId, comment: comment);
      ref.invalidate(agentPlansProvider);
      ref.invalidate(allHierarchyByProjectProvider);
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(l.plansRejectedToast)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorPrefix(e.toString()))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _StatusPill extends StatelessWidget {
  final PlanStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppL10n.of(context);
    final (color, label) = switch (status) {
      PlanStatus.pendingReview => (Colors.orange, l.plansFilterPending),
      PlanStatus.approved => (Colors.green, l.plansFilterApproved),
      PlanStatus.rejected => (theme.colorScheme.error, l.plansFilterRejected),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
