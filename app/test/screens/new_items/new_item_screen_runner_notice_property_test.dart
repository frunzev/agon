import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/runner_memberships.dart';
import '../../support/sample_runners.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

Future<FakeRunnerRepository> _openWithRunners(
  WidgetTester tester, {
  required Random random,
  required List<Runner> runners,
}) async {
  final RunnerMembership membership = buildWorkspaceMembersFor(runners);
  final FakeRunnerRepository runnerRepository = FakeRunnerRepository(
    runners: runners,
    deviceRepository: membership.devices,
    workspaceRepository: membership.workspaces,
    thisDeviceOffers: null,
    thisRunnerProblem: null,
  );
  final AppDependencies dependencies = replaceRepositories(
    buildNewItemDependencies(ScriptedItemDraftRepository()),
    deviceRepository: membership.devices,
    runnerRepository: runnerRepository,
  );
  await openRecordedNewItemPage(
    tester,
    kind: pickOne(random, DraftKind.values),
    startedFrom: null,
    dependencies: dependencies,
    size: randomScreenSize(random),
  );
  return runnerRepository;
}

List<Runner> _runnersTakingNoNewRuns(Random random) {
  return <Runner>[
    for (final Runner runner in randomRunners(random))
      if (runner.online) runner.asPaused() else runner,
  ];
}

void main() {
  testWidgets('test_build_request_property_paused_runners_never_count', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52701);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Runner> runners = <Runner>[
        buildOnlineRunnerOn(GalleryDeviceIds.macStudio).asPaused(),
        ..._runnersTakingNoNewRuns(random),
      ];

      await _openWithRunners(tester, random: random, runners: runners);

      expect(find.text(noRunnerTitle), findsOneWidget, reason: '$runners');
      expect(find.text(fillInFormLabel), findsOneWidget);
    }
  });

  testWidgets('test_build_request_property_one_runner_taking_runs_is_enough', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52702);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Runner> runners = <Runner>[
        ..._runnersTakingNoNewRuns(random),
        buildOnlineRunnerOn(GalleryDeviceIds.macStudio),
      ];

      await _openWithRunners(tester, random: random, runners: runners);

      expect(find.text(noRunnerTitle), findsNothing, reason: '$runners');
      expect(find.text(fillInFormLabel), findsNothing);
    }
  });

  testWidgets('test_build_request_property_pausing_and_resuming_follows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(52703);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Runner accepting = buildOnlineRunnerOn(GalleryDeviceIds.macStudio);
      final FakeRunnerRepository runnerRepository = await _openWithRunners(
        tester,
        random: random,
        runners: <Runner>[accepting],
      );
      expect(find.text(noRunnerTitle), findsNothing);

      await runnerRepository.pauseRunner(accepting.deviceId);
      await tester.pump();
      expect(find.text(noRunnerTitle), findsOneWidget);

      await runnerRepository.resumeRunner(accepting.deviceId);
      await tester.pump();
      expect(find.text(noRunnerTitle), findsNothing);
    }
  });
}
