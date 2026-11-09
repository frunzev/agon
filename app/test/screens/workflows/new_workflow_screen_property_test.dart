import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/random_inputs.dart';
import 'new_workflow_scene.dart';

void main() {
  test('test_new_workflow_screen_constructor_property_keeps_navigation', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = buildNewWorkflowNavigation();
      final NewWorkflowScreen screen = NewWorkflowScreen(
        navigation: navigation,
      );

      expect(screen.navigation, same(navigation));
    }
  });

  test('test_new_workflow_screen_constructor_property_screens_keep_their_'
      'own_navigation', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation first = buildNewWorkflowNavigation();
      final AppNavigation second = buildNewWorkflowNavigation();

      expect(NewWorkflowScreen(navigation: first).navigation, same(first));
      expect(NewWorkflowScreen(navigation: second).navigation, same(second));
    }
  });

  testWidgets('test_new_workflow_screen_constructor_property_reports_to_its_'
      'navigation', (WidgetTester tester) async {
    final Random random = seededRandom(1220801);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation shown = buildNewWorkflowNavigation();
      final AppNavigation other = buildNewWorkflowNavigation();
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: shown),
      );

      await tapNewWorkflowLabel(tester, 'Cancel');

      expect(shown.routes, const <AppRoute>[newWorkflowFormSectionRoute]);
      expect(other.routes.length, 2);
    }
  });

  test('test_new_workflow_screen_create_state_property_each_call_makes_a_'
      'fresh_state', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final NewWorkflowScreen screen = NewWorkflowScreen(
        navigation: buildNewWorkflowNavigation(),
      );

      expect(identical(screen.createState(), screen.createState()), isFalse);
    }
  });

  testWidgets('test_new_workflow_screen_create_state_property_a_new_key_'
      'starts_empty', (WidgetTester tester) async {
    final Random random = seededRandom(1220802);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = buildNewWorkflowNavigation();
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(key: ValueKey<int>(i * 2), navigation: navigation),
      );
      await tester.enterText(findWorkflowDescription(), randomText(random));
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(
          key: ValueKey<int>(i * 2 + 1),
          navigation: navigation,
        ),
      );

      final TextField field = tester.widget<TextField>(
        findWorkflowDescription(),
      );
      expect(field.controller!.text, isEmpty);
    }
  });

  testWidgets('test_new_workflow_screen_create_state_property_rebuilds_keep_'
      'the_typed_words', (WidgetTester tester) async {
    final Random random = seededRandom(1220803);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewWorkflowScreen screen = NewWorkflowScreen(
        navigation: buildNewWorkflowNavigation(),
      );
      final String typed = randomText(random);
      await pumpNewWorkflowScreen(tester, random, screen);
      await tester.enterText(findWorkflowDescription(), typed);
      await pumpNewWorkflowScreen(tester, random, screen);

      final TextField field = tester.widget<TextField>(
        findWorkflowDescription(),
      );
      expect(field.controller!.text, typed);
    }
  });

  testWidgets('test_new_workflow_screen_dispose_property_leaving_changes_no_'
      'route', (WidgetTester tester) async {
    final Random random = seededRandom(1220804);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = buildNewWorkflowNavigation();
      final List<AppRoute> routesBefore = navigation.routes;
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: navigation),
      );
      await tester.enterText(findWorkflowDescription(), randomText(random));
      if (random.nextBool()) {
        await tester.enterText(
          findWorkflowDescription(),
          randomDescriptionWhiteSpace(random),
        );
        await tapNewWorkflowLabel(tester, draftWorkflowLabel);
      }

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
      expect(navigation.routes, routesBefore);
    }
  });

  testWidgets('test_new_workflow_screen_dispose_property_a_reopened_form_'
      'starts_empty', (WidgetTester tester) async {
    final Random random = seededRandom(1220805);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = buildNewWorkflowNavigation();
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: navigation),
      );
      await tester.enterText(findWorkflowDescription(), 'Words $i');
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: navigation),
      );

      final TextField field = tester.widget<TextField>(
        findWorkflowDescription(),
      );
      expect(field.controller!.text, isEmpty);
      expect(field.decoration!.errorText, isNull);
    }
  });

  testWidgets('test_new_workflow_screen_dispose_property_disposes_the_'
      'description_once', (WidgetTester tester) async {
    final Random random = seededRandom(1220806);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: buildNewWorkflowNavigation()),
      );
      final TextEditingController controller = tester
          .widget<TextField>(findWorkflowDescription())
          .controller!;

      await tester.pumpWidget(const SizedBox.shrink());

      expect(tester.takeException(), isNull);
      expect(() => controller.addListener(() {}), throwsFlutterError);
    }
  });
}
