// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'mora-knode';

  @override
  String get navMyWork => 'My work';

  @override
  String get navAllWork => 'All work';

  @override
  String get navProjects => 'Projects';

  @override
  String get navResources => 'Resources';

  @override
  String get navMatrix => 'Matrix';

  @override
  String get navPlans => 'Plans';

  @override
  String get navAudit => 'Change log';

  @override
  String get navAgents => 'Agents';

  @override
  String get navSettings => 'Settings';

  @override
  String get topbarOpenSidebar => 'Open sidebar  [';

  @override
  String get topbarCloseSidebar => 'Close sidebar  [';

  @override
  String get topbarOpenInspector => 'Open details  ]';

  @override
  String get topbarCloseInspector => 'Close details  ]';

  @override
  String get headerMyWork => 'My work';

  @override
  String get headerMyWorkSub => 'this week';

  @override
  String get headerAllWork => 'All work';

  @override
  String get headerProjects => 'Projects';

  @override
  String get headerResources => 'Resources';

  @override
  String get headerMatrixLoad => 'Matrix load';

  @override
  String get headerPlans => 'Plans';

  @override
  String get headerAudit => 'Change log';

  @override
  String get headerAgents => 'Agents';

  @override
  String get headerSettings => 'Settings';

  @override
  String get tabList => 'List';

  @override
  String get tabGantt => 'Gantt';

  @override
  String get tabCalendar => 'Calendar';

  @override
  String get newTask => 'New task';

  @override
  String get comingSoon => 'Coming in the next stage of the redesign.';

  @override
  String get comingProjectsDirectory => 'Projects directory';

  @override
  String get comingResources => 'Resources';

  @override
  String get comingPlanReviewQueue => 'Plan review queue (M2)';

  @override
  String get comingChangeLog => 'Change log';

  @override
  String get comingAgentRbac => 'Agent identity & RBAC (M2)';

  @override
  String get badgeM2 => 'M2';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageHint =>
      'Affects all UI strings. Restart not required.';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsAdminOnlyTitle =>
      'Settings are visible to admin roles only.';

  @override
  String get settingsAdminOnlyHint =>
      'Switch to the ysh user from the sidebar to edit WorkCalendar and other org-level settings.';

  @override
  String get settingsWorkCalendar => 'Work Calendar';

  @override
  String get settingsWorkCalendarHint =>
      'Drives matrix load calculation, calendar week-mode hour grid, and gantt overlays.';

  @override
  String get settingsWorkCalendarFallback =>
      'No WorkCalendar configured yet. Showing the 24/7 fallback. Saving will create the document and start scoping matrix load to work hours.';

  @override
  String get settingsWorkDays => 'Work days';

  @override
  String get settingsDailyHoursLocal => 'Daily hours (local)';

  @override
  String get settingsTimeStart => 'Start';

  @override
  String get settingsTimeEnd => 'End';

  @override
  String get settingsTimezone => 'Timezone';

  @override
  String get settingsTimezoneHint => 'e.g. Asia/Seoul';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSaving => 'Saving…';

  @override
  String get actionReset => 'Reset';

  @override
  String get stateUnsavedChanges => 'Unsaved changes';

  @override
  String errorPrefix(String detail) {
    return 'Error: $detail';
  }

  @override
  String get myWorkBannerNoUser =>
      'No user selected — showing every assignment. Pick a user from the sidebar bottom to see only their work.';

  @override
  String get myWorkLaneThisWeek => 'This week';

  @override
  String get myWorkLaneNextWeek => 'Next week';

  @override
  String myWorkLaneOverdue(int count) {
    return 'Overdue ($count)';
  }

  @override
  String get myWorkEmptyThisWeek => 'Nothing scheduled this week.';

  @override
  String get myWorkEmptyNextWeek => 'Next week is open.';

  @override
  String get myWorkEmptyOverdue => 'No overdue tasks.';

  @override
  String get filterProject => 'Project';

  @override
  String get filterAssignee => 'Assignee';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterShowAll => 'Show all';

  @override
  String get filterClearAll => 'Clear all';

  @override
  String get filterClearSearch => 'Clear search';

  @override
  String filterByLabel(String label) {
    return 'Filter by $label';
  }

  @override
  String filterAllSuffix(String label) {
    return '$label: all';
  }

  @override
  String filterCountSuffix(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get filterSearchHint => 'Search title…';

  @override
  String filterCounter(int projects, int resources) {
    return '$projects projects · $resources resources';
  }

  @override
  String get filterNoMatch => 'No tasks match the current filters.';

  @override
  String get inspectorTitle => 'Details';

  @override
  String get inspectorEmpty =>
      'Select a task, project, or plan to see its details here.';

  @override
  String get userSwitcherTooltip => 'Switch user (dev only)';

  @override
  String get userSwitcherLoading => 'Loading users…';

  @override
  String get userSwitcherAnonymous => 'anonymous';

  @override
  String get userSwitcherAnonymousAdmin => 'anonymous (admin)';

  @override
  String get userSwitcherAdminCaption => 'admin (no header)';

  @override
  String get taskStatusCreated => 'Created';

  @override
  String get taskStatusPlanning => 'Planning';

  @override
  String get taskStatusPlanReview => 'Plan review';

  @override
  String get taskStatusInProgress => 'In progress';

  @override
  String get taskStatusWorkReview => 'Work review';

  @override
  String get taskStatusOnHold => 'On hold';

  @override
  String get taskStatusDone => 'Done';

  @override
  String get taskStatusCancelled => 'Cancelled';

  @override
  String get taskStatusDropped => 'Dropped';

  @override
  String get taskStatusCancelledTooltip => 'Cancelled at planning stage';

  @override
  String get taskStatusDroppedTooltip =>
      'Dropped after work (kept for reference)';

  @override
  String get taskWaitingToggle => 'Waiting';

  @override
  String get taskWaitingTooltip => 'Mark as waiting (different from On hold)';

  @override
  String get taskPriorityUnset => 'Unset';

  @override
  String get taskPriorityLow => 'Low';

  @override
  String get taskPriorityNormal => 'Normal';

  @override
  String get taskPriorityHigh => 'High';

  @override
  String get taskPriorityUrgent => 'Urgent';

  @override
  String get filterPriority => 'Priority';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortAddStep => 'Add sort';

  @override
  String get sortKeyPriority => 'Priority';

  @override
  String get sortKeyStartDate => 'Start date';

  @override
  String get sortKeyDueDate => 'Due date';

  @override
  String get sortKeyStatus => 'Status';

  @override
  String get sortKeyNumber => 'Number';

  @override
  String get sortPriorityUrgentFirst => 'Urgent first';

  @override
  String get sortPriorityUnsetFirst => 'Unset first';

  @override
  String get sortStartDateEarliestFirst => 'Earliest start first';

  @override
  String get sortStartDateLatestFirst => 'Latest start first';

  @override
  String get sortDueDateSoonestFirst => 'Soonest first';

  @override
  String get sortDueDateLatestFirst => 'Latest first';

  @override
  String get sortStatusActiveFirst => 'Active first';

  @override
  String get sortStatusDoneFirst => 'Done first';

  @override
  String get sortNumberLowFirst => 'Lower number first';

  @override
  String get sortNumberHighFirst => 'Higher number first';

  @override
  String taskStatusAggregatedSuffix(String label) {
    return '$label*';
  }

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionAdd => 'Add';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionToday => 'today';

  @override
  String get taskEditorFieldTitle => 'Title *';

  @override
  String get taskEditorFieldDescription => 'Description';

  @override
  String get taskEditorFieldStatus => 'Status';

  @override
  String get taskEditorFieldParent => 'Parent (optional)';

  @override
  String get taskEditorFieldProject => 'Project *';

  @override
  String get taskEditorParentTopLevel => '— Top level —';

  @override
  String get taskEditorChangeReason => 'Change reason (logged)';

  @override
  String get taskEditorChangedBy => 'Changed by';

  @override
  String get taskEditorAllDay => 'All-day';

  @override
  String get taskEditorTimed => 'Timed';

  @override
  String get taskEditorTitleNew => 'New task';

  @override
  String get taskEditorTitleEdit => 'Edit task';

  @override
  String get actionCreate => 'Create';

  @override
  String get timelineL1Origin => 'L1 Origin';

  @override
  String get timelineL2Current => 'L2 Current';

  @override
  String get timelineL3Real => 'L3 Real';

  @override
  String get timelineSummaryGroup => 'Group';

  @override
  String get timelineAllDayBadge => 'all-day';

  @override
  String get timelineTimedBadge => 'timed';

  @override
  String get inspectorSectionNotes => 'Notes';

  @override
  String get inspectorSectionTimelines => 'Timelines';

  @override
  String get inspectorSectionAssignees => 'Assignees';

  @override
  String get inspectorSectionChildren => 'Children';

  @override
  String get inspectorSectionRecentChanges => 'Recent changes';

  @override
  String get inspectorSectionStats => 'Stats';

  @override
  String get inspectorSectionMilestones => 'Milestones';

  @override
  String get inspectorSectionTopLevel => 'Top-level tasks';

  @override
  String get taskInspectorNotFound =>
      'Task not found (or hidden by view scope).';

  @override
  String get projectInspectorNotFound =>
      'Project not found (or hidden by view scope).';

  @override
  String get notesPlaceholderEmpty => 'Click to add notes…';

  @override
  String get notesHint => 'Markdown-friendly notes about this task';

  @override
  String get notesSaveHint => 'Click outside or press Esc to save';

  @override
  String get notesNoChanges => 'No changes yet.';

  @override
  String get deleteTaskTitle => 'Delete task?';

  @override
  String deleteTaskBody(String title) {
    return '\"$title\" will be removed permanently.';
  }

  @override
  String projectStats(int leaf, int group) {
    return '$leaf leaf tasks · $group group tasks';
  }

  @override
  String projectCreated(String date) {
    return 'created $date';
  }

  @override
  String get calendarMonth => 'Month';

  @override
  String get calendarWeek => 'Week';

  @override
  String calendarWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get navPrevious => 'Previous';

  @override
  String get navNext => 'Next';

  @override
  String get navPreviousWeek => 'Previous week';

  @override
  String get navNextWeek => 'Next week';

  @override
  String get matrixEditCalendar => 'Edit calendar';

  @override
  String get matrixHeaderResource => 'Resource';

  @override
  String matrixWorkCalendarLabel(String detail) {
    return 'WorkCalendar: $detail';
  }

  @override
  String get matrixWorkCalendarFallback => '24/7 fallback';

  @override
  String get ganttNoTasks => 'No tasks yet.';

  @override
  String get ganttNoTimeline =>
      'No timeline data yet. Add Current timeline to tasks.';

  @override
  String get ganttColTask => 'Task';

  @override
  String get ganttZoomDay => 'Day';

  @override
  String get ganttZoomWeek => 'Week';

  @override
  String get ganttZoomMonth => 'Month';

  @override
  String get projectsDirectoryTitle => 'Project list';

  @override
  String get projectsDirectoryEmpty => 'No projects yet.';

  @override
  String get projectPickPrompt => 'Pick a project from the list on the left.';

  @override
  String get projectTabOverview => 'Overview';

  @override
  String get projectTabTasks => 'Tasks';

  @override
  String get projectTabIssues => 'Issues';

  @override
  String get projectTabInitiatives => 'Initiatives';

  @override
  String get projectTabDocuments => 'Documents';

  @override
  String get projectBackToDirectory => 'Back to list';

  @override
  String get projectIssuesComing => 'Issue triage';

  @override
  String get projectInitiativesComing => 'Project initiatives';

  @override
  String get projectDocumentsComing => 'Project documents';

  @override
  String projectOverviewCounts(int tasks, int milestones) {
    return '$tasks tasks · $milestones milestones';
  }

  @override
  String get projectTasksEmpty => 'No tasks in this project.';

  @override
  String get projectTaskOpenInAllWork => 'Open in All work';

  @override
  String get actionCopy => 'Copy';

  @override
  String get agentsSectionLead =>
      'Manage external AI agent identities and their auth tokens. Tokens are shown exactly once at issuance.';

  @override
  String get agentsCreateButton => '+ New agent';

  @override
  String get agentsEmptyTitle => 'No agents yet';

  @override
  String get agentsEmptyHint =>
      'Use + New agent to provision the first identity and receive its token.';

  @override
  String get agentsRotateTooltip =>
      'Rotate token (existing key is revoked immediately)';

  @override
  String get agentsRevokeTooltip => 'Revoke all tokens (no auth until rotated)';

  @override
  String get agentsExpandTokens => 'Show token history';

  @override
  String get agentsCollapseTokens => 'Hide token history';

  @override
  String get agentsRotatedTitle => 'New token issued';

  @override
  String get agentsCreatedTitle => 'Agent created';

  @override
  String get agentsRevokeConfirmTitle => 'Revoke tokens?';

  @override
  String agentsRevokeConfirmBody(String name) {
    return 'All active tokens for \"$name\" will be invalidated. Rotation is required to use the agent again.';
  }

  @override
  String get agentsRevokeConfirmAction => 'Revoke';

  @override
  String agentsRevokedToast(int count) {
    return 'Revoked $count token(s).';
  }

  @override
  String get agentsTokensEmpty => 'No token history.';

  @override
  String get agentsTokenActive => 'active';

  @override
  String agentsTokenRevokedAt(String at) {
    return 'revoked · $at';
  }

  @override
  String agentsTokenCreatedAt(String at) {
    return 'issued · $at';
  }

  @override
  String get agentsCreateDialogTitle => 'New agent';

  @override
  String get agentsFieldName => 'Name *';

  @override
  String get agentsFieldRole => 'Role (optional)';

  @override
  String get agentsFieldDescription => 'Description (optional)';

  @override
  String get agentsFieldDescriptionHint =>
      'Model / tooling / prompt provenance, etc.';

  @override
  String get agentsFieldRbac => 'RBAC preset';

  @override
  String get agentsFieldNameRequired => 'Name is required.';

  @override
  String get agentsCreateConfirm => 'Create and reveal token';

  @override
  String get agentsTokenRevealWarning =>
      'This token is shown only once. Copy it somewhere safe before closing.';

  @override
  String agentsTokenRevealHint(String lastFour) {
    return 'Last 4 chars: …$lastFour';
  }

  @override
  String get agentsTokenRevealAcknowledge => 'I\'ve saved it';

  @override
  String get plansSectionLead =>
      'Review and decide on plans submitted by external agents. Approving moves the task to InProgress automatically.';

  @override
  String get plansFilterPending => 'Pending review';

  @override
  String get plansFilterApproved => 'Approved';

  @override
  String get plansFilterRejected => 'Rejected';

  @override
  String get plansFilterAll => 'All';

  @override
  String get plansEmptyPendingTitle => 'No plans awaiting review';

  @override
  String get plansEmptyPendingHint => 'Plans submitted by agents land here.';

  @override
  String get plansEmptyApprovedTitle => 'No approved plans yet';

  @override
  String get plansEmptyApprovedHint =>
      'Approved pending items accumulate here.';

  @override
  String get plansEmptyRejectedTitle => 'No rejected plans yet';

  @override
  String get plansEmptyRejectedHint =>
      'Plans you reject (with comments) collect here.';

  @override
  String get plansEmptyAllTitle => 'No plans yet';

  @override
  String get plansEmptyAllHint => 'Agents will surface their plans here.';

  @override
  String plansTaskUnknown(String id) {
    return 'task $id (not found)';
  }

  @override
  String plansEstimateMinutes(int minutes) {
    return '~${minutes}m';
  }

  @override
  String get plansStepsHeader => 'Steps';

  @override
  String get plansNotesHeader => 'Notes';

  @override
  String get plansReviewerCommentHeader => 'Reviewer comment';

  @override
  String get plansActionApprove => 'Approve';

  @override
  String get plansActionReject => 'Reject';

  @override
  String get plansApprovedToast => 'Plan approved. Task moved to InProgress.';

  @override
  String get plansRejectedToast => 'Plan rejected.';

  @override
  String get plansRejectDialogTitle => 'Reject plan';

  @override
  String get plansRejectDialogHint =>
      'Tell the agent what needs to change. The comment is stored on the plan and the ChangeLog.';

  @override
  String get plansRejectFieldComment => 'Reason *';

  @override
  String get plansRejectFieldRequired => 'Reason is required.';

  @override
  String get plansRejectConfirm => 'Reject';

  @override
  String get plansAuthBannerTitle => 'Pick a user first';

  @override
  String get plansAuthBannerHint =>
      'Approve / reject / revert are restricted to authenticated users. Use the user switcher at the bottom of the sidebar to select your account.';

  @override
  String plansReviewedBy(String by, String at) {
    return '$by · $at';
  }

  @override
  String get plansActionRevert => 'Revert decision';

  @override
  String get plansRevertedToast =>
      'Decision reverted. Plan is back to Pending review.';

  @override
  String get plansRevertConfirmTitle => 'Revert this decision?';

  @override
  String get plansRevertConfirmBody =>
      'The plan returns to Pending review and the task lifecycle goes back to PlanReview.';

  @override
  String get plansRevertConfirmAction => 'Revert';

  @override
  String get auditSectionLead =>
      'Every change to projects, tasks, and milestones in one place — status, IsWaiting, plan approve/reject/revert, and timeline edits are all logged automatically.';

  @override
  String get auditFilterAll => 'All';

  @override
  String get auditFilterTask => 'Tasks';

  @override
  String get auditFilterProject => 'Projects';

  @override
  String get auditFilterMilestone => 'Milestones';

  @override
  String auditLimitN(int n) {
    return '$n per page';
  }

  @override
  String get auditRefresh => 'Reload';

  @override
  String get auditEmptyTitle => 'No change history yet';

  @override
  String get auditEmptyHint =>
      'Try changing the filter or raising the page size. New activity accumulates here automatically.';

  @override
  String auditCount(int n) {
    return '$n entries';
  }

  @override
  String get auditValueNone => '(none)';

  @override
  String get auditChangedByUnknown => '(unknown)';

  @override
  String auditEntityTaskUnknown(String id) {
    return 'task $id (not found)';
  }

  @override
  String auditEntityProjectUnknown(String id) {
    return 'project $id (not found)';
  }

  @override
  String auditEntityMilestone(String id) {
    return 'milestone $id';
  }

  @override
  String get auditFilterProjectScope => 'Project';

  @override
  String get auditFilterFrom => 'From';

  @override
  String get auditFilterTo => 'To';

  @override
  String get auditFilterClear => 'Clear filters';

  @override
  String auditPageRange(int first, int last, int total) {
    return '$first–$last of $total';
  }

  @override
  String auditPageOf(int page, int total) {
    return '$page / $total';
  }

  @override
  String get auditPagePrev => 'Previous page';

  @override
  String get auditPageNext => 'Next page';

  @override
  String auditCountOf(int n, int total) {
    return 'Showing $n of $total';
  }

  @override
  String get matrixEmpty => 'No resources to show.';

  @override
  String get matrixEmptyFiltered => 'No resources match the selected filters.';

  @override
  String get matrixFilterDepartment => 'Department';

  @override
  String get matrixFilterProject => 'Project';

  @override
  String get matrixFilterAll => 'All';

  @override
  String get matrixFilterClear => 'Clear filters';

  @override
  String get matrixFilterActiveHint => 'Filters active';
}
