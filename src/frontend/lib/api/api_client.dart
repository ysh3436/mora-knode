import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/agent.dart';
import '../models/agent_plan.dart';
import '../models/assignment.dart';
import '../models/change_log.dart';
import '../models/milestone.dart';
import '../models/project.dart';
import '../models/resource.dart';
import '../models/resource_load.dart';
import '../models/task_hierarchy.dart';
import '../models/task_item.dart';
import '../models/holiday.dart';
import '../models/work_calendar.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final int statusCode;
  final String message;
  ApiException(this.statusCode, this.message);
  @override
  String toString() => 'ApiException($statusCode): $message';
}

class ApiClient {
  final http.Client _http;
  final String _base;
  final String? currentUserId;

  ApiClient({http.Client? client, String? baseUrl, this.currentUserId})
      : _http = client ?? http.Client(),
        _base = baseUrl ?? ApiConfig.baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('$_base$path').replace(queryParameters: query);

  /// Builds default headers for every request. Adds the X-Dev-User-Id
  /// dev-auth header when a user is selected via the sidebar switcher.
  Map<String, String> _headers([Map<String, String>? extra]) {
    final h = <String, String>{...?extra};
    if (currentUserId != null) h['X-Dev-User-Id'] = currentUserId!;
    return h;
  }

  Future<dynamic> _decode(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      if (r.body.isEmpty) return null;
      return jsonDecode(utf8.decode(r.bodyBytes));
    }
    throw ApiException(r.statusCode, r.body);
  }

  static const _jsonHeaders = {'Content-Type': 'application/json'};

  // --- Projects ---
  Future<List<Project>> listProjects() async {
    final data = await _decode(await _http.get(_uri('/api/projects'), headers: _headers()));
    return (data as List).cast<Map<String, dynamic>>().map(Project.fromJson).toList();
  }

  Future<Project> createProject(Project p) async {
    final data = await _decode(await _http.post(
      _uri('/api/projects'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(p.toJson()),
    ));
    return Project.fromJson(data as Map<String, dynamic>);
  }

  Future<Project> updateProject(String id, Project p) async {
    final data = await _decode(await _http.put(
      _uri('/api/projects/$id'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(p.toJson()),
    ));
    return Project.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteProject(String id) async {
    await _decode(await _http.delete(_uri('/api/projects/$id'), headers: _headers()));
  }

  // --- Tasks ---
  Future<List<TaskItem>> listTasks(String projectId) async {
    final data = await _decode(await _http.get(_uri('/api/projects/$projectId/tasks'), headers: _headers()));
    return (data as List).cast<Map<String, dynamic>>().map(TaskItem.fromJson).toList();
  }

  Future<List<TaskHierarchyNode>> listTaskHierarchy(String projectId) async {
    final data = await _decode(await _http.get(_uri('/api/projects/$projectId/tasks/hierarchy'), headers: _headers()));
    return (data as List).cast<Map<String, dynamic>>().map(TaskHierarchyNode.fromJson).toList();
  }

  Future<TaskItem> createTask(String projectId, TaskItem t) async {
    final data = await _decode(await _http.post(
      _uri('/api/projects/$projectId/tasks'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(t.toJson()),
    ));
    return TaskItem.fromJson(data as Map<String, dynamic>);
  }

  Future<TaskItem> getTask(String id) async {
    final data = await _decode(await _http.get(_uri('/api/tasks/$id'), headers: _headers()));
    return TaskItem.fromJson(data as Map<String, dynamic>);
  }

  Future<TaskItem> updateTask(String id, TaskItem t) async {
    final data = await _decode(await _http.put(
      _uri('/api/tasks/$id'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(t.toJson()),
    ));
    return TaskItem.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteTask(String id) async {
    await _decode(await _http.delete(_uri('/api/tasks/$id'), headers: _headers()));
  }

  // --- Resources ---
  Future<List<Resource>> listResources() async {
    final data = await _decode(await _http.get(_uri('/api/resources'), headers: _headers()));
    return (data as List).cast<Map<String, dynamic>>().map(Resource.fromJson).toList();
  }

  Future<Resource> createResource(Resource r) async {
    final data = await _decode(await _http.post(
      _uri('/api/resources'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(r.toJson()),
    ));
    return Resource.fromJson(data as Map<String, dynamic>);
  }

  Future<Resource> updateResource(String id, Resource r) async {
    final data = await _decode(await _http.put(
      _uri('/api/resources/$id'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(r.toJson()),
    ));
    return Resource.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteResource(String id) async {
    await _decode(await _http.delete(_uri('/api/resources/$id'), headers: _headers()));
  }

  // --- Agents (Resource.Kind=Agent + AgentToken) ---
  /// Lists every Resource of Kind=Agent. Token info isn't joined here —
  /// hit [listAgentTokens] for the per-agent credential history.
  Future<List<Resource>> listAgents() async {
    final data = await _decode(await _http.get(_uri('/api/agents/'), headers: _headers()));
    return (data as List).cast<Map<String, dynamic>>().map(Resource.fromJson).toList();
  }

  /// Provisions a brand-new agent identity + first token. The raw token
  /// in the response is returned by the backend exactly once — UI must
  /// surface it immediately and warn the user that it cannot be recovered.
  Future<CreatedAgent> createAgent({
    required String name,
    String? role,
    String? description,
    RbacPresetFE rbac = RbacPresetFE.developer,
    int capacityPercent = 100,
  }) async {
    final data = await _decode(await _http.post(
      _uri('/api/agents/'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode({
        'name': name,
        'role': ?role,
        'description': ?description,
        'rbac': rbac.wire,
        'capacityPercent': capacityPercent,
      }),
    ));
    return CreatedAgent.fromJson(data as Map<String, dynamic>);
  }

  Future<List<AgentTokenSummary>> listAgentTokens(String agentId) async {
    final data = await _decode(await _http.get(
      _uri('/api/agents/$agentId/tokens'),
      headers: _headers(),
    ));
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(AgentTokenSummary.fromJson)
        .toList();
  }

  /// Atomic: revoke any active token row + issue a fresh one. Returns the
  /// new raw token (one-time only — same warn-and-copy UX as create).
  Future<RotatedToken> rotateAgentToken(String agentId) async {
    final data = await _decode(await _http.post(
      _uri('/api/agents/$agentId/rotate'),
      headers: _headers(),
    ));
    return RotatedToken.fromJson(data as Map<String, dynamic>);
  }

  /// Revokes every active token for the agent without re-issuing. After
  /// this the agent has no usable credential and Bearer auth fails 401
  /// until rotate runs.
  Future<int> revokeAgentTokens(String agentId) async {
    final data = await _decode(await _http.post(
      _uri('/api/agents/$agentId/revoke'),
      headers: _headers(),
    ));
    return ((data as Map<String, dynamic>)['revoked'] as num?)?.toInt() ?? 0;
  }

  // --- Agent plans (ADR-002 plan gate) ---
  /// Filtered plan list. Status filter drives the review queue (default
  /// PendingReview); taskId scopes to one task's plan history. Newest first.
  Future<List<AgentPlan>> listAgentPlans({
    PlanStatus? status,
    String? taskId,
    String? submittedBy,
  }) async {
    final query = <String, String>{};
    if (status != null) query['status'] = status.wire;
    if (taskId != null) query['taskId'] = taskId;
    if (submittedBy != null) query['submittedBy'] = submittedBy;
    final data = await _decode(await _http.get(
      _uri('/api/agents/plans', query.isEmpty ? null : query),
      headers: _headers(),
    ));
    return (data as List).cast<Map<String, dynamic>>().map(AgentPlan.fromJson).toList();
  }

  /// Approve a pending plan. Backend constraint: requires Human-class RBAC
  /// (Manager / Reviewer / Human preset). Side-effect: target task moves
  /// from PlanReview → InProgress in the same call.
  Future<AgentPlan> approveAgentPlan(String planId, {String? comment}) async {
    final data = await _decode(await _http.put(
      _uri('/api/agents/plans/$planId/approve'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode({'comment': ?comment}),
    ));
    return AgentPlan.fromJson(data as Map<String, dynamic>);
  }

  /// Reject a pending plan. [comment] is required by the backend so the
  /// agent has actionable feedback. Task moves back to InProgress per the
  /// 9-step lifecycle (bot picks back up with the rejection note in hand).
  Future<AgentPlan> rejectAgentPlan(String planId, {required String comment}) async {
    final data = await _decode(await _http.put(
      _uri('/api/agents/plans/$planId/reject'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode({'comment': comment}),
    ));
    return AgentPlan.fromJson(data as Map<String, dynamic>);
  }

  /// Undo a previous approve / reject. Backend gates this to the original
  /// reviewer (self-correction) or a Manager (override path). Plan goes
  /// back to PendingReview, task lifecycle reverts to PlanReview so the
  /// review queue re-surfaces it.
  Future<AgentPlan> revertAgentPlan(String planId) async {
    final data = await _decode(await _http.put(
      _uri('/api/agents/plans/$planId/revert'),
      headers: _headers(),
    ));
    return AgentPlan.fromJson(data as Map<String, dynamic>);
  }

  // --- Assignments ---
  Future<List<Assignment>> listAssignments({String? resourceId, String? taskId}) async {
    final query = <String, String>{};
    if (resourceId != null) query['resourceId'] = resourceId;
    if (taskId != null) query['taskId'] = taskId;
    final data = await _decode(await _http.get(
      _uri('/api/assignments', query.isEmpty ? null : query),
      headers: _headers(),
    ));
    return (data as List).cast<Map<String, dynamic>>().map(Assignment.fromJson).toList();
  }

  Future<Assignment> createAssignment(Assignment a) async {
    final data = await _decode(await _http.post(
      _uri('/api/assignments'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(a.toJson()),
    ));
    return Assignment.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteAssignment(String id) async {
    await _decode(await _http.delete(_uri('/api/assignments/$id'), headers: _headers()));
  }

  // --- Matrix ---
  Future<MatrixLoadResponse> matrixLoad({required DateTime from, required DateTime to}) async {
    final data = await _decode(await _http.get(
      _uri('/api/matrix/load', {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      }),
      headers: _headers(),
    ));
    return MatrixLoadResponse.fromJson(data as Map<String, dynamic>);
  }

  // --- Milestones ---
  Future<List<Milestone>> listMilestones(String projectId) async {
    final data = await _decode(await _http.get(
      _uri('/api/projects/$projectId/milestones'),
      headers: _headers(),
    ));
    return (data as List).cast<Map<String, dynamic>>().map(Milestone.fromJson).toList();
  }

  Future<Milestone> createMilestone(String projectId, Milestone m) async {
    final data = await _decode(await _http.post(
      _uri('/api/projects/$projectId/milestones'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(m.toJson()),
    ));
    return Milestone.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteMilestone(String id) async {
    await _decode(await _http.delete(_uri('/api/milestones/$id'), headers: _headers()));
  }

  // --- Work Calendar ---
  Future<WorkCalendarResponse> getWorkCalendar() async {
    final data = await _decode(await _http.get(_uri('/api/work-calendar'), headers: _headers()));
    return WorkCalendarResponse.fromJson(data as Map<String, dynamic>);
  }

  Future<WorkCalendar> updateWorkCalendar(WorkCalendar cal) async {
    final data = await _decode(await _http.put(
      _uri('/api/work-calendar'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(cal.toJson()),
    ));
    return WorkCalendar.fromJson(data as Map<String, dynamic>);
  }

  // --- Holiday subscriptions ---

  Future<List<HolidaySource>> listHolidaySources() async {
    final data = await _decode(await _http.get(_uri('/api/holiday-sources/'), headers: _headers()));
    return (data as List).cast<Map<String, dynamic>>().map(HolidaySource.fromJson).toList();
  }

  Future<HolidaySource> createHolidaySource(HolidaySource src) async {
    final data = await _decode(await _http.post(
      _uri('/api/holiday-sources/'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(src.toJson()),
    ));
    return HolidaySource.fromJson(data as Map<String, dynamic>);
  }

  Future<HolidaySource> updateHolidaySource(String id, HolidaySource patch) async {
    final data = await _decode(await _http.patch(
      _uri('/api/holiday-sources/$id'),
      headers: _headers(_jsonHeaders),
      body: jsonEncode(patch.toJson()),
    ));
    return HolidaySource.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteHolidaySource(String id) async {
    await _decode(await _http.delete(_uri('/api/holiday-sources/$id'), headers: _headers()));
  }

  Future<HolidaySource> refreshHolidaySource(String id) async {
    final data = await _decode(await _http.post(
      _uri('/api/holiday-sources/$id/refresh'),
      headers: _headers(),
    ));
    return HolidaySource.fromJson(data as Map<String, dynamic>);
  }

  /// Aggregated holiday list across all enabled sources within [from, to).
  Future<List<Holiday>> listHolidays({required DateTime from, required DateTime to}) async {
    final data = await _decode(await _http.get(
      _uri('/api/holidays', {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      }),
      headers: _headers(),
    ));
    return (data as List).cast<Map<String, dynamic>>().map(Holiday.fromJson).toList();
  }

  /// First-run helper: backend inserts one default subscription matching the
  /// user's locale (when no subscriptions exist yet) and marks it done so
  /// repeat calls are no-ops. Returns whether seeding actually happened —
  /// the caller can use that to decide whether to invalidate downstream
  /// holiday providers.
  Future<bool> autoSeedHolidaySources({required String locale}) async {
    final data = await _decode(await _http.post(
      _uri('/api/holiday-sources/auto-seed', {'locale': locale}),
      headers: _headers(),
    ));
    return (data as Map<String, dynamic>)['seeded'] as bool? ?? false;
  }

  // --- Change Logs ---
  Future<List<ChangeLog>> listChangeLogs({ChangeEntityType? entityType, String? entityId, int limit = 100}) async {
    final query = <String, String>{'limit': '$limit'};
    if (entityType != null) query['entityType'] = entityType.name;
    if (entityId != null) query['entityId'] = entityId;
    final data = await _decode(await _http.get(_uri('/api/change-logs', query), headers: _headers()));
    return (data as List).cast<Map<String, dynamic>>().map(ChangeLog.fromJson).toList();
  }
}
