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
  String get taskStatusNotStarted => '시작 전';

  @override
  String get taskStatusInProgress => '진행 중';

  @override
  String get taskStatusBlocked => '차단됨';

  @override
  String get taskStatusDone => '완료';

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
}
