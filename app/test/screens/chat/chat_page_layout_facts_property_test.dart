import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/chat/chat_context_panel.dart';
import 'package:agent_orchestration/screens/chat/chat_page_layout.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';
import 'package:agent_orchestration/screens/shared/runner_link_route.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../../data/rules/support/random_progress_runs.dart';
import '../../support/random_inputs.dart';
import 'support/random_chat_conversations.dart';
import 'support/random_chat_page_layouts.dart';
import 'support/random_chat_run_contexts.dart';

const String _noSessionYet = 'Not started yet';
const List<RunStatus> _finishedStatuses = <RunStatus>[
  RunStatus.done,
  RunStatus.failed,
  RunStatus.cancelled,
];

ChatPageLayout _layoutAtRandom(Random random) {
  return buildRandomChatPageLayout(
    random,
    onBack: ignoreGoingBack,
    onSend: acceptEveryMessage,
  );
}

bool _expectsRunnerLink(ChatPageLayout layout) {
  final DeviceId? runner = layout.runContext.currentStep.runner;
  final bool isOtherDevice = runner != null && runner != layout.thisDevice.id;
  return isOtherDevice && isRunActive(layout.runContext.run);
}

ChatPageLayout _withRunStatus(ChatPageLayout layout, RunStatus status) {
  final ChatRunContext context = layout.runContext;
  final Run run = context.run.withProgress(
    nextStatus: status,
    nextSteps: context.run.steps,
    nextFinishedAt: context.run.finishedAt,
  );
  return ChatPageLayout(
    runContext: ChatRunContext(
      run: run,
      task: context.task,
      workflow: context.workflow,
      deviceNames: galleryDeviceNames,
    ),
    conversation: layout.conversation,
    runner: layout.runner,
    thisDevice: layout.thisDevice,
    onBack: layout.onBack,
    onSend: layout.onSend,
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
  testWidgets('test_shows_runner_link_property_only_for_an_active_run_on_'
      'another_device', (WidgetTester tester) async {
    final Random random = seededRandom(98001);

    for (int i = 0; i < widgetPropertyIterations * 3; i += 1) {
      final ChatPageLayout layout = _layoutAtRandom(random);

      await pumpChatWidget(
        tester,
        size: randomChatWindowSize(random),
        child: layout,
      );

      final bool isExpected = _expectsRunnerLink(layout);
      final Matcher expected = isExpected ? findsOneWidget : findsNothing;
      expect(find.byType(RouteLine), expected);
    }
  });

  testWidgets('test_shows_runner_link_property_route_joins_this_device_to_'
      'the_runner_over_the_conversation_link', (WidgetTester tester) async {
    final Random random = seededRandom(98002);

    for (int i = 0; i < widgetPropertyIterations * 3; i += 1) {
      final ChatPageLayout layout = _layoutAtRandom(random);
      if (!_expectsRunnerLink(layout)) {
        continue;
      }

      await pumpChatWidget(
        tester,
        size: randomChatWindowSize(random),
        child: layout,
      );

      final RouteLine shown = tester.widget(find.byType(RouteLine));
      final RouteLine expected = buildRunnerLinkRoute(
        startName: layout.thisDevice.name,
        endName: layout.runContext.runnerName,
        link: layout.conversation.link,
      );
      expect(shown.startName, expected.startName);
      expect(shown.endName, expected.endName);
      expect(shown.path, expected.path);
      expect(shown.badgeLabel, expected.badgeLabel);
    }
  });

  testWidgets('test_shows_runner_link_property_finishing_the_run_removes_'
      'the_route', (WidgetTester tester) async {
    final Random random = seededRandom(98003);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatPageLayout active = _withRunStatus(
        _layoutAtRandom(random),
        pickOne(random, activeRunStatuses),
      );
      final ChatPageLayout finished = _withRunStatus(
        active,
        pickOne(random, _finishedStatuses),
      );
      final Size size = randomChatWindowSize(random);

      await pumpChatWidget(tester, size: size, child: active);
      final int activeRoutes = find.byType(RouteLine).evaluate().length;
      await pumpChatWidget(tester, size: size, child: finished);

      expect(activeRoutes, _expectsRunnerLink(active) ? 1 : 0);
      expect(find.byType(RouteLine), findsNothing);
    }
  });

  testWidgets('test_build_facts_property_task_fact_names_task_and_step', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(98004);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatPageLayout layout = _layoutAtRandom(random);
      final ChatRunContext context = layout.runContext;

      final List<Fact> facts = await _readShownFacts(tester, random, layout);

      final String expected =
          '${context.task.title} · ${context.currentStep.name}';
      expect(facts.first.term, 'Task');
      expect(joinTextSegments(facts.first.description), expected);
    }
  });

  testWidgets('test_build_facts_property_session_is_shortened_or_not_'
      'started', (WidgetTester tester) async {
    final Random random = seededRandom(98005);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatPageLayout layout = _layoutAtRandom(random);
      final String? session = layout.runContext.run.agentSession;

      final List<Fact> facts = await _readShownFacts(tester, random, layout);

      final Fact sessionFact = facts[1];
      final TextSegment shown = sessionFact.description.single;
      expect(sessionFact.term, 'Session');
      if (session == null) {
        expect(shown.text, _noSessionYet);
        expect(shown.face, TextFace.body);
      } else {
        expect(shown.text, shortenIdentifier(session));
        expect(shown.face, TextFace.monospace);
      }
    }
  });

  testWidgets('test_build_facts_property_runner_facts_follow_the_runner_'
      'and_the_task_place', (WidgetTester tester) async {
    final Random random = seededRandom(98006);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatPageLayout layout = _layoutAtRandom(random);
      final Runner? runner = layout.runner;

      final List<Fact> facts = await _readShownFacts(tester, random, layout);

      final List<Fact> runnerFacts = buildRunnerFacts(
        runner: runner,
        place: layout.runContext.task.agentPlace,
      );
      expect(_describeFacts(facts.sublist(2)), _describeFacts(runnerFacts));
    }
  });
}
