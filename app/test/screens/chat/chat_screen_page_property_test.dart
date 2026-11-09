import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/screens/chat/chat_context_panel.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/page_header.dart';
import 'package:agent_orchestration/widgets/route_line.dart';

import '../../support/chat_composer_harness.dart';
import '../../support/random_inputs.dart';
import 'support/chat_screen_pumping.dart';
import 'support/random_chat_conversations.dart';
import 'support/random_chat_page_layouts.dart';
import 'support/scripted_message_sends.dart';

const String _openRunLabel = 'Open run';
const String _sandboxTerm = 'Sandbox';

Future<ShownChatScreen> _pumpReleaseChat(
  WidgetTester tester,
  Random random, {
  required Size size,
  required List<AppRoute> routesBelow,
}) {
  return pumpChatScreen(
    tester,
    size: size,
    runId: galleryRunningRun.id,
    dependencies: buildChatScreenDependencies(random, galleryRunningRun.id),
    routesBelow: routesBelow,
  );
}

Future<void> _removeRunnerFromWorkspace(AppDependencies dependencies) {
  return dependencies.deviceRepository.removeDeviceFromWorkspace(
    GalleryDeviceIds.macStudio,
    GalleryWorkspaceIds.acme,
  );
}

List<String> _readFactTerms(WidgetTester tester) {
  final ChatContextPanel panel = tester.widget(find.byType(ChatContextPanel));
  return <String>[for (final Fact fact in panel.facts) fact.term];
}

void main() {
  testWidgets('test_chat_screen_build_property_every_run_renders_at_every_'
      'size', (WidgetTester tester) async {
    final Random random = seededRandom(98401);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      await pumpRandomChatScreen(tester, random);

      expect(tester.takeException(), isNull);
      expect(find.byType(PageHeader), findsOneWidget);
    }
  });

  testWidgets('test_chat_screen_build_property_a_stored_message_shows_up_at_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(98402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownChatScreen shown = await pumpRandomChatScreen(tester, random);
      final String text = 'stored ${randomText(random)}';

      await shown.dependencies.chatRepository.sendMessage(shown.runId, text);
      await tester.pump();

      expect(find.text(text.trim()), findsOneWidget);
    }
  });

  testWidgets('test_chat_screen_build_property_typed_text_survives_new_'
      'messages', (WidgetTester tester) async {
    final Random random = seededRandom(98403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownChatScreen shown = await pumpRandomChatScreen(tester, random);
      final String typed = 'draft ${randomText(random)}';
      await tester.enterText(findComposerField(), typed);

      await shown.dependencies.chatRepository.sendMessage(
        shown.runId,
        'arrived ${randomText(random)}',
      );
      await tester.pump();

      expect(readComposerText(tester), typed);
    }
  });

  testWidgets('test_build_page_property_a_runner_gone_from_the_workspace_'
      'keeps_the_chat_working', (WidgetTester tester) async {
    final Random random = seededRandom(98404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomChatWindowSize(random);
      final ShownChatScreen shown = await _pumpReleaseChat(
        tester,
        random,
        size: size,
        routesBelow: const <AppRoute>[],
      );

      await _removeRunnerFromWorkspace(shown.dependencies);
      await tester.pump();

      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(find.text('Agent on mac-studio'), findsOneWidget);
      expect(findComposerField(), findsOneWidget);
    }
  });

  testWidgets('test_build_page_property_sandbox_stays_without_a_known_'
      'runner', (WidgetTester tester) async {
    final Random random = seededRandom(98405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownChatScreen shown = await _pumpReleaseChat(
        tester,
        random,
        size: randomLargeWindowSize(random),
        routesBelow: const <AppRoute>[],
      );
      final Task task = readExpectedRunContext(shown).task;
      final String sandbox = describeRunSandbox(task.agentPlace);
      final List<String> termsWithRunner = _readFactTerms(tester);
      final bool isSandboxShown = find.text(sandbox).evaluate().isNotEmpty;

      await _removeRunnerFromWorkspace(shown.dependencies);
      await tester.pump();

      expect(termsWithRunner, contains(_sandboxTerm));
      expect(isSandboxShown, isTrue);
      expect(_readFactTerms(tester), <String>[
        ...termsWithRunner.take(2),
        _sandboxTerm,
      ]);
      expect(find.text(sandbox), findsOneWidget);
    }
  });

  testWidgets('test_build_page_property_route_starts_at_this_device', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(98406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownChatScreen shown = await _pumpReleaseChat(
        tester,
        random,
        size: randomChatWindowSize(random),
        routesBelow: const <AppRoute>[],
      );

      final RouteLine route = tester.widget(find.byType(RouteLine));
      final String thisDevice = shown.dependencies.deviceRepository
          .currentDevice()
          .name;
      expect(route.startName, thisDevice);
      expect(route.endName, readExpectedRunContext(shown).runnerName);
    }
  });

  testWidgets('test_return_to_run_property_back_link_opens_the_run_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(98407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownChatScreen shown = await pumpRandomChatScreen(tester, random);

      await tester.tap(find.byType(BackLinkButton));
      await tester.pump();

      final AppRoute expected = TaskRunRoute(shown.runId);
      expect(shown.navigation.currentRoute, expected);
      expect(shown.navigation.routes, <AppRoute>[expected]);
    }
  });

  testWidgets('test_return_to_run_property_open_run_opens_the_run_page', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(98408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ShownChatScreen shown = await _pumpReleaseChat(
        tester,
        random,
        size: randomLargeWindowSize(random),
        routesBelow: const <AppRoute>[],
      );

      await tester.ensureVisible(find.text(_openRunLabel));
      await tester.tap(find.text(_openRunLabel));
      await tester.pump();

      expect(shown.navigation.currentRoute, TaskRunRoute(shown.runId));
    }
  });

  testWidgets('test_return_to_run_property_going_back_closes_the_chat_'
      'opened_from_the_run', (WidgetTester tester) async {
    final Random random = seededRandom(98409);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppRoute runPage = TaskRunRoute(galleryRunningRun.id);
      final List<AppRoute> routesBelow = <AppRoute>[
        if (random.nextBool()) const SectionRoute(AppSection.tasks),
        runPage,
      ];
      final ShownChatScreen shown = await _pumpReleaseChat(
        tester,
        random,
        size: randomChatWindowSize(random),
        routesBelow: routesBelow,
      );

      await tester.tap(find.byType(BackLinkButton));
      await tester.pump();

      expect(shown.navigation.routes, routesBelow);
    }
  });
}
