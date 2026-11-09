import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow_draft.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';
import 'package:agent_orchestration/screens/new_items/item_request_view.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'new_workflow_scene.dart';

void main() {
  testWidgets('test_new_workflow_screen_build_property_never_overflows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1220807);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: buildNewWorkflowNavigation()),
      );
      await tester.enterText(
        findWorkflowDescription(),
        randomText(random) * 4,
      );
      if (random.nextBool()) {
        await tester.enterText(findWorkflowDescription(), '');
        await tapNewWorkflowLabel(tester, draftWorkflowLabel);
      }
      await tester.pump();

      expect(tester.takeException(), isNull, reason: '$width');
    }
  });

  testWidgets('test_new_workflow_screen_build_property_matches_the_design_'
      'wording', (WidgetTester tester) async {
    final Random random = seededRandom(1220808);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: buildNewWorkflowNavigation()),
      );

      expect(find.text('New workflow'), findsOneWidget);
      expect(find.text('What should this workflow do?'), findsOneWidget);
      expect(
        find.text(
          'An agent fills in everything else: the name, where it is '
          "available, the diagram and every agent's settings. You check "
          'it, then sign it.',
        ),
        findsOneWidget,
      );
      expect(find.text('Draft workflow'), findsOneWidget);
      expect(find.text('Add manually'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Workflows'), findsOneWidget);
    }
  });

  testWidgets('test_new_workflow_screen_build_property_back_and_cancel_close_'
      'only_the_form', (WidgetTester tester) async {
    final Random random = seededRandom(1220809);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = buildNewWorkflowNavigation();
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: navigation),
      );

      if (random.nextBool()) {
        await tapVisible(tester, find.byType(BackLinkButton));
        await tester.pump();
      } else {
        await tapNewWorkflowLabel(tester, 'Cancel');
      }

      expect(navigation.routes, const <AppRoute>[newWorkflowFormSectionRoute]);
    }
  });

  testWidgets('test_new_workflow_screen_build_prompt_property_the_field_'
      'grows_from_four_to_eight_lines', (WidgetTester tester) async {
    final Random random = seededRandom(1220810);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: buildNewWorkflowNavigation()),
      );

      final TextField field = tester.widget<TextField>(
        findWorkflowDescription(),
      );
      expect(field.minLines, 4);
      expect(field.maxLines, 8);
    }
  });

  testWidgets('test_new_workflow_screen_build_prompt_property_never_wider_'
      'than_the_prompt_measure', (WidgetTester tester) async {
    final Random random = seededRandom(1220811);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: buildNewWorkflowNavigation()),
      );

      final Rect field = tester.getRect(findWorkflowDescription());
      expect(field.width, lessThanOrEqualTo(promptMaximumWidth));
      expect(field.right, lessThanOrEqualTo(width));
      expect(field.left, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('test_new_workflow_screen_build_prompt_property_add_manually_'
      'opens_the_builder_once', (WidgetTester tester) async {
    final Random random = seededRandom(1220812);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = buildNewWorkflowNavigation();
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: navigation),
      );
      final int taps = 1 + random.nextInt(3);

      for (int tap = 0; tap < taps; tap += 1) {
        await tapNewWorkflowLabel(tester, addManuallyLabel);
        await tester.pump(betweenNewWorkflowTaps);
      }

      expect(navigation.routes, const <AppRoute>[
        newWorkflowFormSectionRoute,
        NewWorkflowRoute(),
        ManualWorkflowRoute(),
      ]);
    }
  });

  testWidgets('test_new_workflow_screen_start_drafting_property_blank_words_'
      'open_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1220813);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = buildNewWorkflowNavigation();
      final List<AppRoute> routesBefore = navigation.routes;
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: navigation),
      );
      await tester.enterText(
        findWorkflowDescription(),
        randomDescriptionWhiteSpace(random),
      );

      await tapNewWorkflowLabel(tester, draftWorkflowLabel);

      expect(navigation.routes, routesBefore);
      expect(find.text(blankWorkflowDescriptionProblem), findsOneWidget);
      await tester.enterText(findWorkflowDescription(), 'x');
      await tester.pump();
      expect(find.text(blankWorkflowDescriptionProblem), findsNothing);
    }
  });

  testWidgets('test_new_workflow_screen_start_drafting_property_drafts_the_'
      'trimmed_words', (WidgetTester tester) async {
    final Random random = seededRandom(1220814);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = buildNewWorkflowNavigation();
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: navigation),
      );
      final String words = 'Ship ${randomWordPhrase(random)} $i';
      final String leading = randomDescriptionWhiteSpace(random);
      final String trailing = randomDescriptionWhiteSpace(random);
      final String typed = '$leading$words$trailing';
      await tester.enterText(findWorkflowDescription(), typed);

      await tapNewWorkflowLabel(tester, draftWorkflowLabel);

      final AppRoute shown = navigation.currentRoute;
      expect(shown, isA<WorkflowDraftingRoute>());
      expect(
        (shown as WorkflowDraftingRoute).draft.description,
        trimUnicodeWhiteSpace(typed),
      );
      expect(navigation.routes.length, 3);
    }
  });

  testWidgets('test_new_workflow_screen_start_drafting_property_double_taps_'
      'open_one_draft', (WidgetTester tester) async {
    final Random random = seededRandom(1220815);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppNavigation navigation = buildNewWorkflowNavigation();
      await pumpNewWorkflowScreen(
        tester,
        random,
        NewWorkflowScreen(navigation: navigation),
      );
      await tester.enterText(findWorkflowDescription(), 'Draft it $i');

      await tapNewWorkflowLabel(tester, draftWorkflowLabel);
      await tester.pump(betweenNewWorkflowTaps);
      await tapNewWorkflowLabel(tester, draftWorkflowLabel);

      expect(navigation.routes.length, 3);
      expect(navigation.currentRoute, isA<WorkflowDraftingRoute>());
    }
  });
}
