import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/new_item_route_screens.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/runner_memberships.dart';
import '../../support/sample_runners.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';
import 'random_drafts.dart';
import 'work_draft_form_scene.dart';
import 'work_draft_support.dart';

const String _offlineSuffix = ', offline';
const List<String> _unreadableTimes = <String>['soon', '25:99', '', 'x9'];

typedef _ReviewScene = ({RunnerMembership membership, Runner runner});

DraftedWork _withoutChosenRunner(DraftedWork work) {
  return DraftedWork(
    title: work.title,
    details: work.details,
    projectId: work.projectId,
    doer: work.doer,
    runsOn: const AnyFreeRunner(),
    agentPlace: work.agentPlace,
    skills: work.skills,
    usesAutomaticSkills: work.usesAutomaticSkills,
    approvalPolicy: work.approvalPolicy,
    schedule: WeeklySchedule(
      on: Weekday.friday,
      at: ScheduleTime(hour: 9, minute: 30),
    ),
  );
}

Future<_ReviewScene> _openReview(
  WidgetTester tester, {
  required Random random,
  required int round,
}) async {
  final DraftKind kind = pickOne(random, workDraftKinds);
  final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
  final Runner runner = buildOnlineRunnerOn(DeviceId('runner-$round'));
  final RunnerMembership membership = buildWorkspaceMembersFor(<Runner>[
    runner,
  ]);
  final AppDependencies dependencies = replaceRepositories(
    buildNewItemDependencies(drafts),
    deviceRepository: membership.devices,
    runnerRepository: FakeRunnerRepository(
      runners: <Runner>[runner],
      deviceRepository: membership.devices,
      workspaceRepository: membership.workspaces,
      thisDeviceOffers: null,
      thisRunnerProblem: null,
    ),
  );
  final Widget screen = buildNewItemScreen(
    formRoute: NewItemFormRoute(kind),
    startedFrom: null,
    dependencies: dependencies,
    navigation: openWorkNavigation(kind),
  );
  await pumpNewItemPage(tester, page: screen, size: randomScreenSize(random));
  await tester.enterText(find.byType(TextField).first, 'Wish $round');
  await tapPageText(tester, describeNewItem(kind).draftLabel);
  final DraftedWork work = randomListedWork(random, kind);
  await reportDraftProgress(
    tester,
    drafts: drafts,
    progress: DraftFinished(
      ItemDraft(item: _withoutChosenRunner(work), problems: const <String>[]),
    ),
  );
  return (membership: membership, runner: runner);
}

SelectField<RunnerTarget> _findRunnerField(WidgetTester tester) {
  return tester.widget(find.byType(SelectField<RunnerTarget>));
}

Future<void> _pickRunner(WidgetTester tester, Runner runner) async {
  final SelectField<RunnerTarget> field = _findRunnerField(tester);
  await tester.ensureVisible(find.byType(SelectField<RunnerTarget>));
  field.onChanged(SpecificRunner(runner.deviceId));
  await tester.pump();
}

Future<void> _takeRunnerAway(WidgetTester tester, _ReviewScene scene) async {
  await scene.membership.devices.removeDeviceFromWorkspace(
    scene.runner.deviceId,
    membershipWorkspaceId,
  );
  await tester.pump();
}

String _findShownLabel(WidgetTester tester, Runner runner) {
  final SelectField<RunnerTarget> field = _findRunnerField(tester);
  final RunnerTarget picked = SpecificRunner(runner.deviceId);
  final List<String> labels = <String>[
    for (final SelectEntry<RunnerTarget> entry in field.entries)
      if (entry is SelectOption<RunnerTarget> && entry.value == picked)
        entry.label,
  ];
  expect(field.value, picked);
  expect(labels, hasLength(1));
  return labels.single;
}

void main() {
  testWidgets('test_work_draft_review_build_form_property_unreadable_time', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53201);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(
        tester,
        random: random,
        round: i,
      );
      await tester.enterText(
        findFieldInput(workTimeLabel),
        pickOne(random, _unreadableTimes),
      );
      await _pickRunner(tester, scene.runner);

      await _takeRunnerAway(tester, scene);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(_findShownLabel(tester, scene.runner), endsWith(_offlineSuffix));
    }
  });

  testWidgets('test_work_draft_review_build_form_property_readable_time', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53202);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(
        tester,
        random: random,
        round: i,
      );
      await _pickRunner(tester, scene.runner);

      await _takeRunnerAway(tester, scene);

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(_findShownLabel(tester, scene.runner), endsWith(_offlineSuffix));
    }
  });

  testWidgets('test_work_draft_review_build_form_property_runner_returns', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(53203);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ReviewScene scene = await _openReview(
        tester,
        random: random,
        round: i,
      );
      if (random.nextBool()) {
        await tester.enterText(findFieldInput(workTimeLabel), 'later');
      }
      await _pickRunner(tester, scene.runner);
      await _takeRunnerAway(tester, scene);

      await scene.membership.devices.addDeviceToWorkspace(
        scene.runner.deviceId,
        membershipWorkspaceId,
      );
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'round $i');
      final String label = _findShownLabel(tester, scene.runner);
      expect(label.endsWith(_offlineSuffix), isFalse, reason: label);
    }
  });
}
