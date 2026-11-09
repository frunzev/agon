import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../screens/new_items/new_item_harness.dart';
import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import '../support/scripted_item_draft_repository.dart';

const int _identifierSpan = 3;
const int _largestPushCount = 8;

AppRoute _randomRoute(Random random) {
  final int number = random.nextInt(_identifierSpan);
  final List<AppRoute> choices = <AppRoute>[
    const NewTaskRoute(),
    const NewJobRoute(),
    NewItemFormRoute(pickOne(random, DraftKind.values)),
    ProjectRoute(ProjectId('project-$number')),
    EditTaskRoute(TaskId('task-$number')),
    TaskRunRoute(RunId('run-$number')),
    const WorkspaceSwitcherRoute(),
  ];
  return pickOne(random, choices);
}

AppNavigation _openRandomStack(Random random) {
  final AppNavigation navigation = AppNavigation(
    initialRoute: SectionRoute(pickOne(random, AppSection.values)),
  );
  final int pushCount = random.nextInt(_largestPushCount);
  for (int i = 0; i < pushCount; i += 1) {
    navigation.openRoute(_randomRoute(random));
  }
  return navigation;
}

void main() {
  test('test_open_route_property_a_second_push_of_the_top_is_ignored', () {
    final Random random = seededRandom(52601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = _openRandomStack(random);
      final AppRoute route = _randomRoute(random);
      navigation.openRoute(route);
      final List<AppRoute> routesAfterFirstPush = navigation.routes;
      int notificationCount = 0;
      navigation.addListener(() => notificationCount += 1);

      navigation.openRoute(route);

      expect(navigation.routes, routesAfterFirstPush, reason: '$route');
      expect(navigation.currentRoute, route);
      expect(notificationCount, 0);
    }
  });

  test('test_open_route_property_never_stacks_two_equal_routes', () {
    final Random random = seededRandom(52602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = _openRandomStack(random);
      final int pushCount = random.nextInt(_largestPushCount);
      for (int push = 0; push < pushCount; push += 1) {
        final AppRoute topBefore = navigation.currentRoute;
        final int depthBefore = navigation.routes.length;
        final AppRoute route = _randomRoute(random);

        navigation.openRoute(route);

        final int expectedDepth = route == topBefore
            ? depthBefore
            : depthBefore + 1;
        expect(navigation.routes.length, expectedDepth);
        expect(navigation.currentRoute, route);
      }
      final List<AppRoute> routes = navigation.routes;
      for (int index = 1; index < routes.length; index += 1) {
        expect(routes[index], isNot(routes[index - 1]), reason: '$routes');
      }
    }
  });

  test('test_open_route_property_reopens_once_the_page_was_closed', () {
    final Random random = seededRandom(52603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = _openRandomStack(random);
      final AppRoute route = _randomRoute(random);
      navigation.openRoute(route);
      final List<AppRoute> routesWithPage = navigation.routes;
      if (routesWithPage.length < 2) {
        continue;
      }

      navigation.closeRoute();
      navigation.openRoute(route);

      expect(navigation.routes, routesWithPage);
    }
  });

  testWidgets(
    'test_open_route_property_double_tap_on_add_manually_opens_one',
    (WidgetTester tester) async {
      final Random random = seededRandom(52604);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final DraftKind kind = pickOne(random, DraftKind.values);
        final AppNavigation navigation = await openNewItem(
          tester,
          route: newItemRoutes[kind]!,
          dependencies: buildNewItemDependencies(
            ScriptedItemDraftRepository(),
          ),
        );
        final int depthBefore = navigation.routes.length;
        final int tapCount = 2 + random.nextInt(3);

        for (int tap = 0; tap < tapCount; tap += 1) {
          await tester.tap(findAppButton(addManuallyLabel));
        }
        await pumpFrames(tester);

        expect(navigation.routes.length, depthBefore + 1, reason: '$kind');
        expect(navigation.currentRoute, NewItemFormRoute(kind));
        expect(tester.takeException(), isNull);
      }
    },
  );
}
