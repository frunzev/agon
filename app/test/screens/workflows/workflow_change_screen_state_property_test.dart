import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import 'random_workflow_records.dart';
import 'workflow_change_scene.dart';

const List<String> _actions = <String>[discardChangeLabel, signChangeLabel];

Future<void> _refuseOnce(
  WidgetTester tester,
  PlannedRefusal refusal,
  String action,
  int round,
) async {
  refusal.problem = PeopleFacingRefusal('Refused $round');
  await tapChangeAction(tester, action);
  await pumpFrames(tester);
  await tapButtonLabelled(tester, refusalCloseLabel);
  refusal.problem = null;
}

void main() {
  test('test_workflow_change_screen_create_state_property_each_call_makes_'
      'a_fresh_state', () {
    final Random random = seededRandom(1221301);
    final AppDependencies dependencies = buildGalleryDependencies();

    for (int i = 0; i < propertyIterations; i += 1) {
      final WorkflowChangeScreen screen = WorkflowChangeScreen(
        workflowId: randomStoredWorkflow(random, index: i).id,
        workflowRepository: dependencies.workflowRepository,
        deviceRepository: dependencies.deviceRepository,
        clock: dependencies.clock,
        navigation: AppNavigation(initialRoute: changeWorkflowsRoute),
      );

      final State<WorkflowChangeScreen> first = screen.createState();
      expect(identical(first, screen.createState()), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_workflow_change_screen_create_state_property_the_'
      'mounted_state_shows_its_workflow', (WidgetTester tester) async {
    final Random random = seededRandom(1221302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SettlePage page = await openSettlePage(
        tester,
        random,
        refusal: null,
      );

      final State<WorkflowChangeScreen> state = tester.state(
        find.byType(WorkflowChangeScreen),
      );
      expect(state.mounted, isTrue);
      expect(state.widget.workflowId, page.workflow.id);
    }
  });

  testWidgets('test_workflow_change_screen_create_state_property_both_'
      'actions_start_enabled', (WidgetTester tester) async {
    final Random random = seededRandom(1221303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openSettlePage(tester, random, refusal: null);

      for (final String action in _actions) {
        expect(isChangeActionEnabled(tester, action), isTrue);
      }
    }
  });

  testWidgets('test_workflow_change_screen_stop_settling_property_actions_'
      'are_off_while_settling', (WidgetTester tester) async {
    final Random random = seededRandom(1221304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SettlePage page = await openSettlePage(
        tester,
        random,
        refusal: null,
      );
      final Completer<void> hold = Completer<void>();
      page.saveHold.hold = hold;

      await tapChangeAction(tester, pickOne(random, _actions));
      await tester.pump();

      for (final String action in _actions) {
        expect(isChangeActionEnabled(tester, action), isFalse);
      }
      hold.complete();
      await pumpFrames(tester);
    }
  });

  testWidgets('test_workflow_change_screen_stop_settling_property_a_refusal_'
      'turns_the_actions_back_on', (WidgetTester tester) async {
    final Random random = seededRandom(1221305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PlannedRefusal refusal = PlannedRefusal();
      final SettlePage page = await openSettlePage(
        tester,
        random,
        refusal: refusal,
      );

      await _refuseOnce(tester, refusal, pickOne(random, _actions), i);

      for (final String action in _actions) {
        expect(isChangeActionEnabled(tester, action), isTrue);
      }
      expect(page.navigation.currentRoute, isA<WorkflowChangeRoute>());
    }
  });

  testWidgets('test_workflow_change_screen_stop_settling_property_a_retry_'
      'after_a_refusal_settles', (WidgetTester tester) async {
    final Random random = seededRandom(1221306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PlannedRefusal refusal = PlannedRefusal();
      final SettlePage page = await openSettlePage(
        tester,
        random,
        refusal: refusal,
      );
      await _refuseOnce(tester, refusal, pickOne(random, _actions), i);
      refusal.attempts = 0;

      await tapChangeAction(tester, pickOne(random, _actions));
      await pumpFrames(tester);

      expect(refusal.attempts, 1);
      expect(page.stored.findPendingChange(page.workflow.id), isNull);
      expect(page.navigation.routes, const <AppRoute>[changeWorkflowsRoute]);
    }
  });
}
