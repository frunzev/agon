import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/host_text.dart';
import 'package:agent_orchestration/screens/chat/chat_context_panel.dart';
import 'package:agent_orchestration/screens/chat/chat_page_layout.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';

import '../../support/random_inputs.dart';
import '../../support/sample_runners.dart';
import 'support/random_chat_conversations.dart';
import 'support/random_chat_page_layouts.dart';

const String _sandboxTerm = 'Sandbox';
const String _canReachTerm = 'Can reach';
const int _taskAndSessionFactCount = 2;

ChatPageLayout _withRunner(ChatPageLayout layout, Runner? runner) {
  return ChatPageLayout(
    runContext: layout.runContext,
    conversation: layout.conversation,
    runner: runner,
    thisDevice: layout.thisDevice,
    onBack: layout.onBack,
    onSend: layout.onSend,
  );
}

Runner _runnerWithoutHosts() {
  final Runner base = buildOnlineRunnerOn(GalleryDeviceIds.macStudio);
  return Runner(
    deviceId: base.deviceId,
    labels: base.labels,
    slotsTotal: base.slotsTotal,
    slotsBusy: base.slotsBusy,
    link: base.link,
    online: base.online,
    acceptingNewRuns: base.acceptingNewRuns,
    offers: const <AgentPlace>[AgentPlace.container],
    allowedHosts: const <String>[],
  );
}

ChatPageLayout _layoutAtRandom(Random random) {
  return buildRandomChatPageLayout(
    random,
    onBack: ignoreGoingBack,
    onSend: acceptEveryMessage,
  );
}

Future<List<Fact>> _readShownFacts(
  WidgetTester tester,
  Random random,
  ChatPageLayout layout,
) async {
  await pumpChatWidget(
    tester,
    size: randomLargeWindowSize(random),
    child: layout,
  );
  final ChatContextPanel panel = tester.widget(find.byType(ChatContextPanel));
  return panel.facts;
}

List<String> _describeFacts(List<Fact> facts) {
  return <String>[
    for (final Fact fact in facts)
      '${fact.term}: ${joinTextSegments(fact.description)}',
  ];
}

void main() {
  testWidgets('test_build_facts_property_sandbox_shows_without_a_runner', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100321);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ChatPageLayout layout = _withRunner(_layoutAtRandom(random), null);

      final List<Fact> facts = await _readShownFacts(tester, random, layout);

      final List<Fact> placeFacts = facts.sublist(_taskAndSessionFactCount);
      expect(placeFacts, hasLength(1));
      expect(placeFacts.single.term, _sandboxTerm);
      expect(
        joinTextSegments(placeFacts.single.description),
        describeRunSandbox(layout.runContext.task.agentPlace),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_facts_property_container_without_hosts_reads_'
      'like_the_runner_page', (WidgetTester tester) async {
    final Random random = seededRandom(100322);
    int containerLayouts = 0;

    for (int i = 0; i < widgetPropertyIterations * 3; i += 1) {
      final ChatPageLayout randomLayout = _layoutAtRandom(random);
      if (randomLayout.runContext.task.agentPlace != AgentPlace.container) {
        continue;
      }
      containerLayouts += 1;
      final ChatPageLayout layout = _withRunner(
        randomLayout,
        _runnerWithoutHosts(),
      );

      final List<Fact> facts = await _readShownFacts(tester, random, layout);

      final Fact canReach = facts.last;
      expect(canReach.term, _canReachTerm);
      expect(
        joinTextSegments(canReach.description),
        joinTextSegments(describeContainerNetwork(const <String>[])),
      );
      expect(joinTextSegments(canReach.description), isNotEmpty);
    }
    expect(containerLayouts, greaterThan(0));
  });

  testWidgets('test_build_facts_property_place_facts_follow_the_task_place_'
      'and_the_runner', (WidgetTester tester) async {
    final Random random = seededRandom(100323);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatPageLayout layout = _layoutAtRandom(random);

      final List<Fact> facts = await _readShownFacts(tester, random, layout);

      final List<Fact> expected = buildRunnerFacts(
        runner: layout.runner,
        place: layout.runContext.task.agentPlace,
      );
      expect(
        _describeFacts(facts.sublist(_taskAndSessionFactCount)),
        _describeFacts(expected),
      );
      expect(facts[_taskAndSessionFactCount].term, _sandboxTerm);
    }
  });
}
