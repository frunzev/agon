import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/screens/new_items/work_draft_review.dart';
import 'package:agent_orchestration/screens/task_form/task_form_options.dart';
import 'package:agent_orchestration/shell/task_route_screens.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'draft_record_fields.dart';
import 'work_draft_support.dart';

const int _designJobHour = 9;
const String workTitleLabel = 'What should be done?';
const String workDetailsLabel = 'Details';
const String workTimeLabel = 'At';

final class FormCallbackRecorder {
  final List<DraftedItem> changedItems = <DraftedItem>[];
  final List<DraftedItem> approvedItems = <DraftedItem>[];
  int cancelCount = 0;
  Error? approvalProblem;
  Completer<void>? pendingApproval;

  DraftFormCallbacks buildCallbacks() {
    return DraftFormCallbacks(
      onChanged: changedItems.add,
      onApproved: _recordApproval,
      onCancelled: _recordCancel,
    );
  }

  Future<void> _recordApproval(DraftedItem item) async {
    approvedItems.add(item);
    final Completer<void>? gate = pendingApproval;
    if (gate != null) {
      await gate.future;
    }
    final Error? problem = approvalProblem;
    if (problem != null) {
      throw problem;
    }
  }

  void _recordCancel() {
    cancelCount += 1;
  }
}

typedef WorkFormScene = ({
  FormCallbackRecorder recorder,
  AppDependencies dependencies,
  DraftedWork work,
  DraftedWork shownWork,
  bool hasDeletedChoice,
});

DraftedWork describeShownWork({
  required DraftedWork work,
  required DraftKind kind,
  required TaskFormOptions options,
}) {
  return DraftedWork(
    title: trimUnicodeWhiteSpace(work.title),
    details: trimUnicodeWhiteSpace(work.details),
    projectId: work.projectId ?? options.firstProjectId,
    doer: work.doer,
    runsOn: work.runsOn,
    agentPlace: work.agentPlace,
    skills: work.skills,
    usesAutomaticSkills: work.usesAutomaticSkills,
    approvalPolicy: work.approvalPolicy,
    schedule: work.schedule ?? _describeUnscheduledRepeat(kind),
  );
}

Schedule? _describeUnscheduledRepeat(DraftKind kind) {
  if (kind != DraftKind.job) {
    return null;
  }
  return WeeklySchedule(
    on: Weekday.monday,
    at: ScheduleTime(hour: _designJobHour, minute: 0),
  );
}

Future<WorkFormScene> pumpWorkForm(
  WidgetTester tester, {
  required Random random,
  required DraftKind kind,
  required DraftedWork work,
}) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  final WorkDraftReview review = buildRecordingWorkReview(
    kind: kind,
    dependencies: dependencies,
    navigation: openWorkNavigation(kind),
    chosenTargets: <RunnerTarget>[],
  );
  final FormCallbackRecorder recorder = FormCallbackRecorder();
  final Widget form = review.buildForm(work, recorder.buildCallbacks());
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: KeyedSubtree(key: UniqueKey(), child: form),
  );

  final TaskFormOptions options = buildTaskFormOptionsFor(
    dependencies: dependencies,
    chosenTarget: work.runsOn,
  );
  final DraftedWork shownWork = describeShownWork(
    work: work,
    kind: kind,
    options: options,
  );
  final String? projectProblem = options.describeProjectProblem(
    shownWork.projectId!,
  );
  final String? doerProblem = options.describeDoerProblem(shownWork.doer);
  return (
    recorder: recorder,
    dependencies: dependencies,
    work: work,
    shownWork: shownWork,
    hasDeletedChoice: projectProblem != null || doerProblem != null,
  );
}

Future<void> tapReviewAction(WidgetTester tester, String label) async {
  await tapVisible(tester, find.text(label));
  await pumpFrames(tester);
}

String readWorkFieldText(WidgetTester tester, String label) {
  final TextField field = tester.widget(findFieldInput(label));
  return field.controller!.text;
}

void expectSameWork(DraftedItem actual, DraftedWork expected) {
  expect(actual, isA<DraftedWork>());
  expect(
    describeDraftedWorkFields(actual as DraftedWork),
    describeDraftedWorkFields(expected),
  );
}

List<String> listSkillNames(AppDependencies dependencies, DraftedWork work) {
  return <String>[
    for (final Skill skill in dependencies.skillRepository.listSkills())
      if (work.skills.contains(skill.id)) skill.name,
  ];
}
