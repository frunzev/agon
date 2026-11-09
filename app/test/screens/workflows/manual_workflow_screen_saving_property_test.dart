import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflow_builder.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'manual_workflow_scene.dart';

const int _longestName = 40;
const Duration _betweenTwoTaps = Duration(milliseconds: 80);
const String _nameCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789-';
const List<String> _hostileNames = <String>[
  '',
  ' ',
  'Release',
  'café',
  'ship it',
  'ship_it',
  'ship.it',
  'ship it',
  'шип',
];
const List<AppRoute> _placesToMoveOn = <AppRoute>[
  SectionRoute(AppSection.devices),
  NewProjectRoute(),
];

String _randomName(Random random) {
  final int choice = random.nextInt(3);
  if (choice == 0) {
    return pickOne(random, _hostileNames);
  }
  final int length = 1 + random.nextInt(_longestName + 2);
  final StringBuffer name = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    name.write(_nameCharacters[random.nextInt(_nameCharacters.length)]);
  }
  return name.toString();
}

bool _followsTheNamingRule(String name) {
  if (name.isEmpty || name.length > _longestName) {
    return false;
  }
  for (final int codeUnit in name.codeUnits) {
    if (!_nameCharacters.codeUnits.contains(codeUnit)) {
      return false;
    }
  }
  return true;
}

void main() {
  testWidgets('test_manual_workflow_screen_sign_and_save_property_saves_'
      'only_names_that_follow_the_naming_rule', (WidgetTester tester) async {
    final Random random = seededRandom(1221201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      final int countBefore = scene.stored.listWorkflows().length;
      final String name = _randomName(random);
      await nameAndFillManualWorkflow(tester, random, name);

      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump();

      final bool isValid = _followsTheNamingRule(name);
      expect(
        scene.stored.listWorkflows().length,
        isValid ? countBefore + 1 : countBefore,
        reason: '"$name"',
      );
      expect(scene.navigation.routes.length, isValid ? 1 : 3, reason: name);
    }
  });

  testWidgets('test_manual_workflow_screen_sign_and_save_property_unfinished_'
      'steps_block_saving', (WidgetTester tester) async {
    final Random random = seededRandom(1221202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      final int countBefore = scene.stored.listWorkflows().length;
      await tester.enterText(findFieldInput(workflowNameLabel), 'half-$i');
      await addRandomSteps(tester, random);

      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump();

      final WorkflowAgent first = readManualWorkflow(tester).agents.first;
      expect(find.textContaining(first.name), findsWidgets);
      expect(find.textContaining('for ${first.name}'), findsOneWidget);
      expect(scene.stored.listWorkflows().length, countBefore);
      expect(scene.navigation.routes, manualRoutes);
    }
  });

  testWidgets('test_manual_workflow_screen_sign_and_save_property_double_'
      'taps_save_once', (WidgetTester tester) async {
    final Random random = seededRandom(1221203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      final int countBefore = scene.stored.listWorkflows().length;
      await nameAndFillManualWorkflow(tester, random, 'twice-$i');
      final Completer<void> hold = Completer<void>();
      scene.saveHold.hold = hold;

      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump(_betweenTwoTaps);
      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump(_betweenTwoTaps);
      hold.complete();
      await tester.pump();
      await tester.pump();

      expect(scene.stored.listWorkflows().length, countBefore + 1);
      expect(scene.saveHold.saveCount, 2);
    }
  });

  testWidgets('test_manual_workflow_screen_store_and_sign_property_stores_'
      'the_design_signed_and_lands_on_workflows', (WidgetTester tester) async {
    final Random random = seededRandom(1221204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      await nameAndFillManualWorkflow(tester, random, 'signed-$i');
      final Workflow designed = readManualWorkflow(tester);

      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump();

      final Workflow saved = findSavedWorkflow(scene, 'signed-$i')!;
      expect(saved.signature, isNotNull);
      expect(saved.agents, designed.agents);
      expect(saved.connections, designed.connections);
      expect(scene.navigation.routes, const <AppRoute>[manualWorkflowsRoute]);
    }
  });

  testWidgets('test_manual_workflow_screen_store_and_sign_property_a_person_'
      'who_moved_on_stays_where_they_went', (WidgetTester tester) async {
    final Random random = seededRandom(1221205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: null,
      );
      await nameAndFillManualWorkflow(tester, random, 'left-$i');
      final Completer<void> hold = Completer<void>();
      scene.saveHold.hold = hold;

      await tapManualLabel(tester, signAndSaveLabel);
      final AppRoute place = pickOne(random, _placesToMoveOn);
      if (place is SectionRoute) {
        scene.navigation.openSection(place);
      } else {
        scene.navigation.openRoute(place);
      }
      final List<AppRoute> wentTo = scene.navigation.routes;
      hold.complete();
      await tester.pump();
      await tester.pump();

      expect(scene.navigation.routes, wentTo);
      expect(findSavedWorkflow(scene, 'left-$i')!.signature, isNotNull);
    }
  });

  testWidgets('test_manual_workflow_screen_store_and_sign_property_a_refused_'
      'sign_says_why_and_stays', (WidgetTester tester) async {
    final Random random = seededRandom(1221206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PlannedRefusal refusal = PlannedRefusal();
      final ManualScene scene = await openManualScene(
        tester,
        random,
        refusal: refusal,
      );
      await nameAndFillManualWorkflow(tester, random, 'refused-$i');
      final String reason = 'Signing refused $i';
      refusal.problem = PeopleFacingRefusal(reason);

      await tapManualLabel(tester, signAndSaveLabel);
      await tester.pump();

      expect(find.text(reason), findsOneWidget);
      expect(scene.navigation.routes, manualRoutes);
      expect(findSavedWorkflow(scene, 'refused-$i')!.signature, isNull);
    }
  });
}
