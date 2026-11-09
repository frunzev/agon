import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/screens/task_run/run_page_header.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/random_inputs.dart';
import 'support/run_page_header_pages.dart';
import 'support/run_page_retry_harness.dart';

const String _chatLabel = 'Chat with agent';
const String _askLabel = 'Ask the agent';
const String _deleteLabel = 'Delete';

PageHeader _readHeader(WidgetTester tester) {
  return tester.widget(
    find.descendant(
      of: find.byType(RunPageHeader),
      matching: find.byType(PageHeader),
    ),
  );
}

List<String> _readActionLabels(WidgetTester tester) {
  final List<String> labels = <String>[];
  for (final Widget action in _readHeader(tester).actions) {
    labels.add((action as AppButton).label);
  }
  return labels;
}

List<String> _expectedActionLabels(Run run, {required bool canLeave}) {
  if (isRunActive(run)) {
    return const <String>[cancelRunButtonLabel, _chatLabel];
  }
  final List<String> labels = <String>[if (canLeave) _deleteLabel, _askLabel];
  if (run.status != RunStatus.done) {
    labels.add(retryRunLabel);
  }
  return labels;
}

String _chatButtonLabel(Run run) {
  return isRunActive(run) ? _chatLabel : _askLabel;
}

void main() {
  testWidgets('test_run_page_header_build_property_titles_the_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);

      await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: randomRoutesBelowRun(random),
        opener: null,
      );

      expect(tester.takeException(), isNull);
      final PageHeader header = _readHeader(tester);
      expect(header.title, page.runLabel);
      expect(header.title, endsWith('#${page.run.number}'));
      expect(header.summary, isNotEmpty);
    }
  });

  testWidgets('test_run_page_header_build_property_actions_follow_the_'
      'run_status', (WidgetTester tester) async {
    final Random random = seededRandom(1141502);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final RunPageCase page = randomRunPageCase(random);

      await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: randomRoutesBelowRun(random),
        opener: null,
      );

      expect(
        _readActionLabels(tester),
        _expectedActionLabels(page.run, canLeave: true),
        reason: page.run.status.name,
      );
    }
  });

  testWidgets('test_run_page_header_build_property_run_windows_never_'
      'delete', (WidgetTester tester) async {
    final Random random = seededRandom(1141503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);

      await openRunPageInRunWindow(tester, page: page);

      expect(tester.takeException(), isNull);
      expect(
        _readActionLabels(tester),
        _expectedActionLabels(page.run, canLeave: false),
        reason: page.run.status.name,
      );
    }
  });

  testWidgets('test_open_chat_property_opens_the_chat_of_this_run', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: randomRoutesBelowRun(random),
        opener: null,
      );

      await tapAppButton(tester, _chatButtonLabel(page.run));

      expect(tester.takeException(), isNull);
      expect(navigation.currentRoute, ChatRoute(page.run.id));
    }
  });

  testWidgets('test_open_chat_property_keeps_the_run_page_below', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);
      final List<AppRoute> below = randomRoutesBelowRun(random);
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: below,
        opener: null,
      );

      await tapAppButton(tester, _chatButtonLabel(page.run));

      expect(navigation.routes, <AppRoute>[
        ...below,
        TaskRunRoute(page.run.id),
        ChatRoute(page.run.id),
      ]);
    }
  });

  testWidgets('test_open_chat_property_works_inside_a_run_window', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);
      final AppNavigation navigation = await openRunPageInRunWindow(
        tester,
        page: page,
      );

      await tapAppButton(tester, _chatButtonLabel(page.run));

      expect(tester.takeException(), isNull);
      expect(navigation.currentRoute, ChatRoute(page.run.id));
    }
  });
}
