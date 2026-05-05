// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppL10nKo extends AppL10n {
  AppL10nKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'mora-knode';

  @override
  String get navMyWork => '내 업무';

  @override
  String get navAllWork => '전체 업무';

  @override
  String get navProjects => '프로젝트';

  @override
  String get navResources => '리소스';

  @override
  String get navMatrix => '매트릭스';

  @override
  String get navPlans => '플랜';

  @override
  String get navAudit => '변경 이력';

  @override
  String get navAgents => '에이전트';

  @override
  String get navSettings => '설정';

  @override
  String get topbarOpenSidebar => '사이드바 열기  [';

  @override
  String get topbarCloseSidebar => '사이드바 닫기  [';

  @override
  String get topbarOpenInspector => '세부 정보 열기  ]';

  @override
  String get topbarCloseInspector => '세부 정보 닫기  ]';

  @override
  String get headerMyWork => '내 업무';

  @override
  String get headerMyWorkSub => '이번 주';

  @override
  String get headerAllWork => '전체 업무';

  @override
  String get headerProjects => '프로젝트';

  @override
  String get headerResources => '리소스';

  @override
  String get headerMatrixLoad => '매트릭스 부하';

  @override
  String get headerPlans => '플랜';

  @override
  String get headerAudit => '변경 이력';

  @override
  String get headerAgents => '에이전트';

  @override
  String get headerSettings => '설정';

  @override
  String get tabList => '목록';

  @override
  String get tabGantt => '간트';

  @override
  String get tabCalendar => '캘린더';

  @override
  String get newTask => '새 업무';

  @override
  String get comingSoon => '재설계 다음 단계에서 추가됩니다.';

  @override
  String get comingProjectsDirectory => '프로젝트 디렉터리';

  @override
  String get comingResources => '리소스';

  @override
  String get comingPlanReviewQueue => '플랜 검토 큐 (M2)';

  @override
  String get comingChangeLog => '변경 이력';

  @override
  String get comingAgentRbac => '에이전트 식별 & RBAC (M2)';

  @override
  String get badgeM2 => 'M2';

  @override
  String get settingsLanguage => '언어';

  @override
  String get settingsLanguageHint => '모든 UI 문자열에 적용됩니다. 재시작 없이 즉시 반영.';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageEnglish => 'English';

  @override
  String get settingsTheme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get settingsAdminOnlyTitle => '설정은 관리자 권한에서만 표시됩니다.';

  @override
  String get settingsAdminOnlyHint =>
      '사이드바에서 ysh 사용자로 전환하면 WorkCalendar 등 조직 설정을 편집할 수 있습니다.';

  @override
  String get settingsWorkCalendar => 'Work Calendar';

  @override
  String get settingsWorkCalendarHint =>
      '매트릭스 부하 계산, 캘린더 주간 모드 시간 그리드, 간트 오버레이의 기준값.';

  @override
  String get settingsWorkCalendarFallback =>
      '아직 WorkCalendar가 설정되지 않아 24/7 기본값으로 표시 중입니다. 저장하면 문서가 생성되어 매트릭스 부하가 업무 시간 기준으로 한정됩니다.';

  @override
  String get settingsWorkDays => '근무 요일';

  @override
  String get settingsDailyHoursLocal => '일일 근무 시간 (로컬)';

  @override
  String get settingsTimeStart => '시작';

  @override
  String get settingsTimeEnd => '종료';

  @override
  String get settingsTimezone => '타임존';

  @override
  String get settingsTimezoneHint => '예: Asia/Seoul';

  @override
  String get actionSave => '저장';

  @override
  String get actionSaving => '저장 중…';

  @override
  String get actionReset => '리셋';

  @override
  String get stateUnsavedChanges => '저장되지 않은 변경';

  @override
  String errorPrefix(String detail) {
    return '오류: $detail';
  }

  @override
  String get myWorkBannerNoUser =>
      '선택된 사용자가 없습니다 — 모든 배정을 표시 중. 사이드바 하단에서 사용자를 선택하면 본인 업무만 봅니다.';

  @override
  String get myWorkLaneThisWeek => '이번 주';

  @override
  String get myWorkLaneNextWeek => '다음 주';

  @override
  String myWorkLaneOverdue(int count) {
    return '지연 ($count)';
  }

  @override
  String get myWorkEmptyThisWeek => '이번 주에 잡힌 업무가 없습니다.';

  @override
  String get myWorkEmptyNextWeek => '다음 주는 비어 있습니다.';

  @override
  String get myWorkEmptyOverdue => '지연된 업무가 없습니다.';

  @override
  String get filterProject => '프로젝트';

  @override
  String get filterAssignee => '담당자';

  @override
  String get filterStatus => '상태';

  @override
  String get filterShowAll => '전체 표시';

  @override
  String get filterClearAll => '전체 해제';

  @override
  String get filterClearSearch => '검색어 지우기';

  @override
  String filterByLabel(String label) {
    return '$label 필터';
  }

  @override
  String filterAllSuffix(String label) {
    return '$label: 전체';
  }

  @override
  String filterCountSuffix(String label, int count) {
    return '$label ($count)';
  }

  @override
  String get filterSearchHint => '제목 검색…';

  @override
  String filterCounter(int projects, int resources) {
    return '프로젝트 $projects · 리소스 $resources';
  }

  @override
  String get filterNoMatch => '필터 조건에 맞는 업무가 없습니다.';

  @override
  String get inspectorTitle => '세부 정보';

  @override
  String get inspectorEmpty => '업무·프로젝트·플랜을 선택하면 여기에 세부 정보가 표시됩니다.';

  @override
  String get userSwitcherTooltip => '사용자 전환 (개발 모드)';

  @override
  String get userSwitcherLoading => '사용자 목록 로딩 중…';

  @override
  String get userSwitcherAnonymous => 'anonymous';

  @override
  String get userSwitcherAnonymousAdmin => 'anonymous (관리자)';

  @override
  String get userSwitcherAdminCaption => '관리자 (헤더 없음)';

  @override
  String get taskStatusCreated => '생성';

  @override
  String get taskStatusPlanning => '작업계획 작성';

  @override
  String get taskStatusPlanReview => '작업계획 리뷰';

  @override
  String get taskStatusInProgress => '진행 중';

  @override
  String get taskStatusWorkReview => '코드 리뷰';

  @override
  String get taskStatusOnHold => '보류';

  @override
  String get taskStatusDone => '완료';

  @override
  String get taskStatusCancelled => '취소';

  @override
  String get taskStatusDropped => '드랍';

  @override
  String get taskStatusCancelledTooltip => '계획 단계 취소';

  @override
  String get taskStatusDroppedTooltip => '작업 후 폐기 (반영·학습 가치)';

  @override
  String get taskWaitingToggle => '대기 표시';

  @override
  String get taskWaitingTooltip => '진행 막힘 표시 (보류와 다름)';

  @override
  String get taskPriorityUnset => '미설정';

  @override
  String get taskPriorityLow => '낮음';

  @override
  String get taskPriorityNormal => '보통';

  @override
  String get taskPriorityHigh => '높음';

  @override
  String get taskPriorityUrgent => '긴급';

  @override
  String get filterPriority => '우선순위';

  @override
  String get sortBy => '정렬';

  @override
  String get sortAddStep => '정렬 추가';

  @override
  String get sortKeyPriority => '우선순위';

  @override
  String get sortKeyStartDate => '시작일';

  @override
  String get sortKeyDueDate => '마감일';

  @override
  String get sortKeyStatus => '상태';

  @override
  String get sortKeyNumber => '번호';

  @override
  String get sortPriorityUrgentFirst => '긴급 먼저';

  @override
  String get sortPriorityUnsetFirst => '미설정 먼저';

  @override
  String get sortStartDateEarliestFirst => '이른 시작 먼저';

  @override
  String get sortStartDateLatestFirst => '늦은 시작 먼저';

  @override
  String get sortDueDateSoonestFirst => '임박 먼저';

  @override
  String get sortDueDateLatestFirst => '여유 먼저';

  @override
  String get sortStatusActiveFirst => '활성 먼저';

  @override
  String get sortStatusDoneFirst => '종료 먼저';

  @override
  String get sortNumberLowFirst => '낮은 번호 먼저';

  @override
  String get sortNumberHighFirst => '높은 번호 먼저';

  @override
  String taskStatusAggregatedSuffix(String label) {
    return '$label*';
  }

  @override
  String get actionEdit => '편집';

  @override
  String get actionDelete => '삭제';

  @override
  String get actionCancel => '취소';

  @override
  String get actionAdd => '추가';

  @override
  String get actionClear => '지우기';

  @override
  String get actionToday => '오늘';

  @override
  String get taskEditorFieldTitle => '제목 *';

  @override
  String get taskEditorFieldDescription => '설명';

  @override
  String get taskEditorFieldStatus => '상태';

  @override
  String get taskEditorFieldParent => '상위 업무 (선택)';

  @override
  String get taskEditorFieldProject => '프로젝트 *';

  @override
  String get taskEditorParentTopLevel => '— 최상위 —';

  @override
  String get taskEditorChangeReason => '변경 사유 (기록됨)';

  @override
  String get taskEditorChangedBy => '변경자';

  @override
  String get taskEditorAllDay => '종일';

  @override
  String get taskEditorTimed => '시간 지정';

  @override
  String get taskEditorTitleNew => '새 업무';

  @override
  String get taskEditorTitleEdit => '업무 편집';

  @override
  String get actionCreate => '생성';

  @override
  String get timelineL1Origin => 'L1 기준';

  @override
  String get timelineL2Current => 'L2 현재';

  @override
  String get timelineL3Real => 'L3 실제';

  @override
  String get timelineSummaryGroup => '그룹';

  @override
  String get timelineAllDayBadge => '종일';

  @override
  String get timelineTimedBadge => '시간 지정';

  @override
  String get inspectorSectionNotes => '메모';

  @override
  String get inspectorSectionTimelines => '타임라인';

  @override
  String get inspectorSectionAssignees => '담당자';

  @override
  String get inspectorSectionChildren => '하위 업무';

  @override
  String get inspectorSectionRecentChanges => '최근 변경';

  @override
  String get inspectorSectionComments => '코멘트';

  @override
  String get commentsEmpty => '아직 코멘트가 없습니다.';

  @override
  String get commentAddHint => '코멘트 작성…';

  @override
  String get commentPostButton => '작성';

  @override
  String get commentSavingHint => '업로드 중…';

  @override
  String get commentEdit => '수정';

  @override
  String get commentDelete => '삭제';

  @override
  String get commentDeleteConfirmTitle => '코멘트를 삭제할까요?';

  @override
  String get commentDeleteConfirmBody => '이 코멘트가 영구적으로 삭제됩니다.';

  @override
  String get commentSaveButton => '저장';

  @override
  String get commentCancelButton => '취소';

  @override
  String get commentExpand => '펼치기';

  @override
  String get commentCollapse => '접기';

  @override
  String get commentKindReview => '리뷰';

  @override
  String get commentKindBug => '버그';

  @override
  String get commentKindQa => 'QA';

  @override
  String get commentKindNote => '노트';

  @override
  String get commentLoginRequired => '로그인 후 코멘트를 작성할 수 있습니다.';

  @override
  String commentDeleteFailed(String error) {
    return '삭제 실패: $error';
  }

  @override
  String commentRelativeMinutes(int n) {
    return '$n분 전';
  }

  @override
  String commentRelativeHours(int n) {
    return '$n시간 전';
  }

  @override
  String get commentRelativeJustNow => '방금 전';

  @override
  String get inspectorSectionStats => '통계';

  @override
  String get inspectorSectionMilestones => '마일스톤';

  @override
  String get inspectorSectionTopLevel => '최상위 업무';

  @override
  String get taskInspectorNotFound => '업무를 찾을 수 없습니다 (또는 권한으로 숨겨짐).';

  @override
  String get projectInspectorNotFound => '프로젝트를 찾을 수 없습니다 (또는 권한으로 숨겨짐).';

  @override
  String get notesPlaceholderEmpty => '클릭해서 메모 추가…';

  @override
  String get notesHint => '이 업무에 대한 메모 (Markdown 형식)';

  @override
  String get notesSaveHint => '외부 클릭 또는 Esc로 저장';

  @override
  String get notesNoChanges => '변경 이력이 아직 없습니다.';

  @override
  String get deleteTaskTitle => '업무를 삭제할까요?';

  @override
  String deleteTaskBody(String title) {
    return '\"$title\" 항목이 영구적으로 삭제됩니다.';
  }

  @override
  String projectStats(int leaf, int group) {
    return '리프 업무 $leaf · 그룹 업무 $group';
  }

  @override
  String projectCreated(String date) {
    return '$date 생성';
  }

  @override
  String get calendarMonth => '월간';

  @override
  String get calendarWeek => '주간';

  @override
  String calendarWeekOf(String date) {
    return '$date 주';
  }

  @override
  String get navPrevious => '이전';

  @override
  String get navNext => '다음';

  @override
  String get navPreviousWeek => '이전 주';

  @override
  String get navNextWeek => '다음 주';

  @override
  String get matrixEditCalendar => '캘린더 편집';

  @override
  String get matrixHeaderResource => '리소스';

  @override
  String matrixWorkCalendarLabel(String detail) {
    return 'WorkCalendar: $detail';
  }

  @override
  String get matrixWorkCalendarFallback => '24/7 기본값';

  @override
  String get ganttNoTasks => '아직 업무가 없습니다.';

  @override
  String get ganttNoTimeline => '타임라인 데이터가 없습니다. 업무에 L2 현재 타임라인을 추가하세요.';

  @override
  String get ganttColTask => '업무';

  @override
  String get ganttZoomDay => '일';

  @override
  String get ganttZoomWeek => '주';

  @override
  String get ganttZoomMonth => '월';

  @override
  String get projectsDirectoryTitle => '프로젝트 목록';

  @override
  String get projectsDirectoryEmpty => '아직 프로젝트가 없습니다.';

  @override
  String get projectPickPrompt => '왼쪽 목록에서 프로젝트를 선택하세요.';

  @override
  String get projectTabOverview => '개요';

  @override
  String get projectTabTasks => '업무';

  @override
  String get projectTabIssues => '이슈';

  @override
  String get projectTabInitiatives => '기획';

  @override
  String get projectTabDocuments => '문서';

  @override
  String get projectBackToDirectory => '목록으로';

  @override
  String get projectIssuesComing => '이슈 트리아지';

  @override
  String get projectInitiativesComing => '프로젝트 기획';

  @override
  String get projectDocumentsComing => '프로젝트 문서';

  @override
  String projectOverviewCounts(int tasks, int milestones) {
    return '업무 $tasks · 마일스톤 $milestones';
  }

  @override
  String get projectTasksEmpty => '이 프로젝트에 업무가 없습니다.';

  @override
  String get projectTaskOpenInAllWork => '전체 업무에서 보기';

  @override
  String get actionCopy => '복사';

  @override
  String get agentsSectionLead =>
      '외부 AI 에이전트의 식별과 인증 토큰을 관리합니다. 토큰은 발급 직후 한 번만 표시됩니다.';

  @override
  String get agentsCreateButton => '+ 새 에이전트';

  @override
  String get agentsEmptyTitle => '아직 등록된 에이전트가 없습니다';

  @override
  String get agentsEmptyHint => '+ 새 에이전트 버튼으로 첫 에이전트를 만들고 토큰을 받으세요.';

  @override
  String get agentsRotateTooltip => '토큰 재발급 (기존은 즉시 무효)';

  @override
  String get agentsRevokeTooltip => '모든 토큰 폐기 (재발급 전까지 인증 불가)';

  @override
  String get agentsExpandTokens => '토큰 이력 보기';

  @override
  String get agentsCollapseTokens => '토큰 이력 닫기';

  @override
  String get agentsRotatedTitle => '새 토큰이 발급되었습니다';

  @override
  String get agentsCreatedTitle => '에이전트가 생성되었습니다';

  @override
  String get agentsRevokeConfirmTitle => '토큰을 폐기할까요?';

  @override
  String agentsRevokeConfirmBody(String name) {
    return '\"$name\" 의 모든 활성 토큰이 무효화됩니다. 다시 사용하려면 토큰을 재발급해야 합니다.';
  }

  @override
  String get agentsRevokeConfirmAction => '폐기';

  @override
  String agentsRevokedToast(int count) {
    return '$count개 토큰이 폐기되었습니다.';
  }

  @override
  String get agentsTokensEmpty => '토큰 이력이 없습니다.';

  @override
  String get agentsTokenActive => '활성';

  @override
  String agentsTokenRevokedAt(String at) {
    return '폐기됨 · $at';
  }

  @override
  String agentsTokenCreatedAt(String at) {
    return '발급 · $at';
  }

  @override
  String get agentsCreateDialogTitle => '새 에이전트';

  @override
  String get agentsFieldName => '이름 *';

  @override
  String get agentsFieldRole => '역할 (선택)';

  @override
  String get agentsFieldDescription => '설명 (선택)';

  @override
  String get agentsFieldDescriptionHint => '사용 모델 / 도구 셋 / 프롬프트 출처 등';

  @override
  String get agentsFieldRbac => 'RBAC 프리셋';

  @override
  String get agentsFieldNameRequired => '이름은 필수입니다.';

  @override
  String get agentsCreateConfirm => '생성하고 토큰 받기';

  @override
  String get agentsTokenRevealWarning =>
      '이 토큰은 지금 한 번만 표시됩니다. 닫기 전 안전한 곳에 복사해두세요.';

  @override
  String agentsTokenRevealHint(String lastFour) {
    return '끝 4자리: …$lastFour';
  }

  @override
  String get agentsTokenRevealAcknowledge => '확인했고 저장했습니다';

  @override
  String get plansSectionLead =>
      '외부 에이전트가 제출한 작업계획을 검토하고 승인 또는 반려합니다. 승인된 plan 의 task 는 자동으로 InProgress 로 전환됩니다.';

  @override
  String get plansFilterPending => '검토 대기';

  @override
  String get plansFilterApproved => '승인됨';

  @override
  String get plansFilterRejected => '반려됨';

  @override
  String get plansFilterAll => '전체';

  @override
  String get plansEmptyPendingTitle => '검토 대기 중인 plan 이 없습니다';

  @override
  String get plansEmptyPendingHint => '에이전트가 plan 을 제출하면 여기로 들어옵니다.';

  @override
  String get plansEmptyApprovedTitle => '승인된 plan 이 없습니다';

  @override
  String get plansEmptyApprovedHint => '검토 대기 항목을 승인하면 이 목록에 누적됩니다.';

  @override
  String get plansEmptyRejectedTitle => '반려된 plan 이 없습니다';

  @override
  String get plansEmptyRejectedHint => '반려 사유와 함께 반려한 plan 들이 여기에 모입니다.';

  @override
  String get plansEmptyAllTitle => 'plan 이 아직 없습니다';

  @override
  String get plansEmptyAllHint => '에이전트가 작업계획을 제출하면 여기에 표시됩니다.';

  @override
  String plansTaskUnknown(String id) {
    return 'task $id (찾을 수 없음)';
  }

  @override
  String plansEstimateMinutes(int minutes) {
    return '예상 $minutes분';
  }

  @override
  String get plansStepsHeader => '단계';

  @override
  String get plansNotesHeader => '노트';

  @override
  String get plansReviewerCommentHeader => '리뷰어 코멘트';

  @override
  String get plansActionApprove => '승인';

  @override
  String get plansActionReject => '반려';

  @override
  String get plansApprovedToast =>
      'plan 을 승인했습니다. task 가 InProgress 로 전환되었습니다.';

  @override
  String get plansRejectedToast => 'plan 을 반려했습니다.';

  @override
  String get plansRejectDialogTitle => 'plan 반려';

  @override
  String get plansRejectDialogHint =>
      '에이전트가 다시 작업할 때 무엇을 고쳐야 하는지 적어주세요. 반려 사유는 ChangeLog 에도 기록됩니다.';

  @override
  String get plansRejectFieldComment => '반려 사유 *';

  @override
  String get plansRejectFieldRequired => '반려 사유는 필수입니다.';

  @override
  String get plansRejectConfirm => '반려';

  @override
  String get plansAuthBannerTitle => '사용자 선택 필요';

  @override
  String get plansAuthBannerHint =>
      '승인 / 반려 / 취소는 인증된 사용자만 가능합니다. 사이드바 하단의 사용자 스위처에서 본인 계정을 선택하세요.';

  @override
  String plansReviewedBy(String by, String at) {
    return '$by · $at';
  }

  @override
  String get plansActionRevert => '결정 취소';

  @override
  String get plansRevertedToast => '결정을 되돌렸습니다. plan 이 검토 대기로 돌아갔습니다.';

  @override
  String get plansRevertConfirmTitle => '이 결정을 되돌릴까요?';

  @override
  String get plansRevertConfirmBody =>
      'plan 이 검토 대기로 돌아가고 task 의 상태도 PlanReview 로 되돌아갑니다.';

  @override
  String get plansRevertConfirmAction => '되돌리기';

  @override
  String get auditSectionLead =>
      '프로젝트 / 업무 / 마일스톤의 모든 변경 자취를 한 곳에서 추적합니다. status, IsWaiting, plan 승인/반려/취소, 타임라인 수정 모두 자동 기록됩니다.';

  @override
  String get auditFilterAll => '전체';

  @override
  String get auditFilterTask => '업무';

  @override
  String get auditFilterProject => '프로젝트';

  @override
  String get auditFilterMilestone => '마일스톤';

  @override
  String auditLimitN(int n) {
    return '$n개씩';
  }

  @override
  String get auditRefresh => '다시 불러오기';

  @override
  String get auditEmptyTitle => '변경 이력이 없습니다';

  @override
  String get auditEmptyHint => '필터를 바꾸거나 항목 수를 늘려보세요. 작업이 진행되면서 자동으로 쌓입니다.';

  @override
  String auditCount(int n) {
    return '총 $n건';
  }

  @override
  String get auditValueNone => '(없음)';

  @override
  String get auditChangedByUnknown => '(알 수 없음)';

  @override
  String auditEntityTaskUnknown(String id) {
    return 'task $id (찾을 수 없음)';
  }

  @override
  String auditEntityProjectUnknown(String id) {
    return 'project $id (찾을 수 없음)';
  }

  @override
  String auditEntityMilestone(String id) {
    return 'milestone $id';
  }

  @override
  String get auditFilterProjectScope => '프로젝트';

  @override
  String get auditFilterFrom => '시작';

  @override
  String get auditFilterTo => '종료';

  @override
  String get auditFilterClear => '필터 지우기';

  @override
  String auditPageRange(int first, int last, int total) {
    return '$first–$last / $total';
  }

  @override
  String auditPageOf(int page, int total) {
    return '$page / $total';
  }

  @override
  String get auditPagePrev => '이전 페이지';

  @override
  String get auditPageNext => '다음 페이지';

  @override
  String auditCountOf(int n, int total) {
    return '총 $total건 중 $n건 표시';
  }

  @override
  String get matrixEmpty => '표시할 리소스가 없습니다.';

  @override
  String get matrixEmptyFiltered => '선택한 필터에 해당하는 리소스가 없습니다.';

  @override
  String get matrixFilterDepartment => '부서';

  @override
  String get matrixFilterProject => '프로젝트';

  @override
  String get matrixFilterAll => '전체';

  @override
  String get matrixFilterClear => '필터 지우기';

  @override
  String get matrixFilterActiveHint => '필터 적용 중';
}
