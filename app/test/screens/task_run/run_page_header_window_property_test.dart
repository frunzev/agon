import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/task_run/run_page_header.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/run_page_header_pages.dart';
import 'support/run_page_retry_harness.dart';

Future<void> _tapNewWindow(WidgetTester tester) async {
  await tapAppButton(tester, openInNewWindowLabel);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_build_new_window_action_property_needs_an_opener', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool hasOpener = random.nextBool();

      await openRunPageInMainWindow(
        tester,
        random: random,
        page: randomRunPageCase(random),
        routesBelow: randomRoutesBelowRun(random),
        opener: hasOpener ? RecordingRunWindowOpener() : null,
      );

      expect(tester.takeException(), isNull);
      expect(
        findAppButton(openInNewWindowLabel),
        hasOpener ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_build_new_window_action_property_leads_the_actions', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRunPageInMainWindow(
        tester,
        random: random,
        page: randomRunPageCase(random),
        routesBelow: randomRoutesBelowRun(random),
        opener: RecordingRunWindowOpener(),
      );

      final PageHeader header = tester.widget(
        find.descendant(
          of: find.byType(RunPageHeader),
          matching: find.byType(PageHeader),
        ),
      );
      final AppButton first = header.actions.first as AppButton;
      expect(first.label, openInNewWindowLabel);
      expect(first.icon, AppIconKind.newWindow);
      expect(first.tone, ButtonTone.secondary);
      expect(first.onPressed, isNotNull);
    }
  });

  testWidgets('test_build_new_window_action_property_run_windows_hide_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRunPageInRunWindow(tester, page: randomRunPageCase(random));

      expect(tester.takeException(), isNull);
      expect(findAppButton(openInNewWindowLabel), findsNothing);
    }
  });

  testWidgets('test_move_to_new_window_property_opens_this_run_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);
      final RecordingRunWindowOpener opener = RecordingRunWindowOpener();
      await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: randomRoutesBelowRun(random),
        opener: opener,
      );

      await _tapNewWindow(tester);

      expect(opener.openedRuns, <(Object, String)>[
        (page.run.id, page.runLabel),
      ]);
    }
  });

  testWidgets('test_move_to_new_window_property_main_window_shows_tasks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: randomRunPageCase(random),
        routesBelow: randomRoutesBelowRun(random),
        opener: RecordingRunWindowOpener(),
      );

      await _tapNewWindow(tester);

      expect(tester.takeException(), isNull);
      expect(navigation.currentRoute, tasksSectionRoute);
      expect(find.byType(RunPageHeader), findsNothing);
    }
  });

  testWidgets('test_move_to_new_window_property_keeps_the_pages_below', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<AppRoute> below = randomRoutesBelowRun(random);
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: randomRunPageCase(random),
        routesBelow: below,
        opener: RecordingRunWindowOpener(),
      );

      await _tapNewWindow(tester);

      final List<AppRoute> expected = below.last == tasksSectionRoute
          ? below
          : <AppRoute>[...below, tasksSectionRoute];
      expect(navigation.routes, expected);
    }
  });
}
