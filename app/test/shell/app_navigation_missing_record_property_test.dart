import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../support/random_inputs.dart';
import 'app_navigation_form_stacks.dart';

List<AppRoute> _expectClosedStack(List<AppRoute> stack, AppRoute missing) {
  final int pageIndex = stack.indexOf(missing);
  if (pageIndex < 0) {
    return stack;
  }
  if (pageIndex == 0) {
    return <AppRoute>[SectionRoute(missing.section)];
  }
  return stack.sublist(0, pageIndex);
}

AppRoute _pickMissingPage(Random random, List<AppRoute> stack) {
  final List<AppRoute> recordPages = <AppRoute>[
    for (final AppRoute route in stack)
      if (route is! SectionRoute) route,
  ];
  if (recordPages.isEmpty || random.nextInt(4) == 0) {
    return randomPageBelowForm(random);
  }
  return pickOne(random, recordPages);
}

List<AppRoute> _randomStackWithRecordRoot(Random random) {
  final List<AppRoute> stack = listFormStackRoutes(randomFormStack(random));
  if (random.nextBool()) {
    return stack;
  }
  return stack.sublist(1);
}

void main() {
  test('test_close_missing_record_page_property_drops_it_and_above', () {
    final Random random = seededRandom(5310501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppRoute> stack = _randomStackWithRecordRoot(random);
      final AppNavigation navigation = openFormStack(randomFormStack(random));
      navigation.restoreRoutes(stack);
      final AppRoute missing = _pickMissingPage(random, stack);

      navigation.closeMissingRecordPage(missing);

      expect(
        navigation.routes,
        _expectClosedStack(stack, missing),
        reason: '$stack $missing',
      );
      expect(navigation.routes, isNotEmpty);
      expect(navigation.routes, isNot(contains(missing)));
    }
  });

  test('test_close_missing_record_page_property_closing_twice_is_once', () {
    final Random random = seededRandom(5310502);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppRoute> stack = _randomStackWithRecordRoot(random);
      final AppNavigation navigation = openFormStack(randomFormStack(random));
      navigation.restoreRoutes(stack);
      final AppRoute missing = _pickMissingPage(random, stack);
      navigation.closeMissingRecordPage(missing);
      final List<AppRoute> closedOnce = navigation.routes;
      final NotificationCounter counter = listenForNotifications(navigation);

      navigation.closeMissingRecordPage(missing);

      expect(navigation.routes, closedOnce);
      expect(counter.count, 0);
    }
  });

  test('test_close_missing_record_page_property_notifies_only_on_change', () {
    final Random random = seededRandom(5310503);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppRoute> stack = _randomStackWithRecordRoot(random);
      final AppNavigation navigation = openFormStack(randomFormStack(random));
      navigation.restoreRoutes(stack);
      final AppRoute missing = _pickMissingPage(random, stack);
      final NotificationCounter counter = listenForNotifications(navigation);

      navigation.closeMissingRecordPage(missing);

      final int expectedCount = stack.contains(missing) ? 1 : 0;
      expect(counter.count, expectedCount);
    }
  });

  test('test_close_missing_record_page_property_keeps_pages_below', () {
    final Random random = seededRandom(5310504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack formStack = randomFormStack(random);
      final List<AppRoute> stack = listFormStackRoutes(formStack);
      final AppNavigation navigation = openFormStack(formStack);
      final int pageIndex = 1 + random.nextInt(stack.length - 1);
      final AppRoute missing = stack[pageIndex];

      navigation.closeMissingRecordPage(missing);

      expect(navigation.routes.first, stack.first);
      expect(stack.sublist(0, navigation.routes.length), navigation.routes);
    }
  });
}
