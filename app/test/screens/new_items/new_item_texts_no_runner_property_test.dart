import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../presentation/support/plain_shown_text.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/runner_memberships.dart';
import '../../support/sample_runners.dart';
import '../../support/scripted_item_draft_repository.dart';
import 'new_item_harness.dart';
import 'new_item_screen_flow.dart';

const String _pausedRunnerPhrase = 'new runs';
const String _onlineWord = 'online';
const String _pauseLabel = 'Pause new runs';
const String _noRunnerPage = 'task-new-chat-no-runner';
const String _runnerPage = 'runner-detail';

List<Runner> _runnersWithOnlyPausedOnline(Random random) {
  return <Runner>[
    buildOnlineRunnerOn(GalleryDeviceIds.macStudio).asPaused(),
    for (final Runner runner in randomRunners(random))
      if (runner.online) runner.asPaused() else runner,
  ];
}

Future<void> _openWithRunners(
  WidgetTester tester, {
  required Random random,
  required List<Runner> runners,
}) async {
  final RunnerMembership membership = buildWorkspaceMembersFor(runners);
  final AppDependencies dependencies = replaceRepositories(
    buildNewItemDependencies(ScriptedItemDraftRepository()),
    deviceRepository: membership.devices,
    runnerRepository: FakeRunnerRepository(
      runners: runners,
      deviceRepository: membership.devices,
      workspaceRepository: membership.workspaces,
      thisDeviceOffers: null,
      thisRunnerProblem: null,
    ),
  );
  await openRecordedNewItemPage(
    tester,
    kind: pickOne(random, DraftKind.values),
    startedFrom: null,
    dependencies: dependencies,
    size: randomScreenSize(random),
  );
}

List<String> _readNoticeTexts(WidgetTester tester) {
  final Finder notice = find.byType(NoticeBanner);
  final Iterable<Text> texts = tester.widgetList<Text>(
    find.descendant(of: notice, matching: find.byType(Text)),
  );
  return <String>[for (final Text text in texts) text.data ?? ''];
}

void main() {
  testWidgets('test_no_runner_notice_build_property_true_while_a_paused_'
      'runner_is_online', (WidgetTester tester) async {
    final Random random = seededRandom(1130701);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Runner> runners = _runnersWithOnlyPausedOnline(random);

      await _openWithRunners(tester, random: random, runners: runners);

      expect(find.text(noRunnerTitle), findsOneWidget, reason: '$runners');
      for (final String shown in _readNoticeTexts(tester)) {
        expect(shown, isNot(contains(_onlineWord)), reason: shown);
      }
    }
  });

  test('test_no_runner_title_property_names_what_pausing_stops', () {
    final String pausedPhrase = _pauseLabel.toLowerCase();
    final String noRunnerPage = readDesignPageText(_noRunnerPage);
    final String runnerPage = readDesignPageText(_runnerPage);

    expect(pausedPhrase, endsWith(_pausedRunnerPhrase));
    expect(runnerPage, contains(' $_pauseLabel '));
    expect(noRunnerTitle, endsWith(_pausedRunnerPhrase));
    expect(noRunnerTitle, isNot(contains(_onlineWord)));
    expect(noRunnerPage, contains(' $noRunnerTitle '));
    expectPlainLabel(noRunnerTitle);
  });

  test('test_no_runner_text_property_waits_for_a_runner_taking_new_runs', () {
    final String noRunnerPage = readDesignPageText(_noRunnerPage);

    expect(noRunnerText, contains(_pausedRunnerPhrase));
    expect(noRunnerText, isNot(contains(_onlineWord)));
    expect(noRunnerText, contains(fillInFormLabel.toLowerCase()));
    expect(noRunnerPage, contains(' $noRunnerText '));
    expectPlainSentences(noRunnerText);
  });
}
