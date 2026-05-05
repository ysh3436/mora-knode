import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// Brand name shown in window title and sidebar header.
  ///
  /// In en, this message translates to:
  /// **'mora-knode'**
  String get appTitle;

  /// No description provided for @navMyWork.
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get navMyWork;

  /// No description provided for @navAllWork.
  ///
  /// In en, this message translates to:
  /// **'All work'**
  String get navAllWork;

  /// No description provided for @navProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get navProjects;

  /// No description provided for @navResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get navResources;

  /// No description provided for @navMatrix.
  ///
  /// In en, this message translates to:
  /// **'Matrix'**
  String get navMatrix;

  /// No description provided for @navPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get navPlans;

  /// No description provided for @navAudit.
  ///
  /// In en, this message translates to:
  /// **'Change log'**
  String get navAudit;

  /// No description provided for @navAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get navAgents;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @topbarOpenSidebar.
  ///
  /// In en, this message translates to:
  /// **'Open sidebar  ['**
  String get topbarOpenSidebar;

  /// No description provided for @topbarCloseSidebar.
  ///
  /// In en, this message translates to:
  /// **'Close sidebar  ['**
  String get topbarCloseSidebar;

  /// No description provided for @topbarOpenInspector.
  ///
  /// In en, this message translates to:
  /// **'Open details  ]'**
  String get topbarOpenInspector;

  /// No description provided for @topbarCloseInspector.
  ///
  /// In en, this message translates to:
  /// **'Close details  ]'**
  String get topbarCloseInspector;

  /// No description provided for @headerMyWork.
  ///
  /// In en, this message translates to:
  /// **'My work'**
  String get headerMyWork;

  /// No description provided for @headerMyWorkSub.
  ///
  /// In en, this message translates to:
  /// **'this week'**
  String get headerMyWorkSub;

  /// No description provided for @headerAllWork.
  ///
  /// In en, this message translates to:
  /// **'All work'**
  String get headerAllWork;

  /// No description provided for @headerProjects.
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get headerProjects;

  /// No description provided for @headerResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get headerResources;

  /// No description provided for @headerMatrixLoad.
  ///
  /// In en, this message translates to:
  /// **'Matrix load'**
  String get headerMatrixLoad;

  /// No description provided for @headerPlans.
  ///
  /// In en, this message translates to:
  /// **'Plans'**
  String get headerPlans;

  /// No description provided for @headerAudit.
  ///
  /// In en, this message translates to:
  /// **'Change log'**
  String get headerAudit;

  /// No description provided for @headerAgents.
  ///
  /// In en, this message translates to:
  /// **'Agents'**
  String get headerAgents;

  /// No description provided for @headerSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get headerSettings;

  /// No description provided for @tabList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get tabList;

  /// No description provided for @tabGantt.
  ///
  /// In en, this message translates to:
  /// **'Gantt'**
  String get tabGantt;

  /// No description provided for @tabCalendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get tabCalendar;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get newTask;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming in the next stage of the redesign.'**
  String get comingSoon;

  /// No description provided for @comingProjectsDirectory.
  ///
  /// In en, this message translates to:
  /// **'Projects directory'**
  String get comingProjectsDirectory;

  /// No description provided for @comingResources.
  ///
  /// In en, this message translates to:
  /// **'Resources'**
  String get comingResources;

  /// No description provided for @comingPlanReviewQueue.
  ///
  /// In en, this message translates to:
  /// **'Plan review queue (M2)'**
  String get comingPlanReviewQueue;

  /// No description provided for @comingChangeLog.
  ///
  /// In en, this message translates to:
  /// **'Change log'**
  String get comingChangeLog;

  /// No description provided for @comingAgentRbac.
  ///
  /// In en, this message translates to:
  /// **'Agent identity & RBAC (M2)'**
  String get comingAgentRbac;

  /// No description provided for @badgeM2.
  ///
  /// In en, this message translates to:
  /// **'M2'**
  String get badgeM2;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageHint.
  ///
  /// In en, this message translates to:
  /// **'Affects all UI strings. Restart not required.'**
  String get settingsLanguageHint;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsAdminOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings are visible to admin roles only.'**
  String get settingsAdminOnlyTitle;

  /// No description provided for @settingsAdminOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Switch to the ysh user from the sidebar to edit WorkCalendar and other org-level settings.'**
  String get settingsAdminOnlyHint;

  /// No description provided for @settingsWorkCalendar.
  ///
  /// In en, this message translates to:
  /// **'Work Calendar'**
  String get settingsWorkCalendar;

  /// No description provided for @settingsWorkCalendarHint.
  ///
  /// In en, this message translates to:
  /// **'Drives matrix load calculation, calendar week-mode hour grid, and gantt overlays.'**
  String get settingsWorkCalendarHint;

  /// No description provided for @settingsWorkCalendarFallback.
  ///
  /// In en, this message translates to:
  /// **'No WorkCalendar configured yet. Showing the 24/7 fallback. Saving will create the document and start scoping matrix load to work hours.'**
  String get settingsWorkCalendarFallback;

  /// No description provided for @settingsWorkDays.
  ///
  /// In en, this message translates to:
  /// **'Work days'**
  String get settingsWorkDays;

  /// No description provided for @settingsDailyHoursLocal.
  ///
  /// In en, this message translates to:
  /// **'Daily hours (local)'**
  String get settingsDailyHoursLocal;

  /// No description provided for @settingsTimeStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get settingsTimeStart;

  /// No description provided for @settingsTimeEnd.
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get settingsTimeEnd;

  /// No description provided for @settingsTimezone.
  ///
  /// In en, this message translates to:
  /// **'Timezone'**
  String get settingsTimezone;

  /// No description provided for @settingsTimezoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Asia/Seoul'**
  String get settingsTimezoneHint;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get actionSaving;

  /// No description provided for @actionReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get actionReset;

  /// No description provided for @stateUnsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get stateUnsavedChanges;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {detail}'**
  String errorPrefix(String detail);

  /// No description provided for @myWorkBannerNoUser.
  ///
  /// In en, this message translates to:
  /// **'No user selected — showing every assignment. Pick a user from the sidebar bottom to see only their work.'**
  String get myWorkBannerNoUser;

  /// No description provided for @myWorkLaneThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get myWorkLaneThisWeek;

  /// No description provided for @myWorkLaneNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get myWorkLaneNextWeek;

  /// No description provided for @myWorkLaneOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue ({count})'**
  String myWorkLaneOverdue(int count);

  /// No description provided for @myWorkEmptyThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Nothing scheduled this week.'**
  String get myWorkEmptyThisWeek;

  /// No description provided for @myWorkEmptyNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week is open.'**
  String get myWorkEmptyNextWeek;

  /// No description provided for @myWorkEmptyOverdue.
  ///
  /// In en, this message translates to:
  /// **'No overdue tasks.'**
  String get myWorkEmptyOverdue;

  /// No description provided for @filterProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get filterProject;

  /// No description provided for @filterAssignee.
  ///
  /// In en, this message translates to:
  /// **'Assignee'**
  String get filterAssignee;

  /// No description provided for @filterStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get filterStatus;

  /// No description provided for @filterShowAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get filterShowAll;

  /// No description provided for @filterClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get filterClearAll;

  /// No description provided for @filterClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get filterClearSearch;

  /// No description provided for @filterByLabel.
  ///
  /// In en, this message translates to:
  /// **'Filter by {label}'**
  String filterByLabel(String label);

  /// No description provided for @filterAllSuffix.
  ///
  /// In en, this message translates to:
  /// **'{label}: all'**
  String filterAllSuffix(String label);

  /// No description provided for @filterCountSuffix.
  ///
  /// In en, this message translates to:
  /// **'{label} ({count})'**
  String filterCountSuffix(String label, int count);

  /// No description provided for @filterSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search title…'**
  String get filterSearchHint;

  /// No description provided for @filterCounter.
  ///
  /// In en, this message translates to:
  /// **'{projects} projects · {resources} resources'**
  String filterCounter(int projects, int resources);

  /// No description provided for @filterNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No tasks match the current filters.'**
  String get filterNoMatch;

  /// No description provided for @inspectorTitle.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get inspectorTitle;

  /// No description provided for @inspectorEmpty.
  ///
  /// In en, this message translates to:
  /// **'Select a task, project, or plan to see its details here.'**
  String get inspectorEmpty;

  /// No description provided for @userSwitcherTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch user (dev only)'**
  String get userSwitcherTooltip;

  /// No description provided for @userSwitcherLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading users…'**
  String get userSwitcherLoading;

  /// No description provided for @userSwitcherAnonymous.
  ///
  /// In en, this message translates to:
  /// **'anonymous'**
  String get userSwitcherAnonymous;

  /// No description provided for @userSwitcherAnonymousAdmin.
  ///
  /// In en, this message translates to:
  /// **'anonymous (admin)'**
  String get userSwitcherAnonymousAdmin;

  /// No description provided for @userSwitcherAdminCaption.
  ///
  /// In en, this message translates to:
  /// **'admin (no header)'**
  String get userSwitcherAdminCaption;

  /// No description provided for @taskStatusCreated.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get taskStatusCreated;

  /// No description provided for @taskStatusPlanning.
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get taskStatusPlanning;

  /// No description provided for @taskStatusPlanReview.
  ///
  /// In en, this message translates to:
  /// **'Plan review'**
  String get taskStatusPlanReview;

  /// No description provided for @taskStatusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get taskStatusInProgress;

  /// No description provided for @taskStatusWorkReview.
  ///
  /// In en, this message translates to:
  /// **'Work review'**
  String get taskStatusWorkReview;

  /// No description provided for @taskStatusOnHold.
  ///
  /// In en, this message translates to:
  /// **'On hold'**
  String get taskStatusOnHold;

  /// No description provided for @taskStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get taskStatusDone;

  /// No description provided for @taskStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get taskStatusCancelled;

  /// No description provided for @taskStatusDropped.
  ///
  /// In en, this message translates to:
  /// **'Dropped'**
  String get taskStatusDropped;

  /// No description provided for @taskStatusCancelledTooltip.
  ///
  /// In en, this message translates to:
  /// **'Cancelled at planning stage'**
  String get taskStatusCancelledTooltip;

  /// No description provided for @taskStatusDroppedTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dropped after work (kept for reference)'**
  String get taskStatusDroppedTooltip;

  /// No description provided for @taskWaitingToggle.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get taskWaitingToggle;

  /// No description provided for @taskWaitingTooltip.
  ///
  /// In en, this message translates to:
  /// **'Mark as waiting (different from On hold)'**
  String get taskWaitingTooltip;

  /// No description provided for @taskPriorityUnset.
  ///
  /// In en, this message translates to:
  /// **'Unset'**
  String get taskPriorityUnset;

  /// No description provided for @taskPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get taskPriorityLow;

  /// No description provided for @taskPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get taskPriorityNormal;

  /// No description provided for @taskPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get taskPriorityHigh;

  /// No description provided for @taskPriorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get taskPriorityUrgent;

  /// No description provided for @filterPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get filterPriority;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortBy;

  /// No description provided for @sortAddStep.
  ///
  /// In en, this message translates to:
  /// **'Add sort'**
  String get sortAddStep;

  /// No description provided for @sortKeyPriority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get sortKeyPriority;

  /// No description provided for @sortKeyStartDate.
  ///
  /// In en, this message translates to:
  /// **'Start date'**
  String get sortKeyStartDate;

  /// No description provided for @sortKeyDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get sortKeyDueDate;

  /// No description provided for @sortKeyStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get sortKeyStatus;

  /// No description provided for @sortKeyNumber.
  ///
  /// In en, this message translates to:
  /// **'Number'**
  String get sortKeyNumber;

  /// No description provided for @sortPriorityUrgentFirst.
  ///
  /// In en, this message translates to:
  /// **'Urgent first'**
  String get sortPriorityUrgentFirst;

  /// No description provided for @sortPriorityUnsetFirst.
  ///
  /// In en, this message translates to:
  /// **'Unset first'**
  String get sortPriorityUnsetFirst;

  /// No description provided for @sortStartDateEarliestFirst.
  ///
  /// In en, this message translates to:
  /// **'Earliest start first'**
  String get sortStartDateEarliestFirst;

  /// No description provided for @sortStartDateLatestFirst.
  ///
  /// In en, this message translates to:
  /// **'Latest start first'**
  String get sortStartDateLatestFirst;

  /// No description provided for @sortDueDateSoonestFirst.
  ///
  /// In en, this message translates to:
  /// **'Soonest first'**
  String get sortDueDateSoonestFirst;

  /// No description provided for @sortDueDateLatestFirst.
  ///
  /// In en, this message translates to:
  /// **'Latest first'**
  String get sortDueDateLatestFirst;

  /// No description provided for @sortStatusActiveFirst.
  ///
  /// In en, this message translates to:
  /// **'Active first'**
  String get sortStatusActiveFirst;

  /// No description provided for @sortStatusDoneFirst.
  ///
  /// In en, this message translates to:
  /// **'Done first'**
  String get sortStatusDoneFirst;

  /// No description provided for @sortNumberLowFirst.
  ///
  /// In en, this message translates to:
  /// **'Lower number first'**
  String get sortNumberLowFirst;

  /// No description provided for @sortNumberHighFirst.
  ///
  /// In en, this message translates to:
  /// **'Higher number first'**
  String get sortNumberHighFirst;

  /// Status label decorated with a marker (default *) when it's computed from child tasks instead of set directly.
  ///
  /// In en, this message translates to:
  /// **'{label}*'**
  String taskStatusAggregatedSuffix(String label);

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get actionAdd;

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

  /// No description provided for @actionToday.
  ///
  /// In en, this message translates to:
  /// **'today'**
  String get actionToday;

  /// No description provided for @taskEditorFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get taskEditorFieldTitle;

  /// No description provided for @taskEditorFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get taskEditorFieldDescription;

  /// No description provided for @taskEditorFieldStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get taskEditorFieldStatus;

  /// No description provided for @taskEditorFieldParent.
  ///
  /// In en, this message translates to:
  /// **'Parent (optional)'**
  String get taskEditorFieldParent;

  /// No description provided for @taskEditorFieldProject.
  ///
  /// In en, this message translates to:
  /// **'Project *'**
  String get taskEditorFieldProject;

  /// No description provided for @taskEditorParentTopLevel.
  ///
  /// In en, this message translates to:
  /// **'— Top level —'**
  String get taskEditorParentTopLevel;

  /// No description provided for @taskEditorChangeReason.
  ///
  /// In en, this message translates to:
  /// **'Change reason (logged)'**
  String get taskEditorChangeReason;

  /// No description provided for @taskEditorChangedBy.
  ///
  /// In en, this message translates to:
  /// **'Changed by'**
  String get taskEditorChangedBy;

  /// No description provided for @taskEditorAllDay.
  ///
  /// In en, this message translates to:
  /// **'All-day'**
  String get taskEditorAllDay;

  /// No description provided for @taskEditorTimed.
  ///
  /// In en, this message translates to:
  /// **'Timed'**
  String get taskEditorTimed;

  /// No description provided for @taskEditorTitleNew.
  ///
  /// In en, this message translates to:
  /// **'New task'**
  String get taskEditorTitleNew;

  /// No description provided for @taskEditorTitleEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit task'**
  String get taskEditorTitleEdit;

  /// No description provided for @actionCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get actionCreate;

  /// No description provided for @timelineL1Origin.
  ///
  /// In en, this message translates to:
  /// **'L1 Origin'**
  String get timelineL1Origin;

  /// No description provided for @timelineL2Current.
  ///
  /// In en, this message translates to:
  /// **'L2 Current'**
  String get timelineL2Current;

  /// No description provided for @timelineL3Real.
  ///
  /// In en, this message translates to:
  /// **'L3 Real'**
  String get timelineL3Real;

  /// No description provided for @timelineSummaryGroup.
  ///
  /// In en, this message translates to:
  /// **'Group'**
  String get timelineSummaryGroup;

  /// No description provided for @timelineAllDayBadge.
  ///
  /// In en, this message translates to:
  /// **'all-day'**
  String get timelineAllDayBadge;

  /// No description provided for @timelineTimedBadge.
  ///
  /// In en, this message translates to:
  /// **'timed'**
  String get timelineTimedBadge;

  /// No description provided for @inspectorSectionNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get inspectorSectionNotes;

  /// No description provided for @inspectorSectionTimelines.
  ///
  /// In en, this message translates to:
  /// **'Timelines'**
  String get inspectorSectionTimelines;

  /// No description provided for @inspectorSectionAssignees.
  ///
  /// In en, this message translates to:
  /// **'Assignees'**
  String get inspectorSectionAssignees;

  /// No description provided for @inspectorSectionChildren.
  ///
  /// In en, this message translates to:
  /// **'Children'**
  String get inspectorSectionChildren;

  /// No description provided for @inspectorSectionRecentChanges.
  ///
  /// In en, this message translates to:
  /// **'Recent changes'**
  String get inspectorSectionRecentChanges;

  /// No description provided for @inspectorSectionStats.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get inspectorSectionStats;

  /// No description provided for @inspectorSectionMilestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get inspectorSectionMilestones;

  /// No description provided for @inspectorSectionTopLevel.
  ///
  /// In en, this message translates to:
  /// **'Top-level tasks'**
  String get inspectorSectionTopLevel;

  /// No description provided for @taskInspectorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Task not found (or hidden by view scope).'**
  String get taskInspectorNotFound;

  /// No description provided for @projectInspectorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Project not found (or hidden by view scope).'**
  String get projectInspectorNotFound;

  /// No description provided for @notesPlaceholderEmpty.
  ///
  /// In en, this message translates to:
  /// **'Click to add notes…'**
  String get notesPlaceholderEmpty;

  /// No description provided for @notesHint.
  ///
  /// In en, this message translates to:
  /// **'Markdown-friendly notes about this task'**
  String get notesHint;

  /// No description provided for @notesSaveHint.
  ///
  /// In en, this message translates to:
  /// **'Click outside or press Esc to save'**
  String get notesSaveHint;

  /// No description provided for @notesNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes yet.'**
  String get notesNoChanges;

  /// No description provided for @deleteTaskTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete task?'**
  String get deleteTaskTitle;

  /// No description provided for @deleteTaskBody.
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" will be removed permanently.'**
  String deleteTaskBody(String title);

  /// No description provided for @projectStats.
  ///
  /// In en, this message translates to:
  /// **'{leaf} leaf tasks · {group} group tasks'**
  String projectStats(int leaf, int group);

  /// No description provided for @projectCreated.
  ///
  /// In en, this message translates to:
  /// **'created {date}'**
  String projectCreated(String date);

  /// No description provided for @calendarMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarMonth;

  /// No description provided for @calendarWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarWeek;

  /// No description provided for @calendarWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String calendarWeekOf(String date);

  /// No description provided for @navPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get navPrevious;

  /// No description provided for @navNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get navNext;

  /// No description provided for @navPreviousWeek.
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get navPreviousWeek;

  /// No description provided for @navNextWeek.
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get navNextWeek;

  /// No description provided for @matrixEditCalendar.
  ///
  /// In en, this message translates to:
  /// **'Edit calendar'**
  String get matrixEditCalendar;

  /// No description provided for @matrixHeaderResource.
  ///
  /// In en, this message translates to:
  /// **'Resource'**
  String get matrixHeaderResource;

  /// No description provided for @matrixWorkCalendarLabel.
  ///
  /// In en, this message translates to:
  /// **'WorkCalendar: {detail}'**
  String matrixWorkCalendarLabel(String detail);

  /// No description provided for @matrixWorkCalendarFallback.
  ///
  /// In en, this message translates to:
  /// **'24/7 fallback'**
  String get matrixWorkCalendarFallback;

  /// No description provided for @ganttNoTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet.'**
  String get ganttNoTasks;

  /// No description provided for @ganttNoTimeline.
  ///
  /// In en, this message translates to:
  /// **'No timeline data yet. Add Current timeline to tasks.'**
  String get ganttNoTimeline;

  /// No description provided for @ganttColTask.
  ///
  /// In en, this message translates to:
  /// **'Task'**
  String get ganttColTask;

  /// No description provided for @ganttZoomDay.
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get ganttZoomDay;

  /// No description provided for @ganttZoomWeek.
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get ganttZoomWeek;

  /// No description provided for @ganttZoomMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get ganttZoomMonth;

  /// No description provided for @projectsDirectoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Project list'**
  String get projectsDirectoryTitle;

  /// No description provided for @projectsDirectoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No projects yet.'**
  String get projectsDirectoryEmpty;

  /// No description provided for @projectPickPrompt.
  ///
  /// In en, this message translates to:
  /// **'Pick a project from the list on the left.'**
  String get projectPickPrompt;

  /// No description provided for @projectTabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get projectTabOverview;

  /// No description provided for @projectTabTasks.
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get projectTabTasks;

  /// No description provided for @projectTabIssues.
  ///
  /// In en, this message translates to:
  /// **'Issues'**
  String get projectTabIssues;

  /// No description provided for @projectTabInitiatives.
  ///
  /// In en, this message translates to:
  /// **'Initiatives'**
  String get projectTabInitiatives;

  /// No description provided for @projectTabDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get projectTabDocuments;

  /// No description provided for @projectBackToDirectory.
  ///
  /// In en, this message translates to:
  /// **'Back to list'**
  String get projectBackToDirectory;

  /// No description provided for @projectIssuesComing.
  ///
  /// In en, this message translates to:
  /// **'Issue triage'**
  String get projectIssuesComing;

  /// No description provided for @projectInitiativesComing.
  ///
  /// In en, this message translates to:
  /// **'Project initiatives'**
  String get projectInitiativesComing;

  /// No description provided for @projectDocumentsComing.
  ///
  /// In en, this message translates to:
  /// **'Project documents'**
  String get projectDocumentsComing;

  /// No description provided for @projectOverviewCounts.
  ///
  /// In en, this message translates to:
  /// **'{tasks} tasks · {milestones} milestones'**
  String projectOverviewCounts(int tasks, int milestones);

  /// No description provided for @projectTasksEmpty.
  ///
  /// In en, this message translates to:
  /// **'No tasks in this project.'**
  String get projectTasksEmpty;

  /// No description provided for @projectTaskOpenInAllWork.
  ///
  /// In en, this message translates to:
  /// **'Open in All work'**
  String get projectTaskOpenInAllWork;

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// No description provided for @agentsSectionLead.
  ///
  /// In en, this message translates to:
  /// **'Manage external AI agent identities and their auth tokens. Tokens are shown exactly once at issuance.'**
  String get agentsSectionLead;

  /// No description provided for @agentsCreateButton.
  ///
  /// In en, this message translates to:
  /// **'+ New agent'**
  String get agentsCreateButton;

  /// No description provided for @agentsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No agents yet'**
  String get agentsEmptyTitle;

  /// No description provided for @agentsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Use + New agent to provision the first identity and receive its token.'**
  String get agentsEmptyHint;

  /// No description provided for @agentsRotateTooltip.
  ///
  /// In en, this message translates to:
  /// **'Rotate token (existing key is revoked immediately)'**
  String get agentsRotateTooltip;

  /// No description provided for @agentsRevokeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Revoke all tokens (no auth until rotated)'**
  String get agentsRevokeTooltip;

  /// No description provided for @agentsExpandTokens.
  ///
  /// In en, this message translates to:
  /// **'Show token history'**
  String get agentsExpandTokens;

  /// No description provided for @agentsCollapseTokens.
  ///
  /// In en, this message translates to:
  /// **'Hide token history'**
  String get agentsCollapseTokens;

  /// No description provided for @agentsRotatedTitle.
  ///
  /// In en, this message translates to:
  /// **'New token issued'**
  String get agentsRotatedTitle;

  /// No description provided for @agentsCreatedTitle.
  ///
  /// In en, this message translates to:
  /// **'Agent created'**
  String get agentsCreatedTitle;

  /// No description provided for @agentsRevokeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke tokens?'**
  String get agentsRevokeConfirmTitle;

  /// No description provided for @agentsRevokeConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'All active tokens for \"{name}\" will be invalidated. Rotation is required to use the agent again.'**
  String agentsRevokeConfirmBody(String name);

  /// No description provided for @agentsRevokeConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get agentsRevokeConfirmAction;

  /// No description provided for @agentsRevokedToast.
  ///
  /// In en, this message translates to:
  /// **'Revoked {count} token(s).'**
  String agentsRevokedToast(int count);

  /// No description provided for @agentsTokensEmpty.
  ///
  /// In en, this message translates to:
  /// **'No token history.'**
  String get agentsTokensEmpty;

  /// No description provided for @agentsTokenActive.
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get agentsTokenActive;

  /// No description provided for @agentsTokenRevokedAt.
  ///
  /// In en, this message translates to:
  /// **'revoked · {at}'**
  String agentsTokenRevokedAt(String at);

  /// No description provided for @agentsTokenCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'issued · {at}'**
  String agentsTokenCreatedAt(String at);

  /// No description provided for @agentsCreateDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'New agent'**
  String get agentsCreateDialogTitle;

  /// No description provided for @agentsFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get agentsFieldName;

  /// No description provided for @agentsFieldRole.
  ///
  /// In en, this message translates to:
  /// **'Role (optional)'**
  String get agentsFieldRole;

  /// No description provided for @agentsFieldDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get agentsFieldDescription;

  /// No description provided for @agentsFieldDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Model / tooling / prompt provenance, etc.'**
  String get agentsFieldDescriptionHint;

  /// No description provided for @agentsFieldRbac.
  ///
  /// In en, this message translates to:
  /// **'RBAC preset'**
  String get agentsFieldRbac;

  /// No description provided for @agentsFieldNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get agentsFieldNameRequired;

  /// No description provided for @agentsCreateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Create and reveal token'**
  String get agentsCreateConfirm;

  /// No description provided for @agentsTokenRevealWarning.
  ///
  /// In en, this message translates to:
  /// **'This token is shown only once. Copy it somewhere safe before closing.'**
  String get agentsTokenRevealWarning;

  /// No description provided for @agentsTokenRevealHint.
  ///
  /// In en, this message translates to:
  /// **'Last 4 chars: …{lastFour}'**
  String agentsTokenRevealHint(String lastFour);

  /// No description provided for @agentsTokenRevealAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I\'ve saved it'**
  String get agentsTokenRevealAcknowledge;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'ko':
      return AppL10nKo();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
