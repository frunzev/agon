import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/presentation/runner_text.dart'
    hide describeRunnerSummary;
import 'package:agent_orchestration/screens/devices/devices_screen.dart';
import 'package:agent_orchestration/screens/devices/runner_notices.dart';
import 'package:agent_orchestration/screens/runners.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';
import 'support/random_devices_page.dart';

const String _summaryLead = 'Runners: ';
const String _serverDownTitle = "Can't reach the app server";

final RegExp _countPattern = RegExp(r'^Runners: (\d+) of (\d+) ');

List<Widget> _buildNoticesOnPage(
  WidgetTester tester,
  AppDependencies dependencies,
) {
  final BuildContext context = tester.element(find.byType(DevicesScreen));
  final RunnerNotices notices = RunnerNotices(
    runnerRepository: dependencies.runnerRepository,
    deviceRepository: dependencies.deviceRepository,
    workspaceRepository: dependencies.workspaceRepository,
  );
  return notices.buildNotices(context);
}

int _countNoticesByModel(AppDependencies dependencies) {
  final bool hasProblem =
      dependencies.runnerRepository.findThisRunnerProblem() != null;
  final bool hasRunners = dependencies.runnerRepository
      .listRunners()
      .isNotEmpty;
  final bool showsServerDown = isAppServerDown(dependencies) && hasRunners;
  return (hasProblem ? 1 : 0) + (showsServerDown ? 1 : 0);
}

void main() {
  test('test_runner_notices_describe_runner_summary_property_none_if_no_'
      'runners', () {
    final Random random = seededRandom(73501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);

      final String? summary = describeRunnerSummary(
        runners: runners,
        serverState: pickOne(random, AppServerState.values),
      );

      expect(summary == null, runners.isEmpty);
    }
  });

  test('test_runner_notices_describe_runner_summary_property_reach_when_'
      'server_is_down', () {
    final Random random = seededRandom(73502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      final AppServerState state = pickOne(random, AppServerState.values);
      if (runners.isEmpty) {
        continue;
      }

      final String? summary = describeRunnerSummary(
        runners: runners,
        serverState: state,
      );

      final String expected = state == AppServerState.unreachable
          ? describeReachableRunners(runners)
          : describeRunnerFleet(runners);
      expect(summary, '$_summaryLead$expected');
    }
  });

  test('test_runner_notices_describe_runner_summary_property_counts_within_'
      'the_fleet', () {
    final Random random = seededRandom(73503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Runner> runners = randomRunners(random);
      if (runners.isEmpty) {
        continue;
      }

      final String summary = describeRunnerSummary(
        runners: runners,
        serverState: pickOne(random, AppServerState.values),
      )!;

      final RegExpMatch match = _countPattern.firstMatch(summary)!;
      final int counted = int.parse(match.group(1)!);
      final int total = int.parse(match.group(2)!);
      expect(total, runners.length);
      expect(counted, inInclusiveRange(0, total));
    }
  });

  testWidgets('test_build_notices_property_one_notice_per_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );

      final List<Widget> notices = _buildNoticesOnPage(tester, dependencies);

      expect(notices, hasLength(_countNoticesByModel(dependencies)));
    }
  });

  testWidgets('test_build_notices_property_this_computer_comes_first', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );

      final List<Widget> notices = _buildNoticesOnPage(tester, dependencies);

      final bool hasProblem =
          dependencies.runnerRepository.findThisRunnerProblem() != null;
      if (hasProblem) {
        expect(notices.first, isA<RunnerProblemBanner>());
      }
      for (final Widget notice in notices.skip(hasProblem ? 1 : 0)) {
        expect(notice, isA<NoticeBanner>());
      }
    }
  });

  testWidgets('test_build_notices_property_page_shows_each_notice_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );

      final bool hasProblem =
          dependencies.runnerRepository.findThisRunnerProblem() != null;
      final bool showsServerDown =
          isAppServerDown(dependencies) &&
          dependencies.runnerRepository.listRunners().isNotEmpty;
      final Finder problemTitle = find.text(runnerProblemTitle);
      final Finder serverTitle = find.text(_serverDownTitle);
      expect(problemTitle, hasProblem ? findsOneWidget : findsNothing);
      expect(serverTitle, showsServerDown ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('test_build_this_runner_problem_property_offers_local_only_'
      'when_missing', (WidgetTester tester) async {
    final Random random = seededRandom(73507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );
      if (dependencies.runnerRepository.findThisRunnerProblem() == null) {
        continue;
      }

      final List<PlaceOffer>? offers = dependencies.runnerRepository
          .findThisDeviceOffers();
      final bool offersLocal =
          offers != null &&
          offers.any(
            (PlaceOffer offer) => offer.place == AgentPlace.localProcess,
          );
      final bool canAddLocal = offers != null && !offersLocal;
      final Finder button = findBannerText(
        runnerProblemTitle,
        runLocallyLabel,
      );
      expect(button, canAddLocal ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('test_build_this_runner_problem_property_shows_the_problem', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(73508);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );
      final String? problem = dependencies.runnerRepository
          .findThisRunnerProblem();
      if (problem == null) {
        continue;
      }

      expect(findBannerText(runnerProblemTitle, problem), findsOneWidget);
    }
  });

  testWidgets('test_build_this_runner_problem_property_button_adds_local_'
      'place', (WidgetTester tester) async {
    final Random random = seededRandom(73512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = await pumpRandomDevicesPage(
        tester,
        random,
      );
      final Finder button = findBannerText(
        runnerProblemTitle,
        runLocallyLabel,
      );
      if (button.evaluate().isEmpty) {
        continue;
      }
      final Set<AgentPlace> placesBefore = <AgentPlace>{
        for (final PlaceOffer offer
            in dependencies.runnerRepository.findThisDeviceOffers()!)
          offer.place,
      };

      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump();

      final Set<AgentPlace> placesAfter = <AgentPlace>{
        for (final PlaceOffer offer
            in dependencies.runnerRepository.findThisDeviceOffers()!)
          offer.place,
      };
      expect(placesAfter, <AgentPlace>{
        ...placesBefore,
        AgentPlace.localProcess,
      });
    }
  });
}
