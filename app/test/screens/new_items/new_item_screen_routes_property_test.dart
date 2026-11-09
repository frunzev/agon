import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/runner_memberships.dart';
import '../../support/sample_runners.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

typedef _RunnerScene = ({
  ScriptedItemDraftRepository drafts,
  RunnerMembership membership,
  RecordedNewItemPage page,
});

Future<_RunnerScene> _openWithRunners(
  WidgetTester tester, {
  required Random random,
  required List<Runner> runners,
}) async {
  final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
  final RunnerMembership membership = buildWorkspaceMembersFor(runners);
  final AppDependencies dependencies = replaceRepositories(
    buildNewItemDependencies(drafts),
    deviceRepository: membership.devices,
    runnerRepository: FakeRunnerRepository(
      runners: runners,
      deviceRepository: membership.devices,
      workspaceRepository: membership.workspaces,
      thisDeviceOffers: null,
      thisRunnerProblem: null,
    ),
  );
  final RecordedNewItemPage page = await openRecordedNewItemPage(
    tester,
    kind: pickOne(random, DraftKind.values),
    startedFrom: null,
    dependencies: dependencies,
    size: randomScreenSize(random),
  );
  return (drafts: drafts, membership: membership, page: page);
}

List<Runner> _offlineRunners(Random random) {
  return <Runner>[
    for (final Runner runner in randomRunners(random))
      if (!runner.online) runner,
  ];
}

void main() {
  testWidgets('test_build_request_property_notice_iff_no_runner_takes_runs', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11101);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);

      await _openWithRunners(tester, random: random, runners: runners);

      final bool hasRunnerTakingNewRuns = runners.any(
        (Runner runner) => runner.online && runner.acceptingNewRuns,
      );
      final Matcher shown = hasRunnerTakingNewRuns
          ? findsNothing
          : findsOneWidget;
      expect(find.text(noRunnerTitle), shown, reason: '$runners');
      expect(find.text(noRunnerText), shown);
      expect(find.text(fillInFormLabel), shown);
    }
  });

  testWidgets('test_build_request_property_notice_follows_runner_changes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11102);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Runner online = buildOnlineRunnerOn(GalleryDeviceIds.macStudio);
      final _RunnerScene scene = await _openWithRunners(
        tester,
        random: random,
        runners: <Runner>[online],
      );
      final String words = 'Wish $i ${randomWordPhrase(random)}';
      await tester.enterText(find.byType(TextField).first, words);
      expect(find.text(noRunnerTitle), findsNothing);

      await scene.membership.devices.removeDeviceFromWorkspace(
        online.deviceId,
        membershipWorkspaceId,
      );
      await tester.pump();
      expect(find.text(noRunnerTitle), findsOneWidget);

      await scene.membership.devices.addDeviceToWorkspace(
        online.deviceId,
        membershipWorkspaceId,
      );
      await tester.pump();
      expect(find.text(noRunnerTitle), findsNothing);
      final TextField field = tester.widget(find.byType(TextField).first);
      expect(field.controller!.text, words);
    }
  });

  testWidgets('test_open_form_property_no_runner_notice_swaps_in_the_form', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11103);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RunnerScene scene = await _openWithRunners(
        tester,
        random: random,
        runners: _offlineRunners(random),
      );
      final AppRoute below = scene.page.navigation.routes.first;

      await tapPageText(tester, fillInFormLabel);

      expect(scene.page.navigation.routes, <AppRoute>[
        below,
        NewItemFormRoute(scene.page.kind),
      ]);
    }
  });

  testWidgets('test_open_form_property_failed_draft_swaps_in_the_form', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11104);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedItemDraftRepository drafts = ScriptedItemDraftRepository();
      final RecordedNewItemPage page = await openDraftingPage(
        tester,
        random: random,
        dependencies: buildNewItemDependencies(drafts),
      );
      final AppRoute below = page.navigation.routes.first;
      await failDraft(tester, drafts: drafts, problem: StateError('x'));

      await tapPageText(tester, fillInFormLabel);

      expect(page.navigation.routes, <AppRoute>[
        below,
        NewItemFormRoute(page.kind),
      ]);
    }
  });

  testWidgets('test_open_form_property_sends_no_request_and_no_stop', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11105);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RunnerScene scene = await _openWithRunners(
        tester,
        random: random,
        runners: _offlineRunners(random),
      );
      final bool failsFirst = random.nextBool();
      if (failsFirst) {
        await draftWish(tester, page: scene.page, wish: 'Wish $i');
        await failDraft(
          tester,
          drafts: scene.drafts,
          problem: StateError('x'),
        );
      }

      await tapPageText(tester, fillInFormLabel);

      expect(scene.drafts.requests, hasLength(failsFirst ? 1 : 0));
      expect(scene.drafts.stoppedRequests, isEmpty);
    }
  });

  testWidgets('test_open_form_above_request_property_keeps_the_new_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11106);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RunnerScene scene = await _openWithRunners(
        tester,
        random: random,
        runners: _offlineRunners(random),
      );
      final List<AppRoute> routesBefore = scene.page.navigation.routes;

      await tapPageText(tester, addManuallyLabel);

      expect(
        scene.page.navigation.routes.sublist(0, routesBefore.length),
        routesBefore,
      );
      expect(scene.page.navigation.routes, hasLength(routesBefore.length + 1));
    }
  });

  testWidgets('test_open_form_above_request_property_form_has_screen_kind', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(11107);
    for (final DraftKind kind in DraftKind.values) {
      final RecordedNewItemPage page = await openRecordedNewItemPage(
        tester,
        kind: kind,
        startedFrom: null,
        dependencies: buildNewItemDependencies(ScriptedItemDraftRepository()),
        size: randomScreenSize(random),
      );

      await tapPageText(tester, addManuallyLabel);

      final AppRoute opened = page.navigation.currentRoute;
      expect(opened, NewItemFormRoute(kind));
      expect(opened.section, newItemRoutes[kind]!.section);
      expect(find.byType(ItemRequestView), findsOneWidget);
    }
  });
}
