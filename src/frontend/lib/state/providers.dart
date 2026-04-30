import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../models/assignment.dart';
import '../models/change_log.dart';
import '../models/milestone.dart';
import '../models/project.dart';
import '../models/resource.dart';
import '../models/resource_load.dart';
import '../models/task_hierarchy.dart';
import '../models/task_item.dart';

// --- UI / session state ---

/// Dev-mode "logged in as" id. Selected from the user switcher; passed to
/// the backend as X-Dev-User-Id. null = anonymous (admin-equivalent).
final currentUserIdProvider = StateProvider<String?>((_) => null);

/// AppShell pane visibility. Sidebar default open, inspector default closed
/// per wireframes.md §0.1.
final sidebarOpenProvider = StateProvider<bool>((_) => true);
final inspectorOpenProvider = StateProvider<bool>((_) => false);

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

// --- Shared filter state for the home tabs ---
// Empty set = no filter (show all).

final projectFilterProvider = StateProvider<Set<String>>((_) => <String>{});
final assigneeFilterProvider = StateProvider<Set<String>>((_) => <String>{});
final statusFilterProvider = StateProvider<Set<TaskStatus>>((_) => <TaskStatus>{});
final searchQueryProvider = StateProvider<String>((_) => '');

/// All work has multiple subviews (List / Gantt / Calendar). They are kept as
/// separate widget trees but share the filter state above.
enum AllWorkSubview { list, gantt, calendar }
final allWorkSubviewProvider = StateProvider<AllWorkSubview>((_) => AllWorkSubview.list);

/// Gantt zoom level. Persists across re-entries to the gantt subview.
final ganttZoomProvider = StateProvider<int>((_) => 0); // 0=day, 1=week, 2=month

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
