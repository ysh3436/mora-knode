import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/agent.dart';
import '../models/agent_plan.dart';
import '../models/assignment.dart';
import '../models/change_log.dart';
import '../models/holiday.dart';
import '../models/milestone.dart';
import '../models/project.dart';
import '../models/resource.dart';
import '../models/resource_load.dart';
import '../models/task_hierarchy.dart';
import '../models/task_item.dart';
import '../models/work_calendar.dart';

// --- UI / session state ---

/// Dev-mode "logged in as" id. Selected from the user switcher; passed to
/// the backend as X-Dev-User-Id. null = anonymous (admin-equivalent).
final currentUserIdProvider = StateProvider<String?>((_) => null);

/// AppShell pane visibility. Sidebar default open, inspector default closed
/// per wireframes.md §0.1.
final sidebarOpenProvider = StateProvider<bool>((_) => true);
final inspectorOpenProvider = StateProvider<bool>((_) => false);

/// User-resizable inspector pane width. Min/max enforced at the resize-handle.
final inspectorWidthProvider = StateProvider<double>((_) => 520);

/// Active UI locale. Defaults to Korean for the dogfooding audience; the
/// settings panel exposes a switcher. null would let MaterialApp fall back to
/// the platform locale, which we intentionally avoid here.
final localeProvider = StateProvider<Locale>((_) => const Locale('ko'));

/// Active color scheme. Defaults to System so the app honors the OS's
/// light/dark preference out of the box; Settings exposes an explicit
/// override (System / Light / Dark). Not yet persisted across reloads —
/// same memory-only pattern as [localeProvider].
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

enum AppSection { myWork, allWork, projects, resources, matrix, plans, audit, agents, settings }

final appSectionProvider = StateProvider<AppSection>((_) => AppSection.myWork);

/// What the inspector should display. null = empty state.
sealed class Inspection {
  const Inspection();
}

class TaskInspection extends Inspection {
  final String taskId;
  const TaskInspection(this.taskId);
}

class ProjectInspection extends Inspection {
  final String projectId;
  const ProjectInspection(this.projectId);
}

/// Empty draft form — inspector renders a "create new task" panel instead of
/// opening a modal dialog. Project / parent are pre-selected when the draft
/// is opened from a contextual button (e.g. + 새 업무 inside a project tab).
class TaskDraftInspection extends Inspection {
  final String? projectId;
  final String? parentTaskId;
  const TaskDraftInspection({this.projectId, this.parentTaskId});
}

final inspectionProvider = StateProvider<Inspection?>((_) => null);

// --- API client ---

final apiClientProvider = Provider<ApiClient>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ApiClient(currentUserId: userId);
});

final projectsProvider = FutureProvider<List<Project>>((ref) async {
  return ref.watch(apiClientProvider).listProjects();
});

final selectedProjectIdProvider = StateProvider<String?>((_) => null);

final tasksProvider = FutureProvider.family<List<TaskItem>, String>((ref, projectId) async {
  return ref.watch(apiClientProvider).listTasks(projectId);
});

final taskHierarchyProvider = FutureProvider.family<List<TaskHierarchyNode>, String>((ref, projectId) async {
  return ref.watch(apiClientProvider).listTaskHierarchy(projectId);
});

final milestonesProvider = FutureProvider.family<List<Milestone>, String>((ref, projectId) async {
  return ref.watch(apiClientProvider).listMilestones(projectId);
});

final resourcesProvider = FutureProvider<List<Resource>>((ref) async {
  return ref.watch(apiClientProvider).listResources();
});

/// All Resource records of Kind=Agent. Drives the agent management
/// section. Separate from [resourcesProvider] so re-fetching after a
/// create/rotate/revoke doesn't blow the resource cache used elsewhere.
final agentsProvider = FutureProvider<List<Resource>>((ref) async {
  return ref.watch(apiClientProvider).listAgents();
});

/// Token history for one agent (active + revoked rows, newest first).
/// Surfaces as "what credentials exist" in the per-agent expander.
final agentTokensProvider =
    FutureProvider.family<List<AgentTokenSummary>, String>((ref, agentId) async {
  return ref.watch(apiClientProvider).listAgentTokens(agentId);
});

/// Active filter on the plan review queue. PendingReview by default — the
/// queue is "what needs my decision". User toggles to Approved / Rejected
/// / null (all) to look back through history.
final planReviewFilterProvider = StateProvider<PlanStatus?>((_) => PlanStatus.pendingReview);

/// Plans matching the current filter. Re-fetched on filter change since
/// the backend is doing the filtering anyway.
final agentPlansProvider = FutureProvider<List<AgentPlan>>((ref) async {
  final filter = ref.watch(planReviewFilterProvider);
  return ref.watch(apiClientProvider).listAgentPlans(status: filter);
});

final assignmentsByTaskProvider = FutureProvider.family<List<Assignment>, String>((ref, taskId) async {
  return ref.watch(apiClientProvider).listAssignments(taskId: taskId);
});

final taskChangeLogsProvider = FutureProvider.family<List<ChangeLog>, String>((ref, taskId) async {
  return ref.watch(apiClientProvider).listChangeLogs(
        entityType: ChangeEntityType.Task,
        entityId: taskId,
        limit: 50,
      );
});

// --- Aggregated cross-project views ---

typedef ProjectHierarchy = ({Project project, List<TaskHierarchyNode> nodes});

/// All projects with their hierarchy nodes (fan-out fetch — fine for MVP scale).
final allHierarchyByProjectProvider = FutureProvider<List<ProjectHierarchy>>((ref) async {
  final projects = await ref.watch(projectsProvider.future);
  final api = ref.watch(apiClientProvider);
  final out = <ProjectHierarchy>[];
  for (final p in projects) {
    if (p.id == null) continue;
    final nodes = await api.listTaskHierarchy(p.id!);
    out.add((project: p, nodes: nodes));
  }
  return out;
});

/// All assignments across the system. Used by All Tasks / All Gantt to filter
/// by assignee and to show assignee chips in expanded task detail.
final allAssignmentsProvider = FutureProvider<List<Assignment>>((ref) async {
  return ref.watch(apiClientProvider).listAssignments();
});

/// Configured WorkCalendar (org-level singleton). Returns the wrapped
/// {isFallback, calendar} response so the Settings UI can show "not yet
/// configured" state.
final workCalendarProvider = FutureProvider<WorkCalendarResponse>((ref) async {
  return ref.watch(apiClientProvider).getWorkCalendar();
});

/// Subscribed iCalendar holiday sources — drives the settings UI for
/// add/edit/delete/refresh of holiday subscriptions.
final holidaySourcesProvider = FutureProvider<List<HolidaySource>>((ref) async {
  return ref.watch(apiClientProvider).listHolidaySources();
});

/// Integer key for fast date → Holiday map lookup (year*10000 + month*100 + day).
/// Compares UTC y/m/d so callers don't have to worry about timezone offsets.
int holidayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// Aggregated holiday map covering today ± 5 years — same span as the gantt
/// virtual range so a single fetch services every caller (gantt + month
/// calendar + week calendar). Backend returns from cache so this is cheap.
final holidaysProvider = FutureProvider<Map<int, Holiday>>((ref) async {
  // Watching sources invalidates this map when the user adds / removes /
  // toggles a subscription, so the next paint reflects their change.
  await ref.watch(holidaySourcesProvider.future);
  final now = DateTime.now();
  final from = DateTime.utc(now.year - 5, now.month, now.day);
  final to = DateTime.utc(now.year + 5, now.month, now.day);
  final list = await ref.watch(apiClientProvider).listHolidays(from: from, to: to);
  return {for (final h in list) holidayKey(h.date): h};
});

/// One-shot first-run seed. Watched at MoraKnodeApp root so the very first
/// frame asks the backend "if no holiday subscriptions exist yet, add the
/// one matching my locale." Idempotent on the backend (gated by an AppMeta
/// flag), so re-watching this provider after a hot restart does no harm —
/// and a user who deletes the auto-added source won't see it reappear.
/// Failures (backend not running, network blip) are silently swallowed so
/// the rest of the UI still mounts.
final autoSeedHolidaysProvider = FutureProvider<bool>((ref) async {
  final locale = ref.read(localeProvider).languageCode;
  try {
    final seeded =
        await ref.read(apiClientProvider).autoSeedHolidaySources(locale: locale);
    if (seeded) {
      ref.invalidate(holidaySourcesProvider);
      ref.invalidate(holidaysProvider);
    }
    return seeded;
  } catch (_) {
    return false;
  }
});

/// The currently selected user, resolved against resourcesProvider. Null
/// when anonymous (admin-equivalent).
final currentUserProvider = Provider<Resource?>((ref) {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) return null;
  final list = ref.watch(resourcesProvider).asData?.value ?? const <Resource>[];
  for (final r in list) {
    if (r.id == id) return r;
  }
  return null;
});

/// True when the caller has full permissions / view scope. Anonymous and
/// Manager / Reviewer / Human all qualify (mirrors backend UserContext.IsAdmin).
final isAdminProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return true;
  return user.rbac.isAdmin;
});

// --- Shared filter state for the home tabs ---
// Empty set = no filter (show all).

final projectFilterProvider = StateProvider<Set<String>>((_) => <String>{});
final assigneeFilterProvider = StateProvider<Set<String>>((_) => <String>{});
final statusFilterProvider = StateProvider<Set<TaskStatus>>((_) => <TaskStatus>{});
final searchQueryProvider = StateProvider<String>((_) => '');

/// Notion-style multi-level sort chain shared by the tasks workspace
/// (List + Gantt + Calendar). Empty list = default order (creation /
/// hierarchy position). When non-empty, steps are evaluated in order
/// and the first non-zero comparison wins. ASC has a "natural" meaning
/// per key: priority ASC = most urgent first (Urgent is the smallest
/// int by design), dueDate ASC = soonest first, status ASC = active first.
final taskSortChainProvider = StateProvider<List<TaskSortStep>>((_) => const []);

/// Tasks workspace has multiple subviews (List / Gantt / Calendar). They are
/// kept as separate widget trees but share the filter state above. The same
/// workspace renders in All work (no scope) and per-project Tasks tabs
/// (scopeProjectId set) — selection persists across both contexts.
enum TasksSubview { list, gantt, calendar }
final tasksSubviewProvider = StateProvider<TasksSubview>((_) => TasksSubview.list);

/// Gantt zoom level. Persists across re-entries to the gantt subview.
final ganttZoomProvider = StateProvider<int>((_) => 0); // 0=day, 1=week, 2=month

/// User-resizable gantt title column width. Per-session (memory only,
/// like inspectorWidthProvider). Min/max enforced at the drag handle
/// inside GanttChart.
final ganttTitleColWidthProvider = StateProvider<double>((_) => 240);

/// IDs whose children should be hidden in tree-style views (List + Gantt).
/// Keyed by entity id: a task id collapses that task's subtree;
/// `proj:<id>` collapses an entire project group. Shared so toggling
/// in one view persists into the other.
final collapsedNodesProvider = StateProvider<Set<String>>((_) => const <String>{});

/// Calendar subview state.
enum CalendarMode { month, week }
final calendarModeProvider = StateProvider<CalendarMode>((_) => CalendarMode.month);

/// Anchor date for the calendar — first of the month for Month mode, the
/// Monday of the displayed week for Week mode. Stored as a local-zone
/// DateTime so it composes with task day buckets that key on local y/m/d.
final calendarAnchorProvider = StateProvider<DateTime>((_) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Matrix view's anchor (snapped to a Monday inside the displayed week).
final matrixAnchorProvider = StateProvider<DateTime>((_) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: today.weekday - DateTime.monday));
});

class MatrixRange {
  final DateTime from;
  final DateTime to;
  const MatrixRange(this.from, this.to);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MatrixRange && other.from == from && other.to == to);

  @override
  int get hashCode => Object.hash(from, to);
}

final matrixLoadProvider = FutureProvider.family<MatrixLoadResponse, MatrixRange>((ref, range) async {
  return ref.watch(apiClientProvider).matrixLoad(from: range.from, to: range.to);
});
