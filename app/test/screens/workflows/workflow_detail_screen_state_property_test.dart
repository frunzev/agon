import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/workflows.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../support/held_save_repositories.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import 'random_workflow_records.dart';
import 'workflow_detail_scene.dart';

Future<DetailPage> _openStartablePage(
  WidgetTester tester,
  Random random, {
  required SaveHold? taskHold,
  required PlannedRefusal? taskRefusal,
}) {
  return openDetailPage(
    tester,
    random: random,
    workflow: randomSignableWorkflow(random),
    change: null,
    taskHold: taskHold,
    taskRefusal: taskRefusal,
  );
}

bool _isStartNowEnabled(WidgetTester tester) {
  final AppButton button = tester.widget<AppButton>(
    find.widgetWithText(AppButton, startNowLabel),
  );
  return button.onPressed != null;
}

Future<void> _refuseStart(
  WidgetTester tester,
  PlannedRefusal refusal,
  int round,
) async {
  refusal.problem = PeopleFacingRefusal('No start $round');
  await tapDetailButton(tester, startNowLabel);
  await tapButtonLabelled(tester, refusalCloseLabel);
  refusal.problem = null;
}

void main() {
  test('test_workflow_detail_screen_create_state_property_each_call_makes_'
      'a_fresh_state', () {
    final Random random = seededRandom(1221401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final WorkflowDetailScreen screen = buildDetailScreen(
        workflowId: randomStoredWorkflow(random, index: i).id,
        dependencies: dependencies,
        navigation: AppNavigation(initialRoute: detailWorkflowsRoute),
      );

      final State<WorkflowDetailScreen> first = screen.createState();
      expect(identical(first, screen.createState()), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_workflow_detail_screen_create_state_property_the_'
      'mounted_state_shows_its_workflow', (WidgetTester tester) async {
    final Random random = seededRandom(1221402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);

      final State<WorkflowDetailScreen> state = tester.state(
        find.byType(WorkflowDetailScreen),
      );
      expect(state.mounted, isTrue);
      expect(state.widget.workflowId, page.workflow.id);
    }
  });

  testWidgets('test_workflow_detail_screen_create_state_property_a_signed_'
      'workflow_starts_startable', (WidgetTester tester) async {
    final Random random = seededRandom(1221403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openStartablePage(
        tester,
        random,
        taskHold: null,
        taskRefusal: null,
      );

      expect(_isStartNowEnabled(tester), isTrue);
    }
  });

  testWidgets('test_workflow_detail_screen_stop_starting_property_start_now_'
      'is_off_while_starting', (WidgetTester tester) async {
    final Random random = seededRandom(1221404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SaveHold taskHold = SaveHold();
      await _openStartablePage(
        tester,
        random,
        taskHold: taskHold,
        taskRefusal: null,
      );
      final Completer<void> hold = Completer<void>();
      taskHold.hold = hold;

      await tapDetailButton(tester, startNowLabel);

      expect(_isStartNowEnabled(tester), isFalse);
      hold.complete();
      await tester.pump();
      await tester.pump();
    }
  });

  testWidgets('test_workflow_detail_screen_stop_starting_property_a_refusal_'
      'turns_start_now_back_on', (WidgetTester tester) async {
    final Random random = seededRandom(1221405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PlannedRefusal refusal = PlannedRefusal();
      final DetailPage page = await _openStartablePage(
        tester,
        random,
        taskHold: null,
        taskRefusal: refusal,
      );

      await _refuseStart(tester, refusal, i);

      expect(_isStartNowEnabled(tester), isTrue);
      expect(page.navigation.currentRoute, isA<WorkflowDetailRoute>());
      expect(page.tasks.listTasks(), isEmpty);
    }
  });

  testWidgets('test_workflow_detail_screen_stop_starting_property_a_retry_'
      'after_a_refusal_starts_one_task', (WidgetTester tester) async {
    final Random random = seededRandom(1221406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PlannedRefusal refusal = PlannedRefusal();
      final DetailPage page = await _openStartablePage(
        tester,
        random,
        taskHold: null,
        taskRefusal: refusal,
      );
      await _refuseStart(tester, refusal, i);

      await tapDetailButton(tester, startNowLabel);

      expect(page.tasks.listTasks().length, 1);
      expect(page.navigation.currentRoute, isA<TaskRunRoute>());
      expect(page.navigation.routes.first, detailWorkflowsRoute);
    }
  });
}
