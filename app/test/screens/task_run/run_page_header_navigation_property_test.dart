import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/screens/task_run/run_page_header.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/run_page_header_pages.dart';

const RunId _otherRunId = RunId('other-run');

Finder _findTasksLink() {
  return find.descendant(
    of: find.byType(RunPageHeader),
    matching: find.byType(BackLinkButton),
  );
}

Future<void> _tapTasksLink(WidgetTester tester) async {
  await tester.ensureVisible(_findTasksLink());
  await tester.tap(_findTasksLink());
  await pumpFrames(tester);
}

AppNavigation _randomNavigation(Random random) {
  if (random.nextBool()) {
    return AppNavigation.limitedToRunPages(runId: _otherRunId);
  }
  final AppNavigation navigation = AppNavigation(
    initialRoute: pickOne(random, otherSectionRoutes),
  );
  if (random.nextBool()) {
    navigation.openRoute(const TaskRunRoute(_otherRunId));
  }
  return navigation;
}

void main() {
  test('test_can_leave_run_property_main_windows_can_always_leave', () {
    final Random random = seededRandom(1141301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation(
        initialRoute: pickOne(random, <AppRoute>[
          ...otherSectionRoutes,
          tasksSectionRoute,
          const TaskRunRoute(_otherRunId),
        ]),
      );

      expect(canLeaveRun(navigation), isTrue);
    }
  });

  test('test_can_leave_run_property_run_windows_never_leave', () {
    final Random random = seededRandom(1141302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = AppNavigation.limitedToRunPages(
        runId: RunId('run-${random.nextInt(999)}'),
      );

      expect(canLeaveRun(navigation), isFalse);
    }
  });

  test('test_can_leave_run_property_matches_opening_the_tasks', () {
    final Random random = seededRandom(1141303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = _randomNavigation(random);
      final bool canLeave = canLeaveRun(navigation);

      expect(canLeave, navigation.canOpen(tasksSectionRoute));
      if (canLeave) {
        navigation.returnTo(tasksSectionRoute);
        expect(navigation.currentRoute, tasksSectionRoute);
      } else {
        expect(() => navigation.returnTo(tasksSectionRoute), throwsStateError);
      }
    }
  });

  testWidgets('test_offer_tasks_link_property_main_windows_offer_tasks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141304);

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
      final BackLinkButton link = tester.widget(_findTasksLink());
      expect(link.link.label, 'Tasks');
    }
  });

  testWidgets('test_offer_tasks_link_property_run_windows_offer_none', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);

      await openRunPageInRunWindow(tester, page: page);

      expect(tester.takeException(), isNull);
      expect(find.byType(RunPageHeader), findsOneWidget);
      expect(_findTasksLink(), findsNothing);
    }
  });

  testWidgets('test_offer_tasks_link_property_tapping_lands_on_tasks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: randomRoutesBelowRun(random),
        opener: null,
      );

      await _tapTasksLink(tester);

      expect(tester.takeException(), isNull);
      expect(navigation.currentRoute, tasksSectionRoute);
      expect(find.byType(RunPageHeader), findsNothing);
    }
  });

  testWidgets('test_return_to_tasks_property_closes_the_run_over_tasks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141307);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: randomRunPageCase(random),
        routesBelow: const <AppRoute>[tasksSectionRoute],
        opener: null,
      );

      await _tapTasksLink(tester);

      expect(navigation.routes, const <AppRoute>[tasksSectionRoute]);
    }
  });

  testWidgets('test_return_to_tasks_property_replaces_the_run_elsewhere', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141308);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppRoute below = pickOne(random, otherSectionRoutes);
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: randomRunPageCase(random),
        routesBelow: <AppRoute>[below],
        opener: null,
      );

      await _tapTasksLink(tester);

      expect(navigation.routes, <AppRoute>[below, tasksSectionRoute]);
    }
  });

  testWidgets('test_return_to_tasks_property_never_leaves_a_run_route', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141309);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: randomRoutesBelowRun(random),
        opener: null,
      );

      await _tapTasksLink(tester);

      expect(navigation.routes, isNot(contains(TaskRunRoute(page.run.id))));
      expect(navigation.routes.whereType<RunPageRoute>(), isEmpty);
    }
  });
}
