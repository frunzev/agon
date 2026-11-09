import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/chat/chat_run_context.dart';
import 'package:agent_orchestration/screens/chat/chat_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../../support/random_inputs.dart';
import 'support/chat_screen_pumping.dart';
import 'support/random_chat_conversations.dart';

String _joinSummary(PageHeader header) {
  final StringBuffer joined = StringBuffer();
  for (final TextSegment segment in header.summary) {
    joined.write(segment.text);
  }
  return joined.toString();
}

String _readBackLabel(WidgetTester tester) {
  final PageHeader header = tester.widget(find.byType(PageHeader));
  return header.backLink!.label;
}

void main() {
  test('test_chat_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(98301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId runId = pickOne(random, galleryRuns).id;
      final AppDependencies dependencies = buildChatScreenDependencies(
        random,
        runId,
      );
      final AppNavigation navigation = AppNavigation(
        initialRoute: ChatRoute(runId),
      );

      final ChatScreen screen = buildChatScreen(
        ShownChatScreen(
          runId: runId,
          dependencies: dependencies,
          navigation: navigation,
        ),
      );

      expect(screen.runId, runId);
      expect(screen.taskRepository, same(dependencies.taskRepository));
      expect(screen.workflowRepository, same(dependencies.workflowRepository));
      expect(screen.chatRepository, same(dependencies.chatRepository));
      expect(screen.runnerRepository, same(dependencies.runnerRepository));
      expect(screen.deviceRepository, same(dependencies.deviceRepository));
      expect(screen.navigation, same(navigation));
    }
  });

  testWidgets('test_chat_screen_constructor_property_watches_its_run_while_'
      'shown', (WidgetTester tester) async {
    final Random random = seededRandom(98302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownChatScreen shown = await pumpRandomChatScreen(tester, random);
      final FakeTaskRepository tasks =
          shown.dependencies.taskRepository as FakeTaskRepository;
      final bool isWatchedWhileShown = tasks.isWatchingRun(shown.runId);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(isWatchedWhileShown, isTrue);
      expect(tasks.isWatchingRun(shown.runId), isFalse);
    }
  });

  testWidgets('test_chat_screen_constructor_property_another_run_shows_'
      'that_run', (WidgetTester tester) async {
    final Random random = seededRandom(98303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownChatScreen first = await pumpRandomChatScreen(tester, random);
      final RunId otherRunId = pickOne(random, galleryRuns).id;
      final ShownChatScreen other = ShownChatScreen(
        runId: otherRunId,
        dependencies: buildChatScreenDependencies(random, otherRunId),
        navigation: first.navigation,
      );

      await pumpChatWidget(
        tester,
        size: randomChatWindowSize(random),
        child: buildChatScreen(other),
      );

      final String expectedLabel = readExpectedRunContext(other).runLabel;
      expect(tester.takeException(), isNull);
      expect(_readBackLabel(tester), expectedLabel);
    }
  });

  testWidgets('test_read_run_context_property_header_matches_the_stored_'
      'run', (WidgetTester tester) async {
    final Random random = seededRandom(98304);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ShownChatScreen shown = await pumpRandomChatScreen(tester, random);

      final ChatRunContext expected = readExpectedRunContext(shown);
      final PageHeader header = tester.widget(find.byType(PageHeader));
      expect(header.title, expected.agentTitle);
      expect(_joinSummary(header), expected.agentSummary);
      expect(header.backLink!.label, expected.runLabel);
    }
  });

  testWidgets('test_read_run_context_property_run_label_names_workflow_or_'
      'task', (WidgetTester tester) async {
    final Random random = seededRandom(98305);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ShownChatScreen shown = await pumpRandomChatScreen(tester, random);

      final ChatRunContext expected = readExpectedRunContext(shown);
      final Task task = expected.task;
      final String name = task.doer is WorkflowDoer
          ? expected.workflow!.name
          : task.title;
      expect(_readBackLabel(tester), startsWith(name));
      expect(_readBackLabel(tester), endsWith('#${expected.run.number}'));
    }
  });

  testWidgets('test_read_run_context_property_a_cancelled_run_is_reread', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(98306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownChatScreen shown = await pumpChatScreen(
        tester,
        size: randomChatWindowSize(random),
        runId: galleryRunningRun.id,
        dependencies: buildChatScreenDependencies(
          random,
          galleryRunningRun.id,
        ),
        routesBelow: const <AppRoute>[],
      );
      final Finder routes = find.byType(RouteLine);
      final int routesWhileRunning = routes.evaluate().length;

      await shown.dependencies.taskRepository.cancelRun(shown.runId);
      await tester.pump();

      expect(routesWhileRunning, 1);
      expect(find.byType(RouteLine), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
