import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/screens/workflows/workflow_quick_start.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/held_save_repositories.dart';
import 'random_workflow_records.dart';
import 'workflow_detail_scene.dart';

const String _keepLabel = 'Keep workflow';
const String _deleteLabel = 'Delete workflow';
const Duration _betweenTwoTaps = Duration(milliseconds: 80);
const List<AppRoute> _placesToMoveOn = <AppRoute>[
  SectionRoute(AppSection.devices),
  NewWorkflowRoute(),
  NewProjectRoute(),
];

Future<DetailPage> _openSignedPage(
  WidgetTester tester,
  Random random, {
  required SaveHold? taskHold,
}) {
  return openDetailPage(
    tester,
    random: random,
    workflow: randomSignableWorkflow(random),
    change: null,
    taskHold: taskHold,
    taskRefusal: null,
  );
}

Future<void> _useInATask(DetailPage page) async {
  final List<Project> projects = page.dependencies.projectRepository
      .listProjects(
        page.dependencies.workspaceRepository.currentWorkspace().id,
      );
  await page.tasks.createTask(
    buildQuickStartTask(workflow: page.workflow, projectId: projects.first.id),
  );
}

void _moveOn(DetailPage page, AppRoute place) {
  if (place is SectionRoute) {
    page.navigation.openSection(place);
  } else {
    page.navigation.openRoute(place);
  }
}

void main() {
  testWidgets('test_workflow_detail_screen_review_deletion_property_keeping_'
      'changes_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1220501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);
      final List<AppRoute> routesBefore = page.navigation.routes;

      await tapDetailButton(tester, 'Delete');
      expect(find.text('Delete ${page.workflow.name}?'), findsOneWidget);
      await tapDetailButton(tester, _keepLabel);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, routesBefore);
      expect(
        page.workflows.findWorkflow(page.workflow.id).name,
        page.workflow.name,
      );
    }
  });

  testWidgets('test_workflow_detail_screen_review_deletion_property_deleting_'
      'removes_it_and_returns_to_workflows', (WidgetTester tester) async {
    final Random random = seededRandom(1220502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);

      await tapDetailButton(tester, 'Delete');
      await tapDetailButton(tester, _deleteLabel);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, const <AppRoute>[detailWorkflowsRoute]);
      expect(
        page.workflows.listWorkflows().map((Workflow kept) => kept.id),
        isNot(contains(page.workflow.id)),
      );
    }
  });

  testWidgets('test_workflow_detail_screen_review_deletion_property_a_used_'
      'workflow_stays_and_says_why', (WidgetTester tester) async {
    final Random random = seededRandom(1220503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await _openSignedPage(
        tester,
        random,
        taskHold: null,
      );
      await _useInATask(page);
      await pumpFrames(tester);
      final List<AppRoute> routesBefore = page.navigation.routes;

      await tapDetailButton(tester, 'Delete');
      await tapDetailButton(tester, _deleteLabel);

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('is still used by a task or job'),
        findsOneWidget,
      );
      expect(page.navigation.routes, routesBefore);
      expect(
        page.workflows.findWorkflow(page.workflow.id).id,
        page.workflow.id,
      );
      await tapDetailButton(tester, _keepLabel);
      expect(find.textContaining('is still used'), findsNothing);
    }
  });

  testWidgets('test_workflow_detail_screen_start_now_property_double_taps_'
      'start_one_task', (WidgetTester tester) async {
    final Random random = seededRandom(1220504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SaveHold taskHold = SaveHold();
      final DetailPage page = await _openSignedPage(
        tester,
        random,
        taskHold: taskHold,
      );
      final Completer<void> hold = Completer<void>();
      taskHold.hold = hold;

      final Finder startNow = find.widgetWithText(AppButton, startNowLabel);
      await tester.ensureVisible(startNow);
      await tester.tap(startNow);
      await tester.pump(_betweenTwoTaps);
      await tester.tap(startNow, warnIfMissed: false);
      await tester.pump(_betweenTwoTaps);
      hold.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(taskHold.saveCount, 1);
      expect(page.tasks.listTasks().length, 1);
      expect(page.navigation.currentRoute, isA<TaskRunRoute>());
    }
  });

  testWidgets('test_workflow_detail_screen_start_now_property_a_person_who_'
      'moved_on_stays_where_they_went', (WidgetTester tester) async {
    final Random random = seededRandom(1220505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SaveHold taskHold = SaveHold();
      final DetailPage page = await _openSignedPage(
        tester,
        random,
        taskHold: taskHold,
      );
      final Completer<void> hold = Completer<void>();
      taskHold.hold = hold;

      await tapDetailButton(tester, startNowLabel);
      _moveOn(page, pickOne(random, _placesToMoveOn));
      await pumpFrames(tester);
      final List<AppRoute> wentTo = page.navigation.routes;
      hold.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, wentTo);
      expect(page.tasks.listTasks().length, 1);
    }
  });

  testWidgets('test_workflow_detail_screen_start_now_property_the_run_does_'
      'this_workflow_in_the_first_project', (WidgetTester tester) async {
    final Random random = seededRandom(1220506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await _openSignedPage(
        tester,
        random,
        taskHold: null,
      );
      final WorkspaceId workspaceId = page.dependencies.workspaceRepository
          .currentWorkspace()
          .id;
      final Project firstProject = page.dependencies.projectRepository
          .listProjects(workspaceId)
          .first;

      await tapDetailButton(tester, startNowLabel);

      final AppRoute shown = page.navigation.currentRoute;
      expect(shown, isA<TaskRunRoute>());
      final Run run = page.tasks.findRun((shown as TaskRunRoute).runId);
      final Task task = page.tasks.findTask(run.taskId);
      expect(task.doer, WorkflowDoer(page.workflow.id));
      expect(task.projectId, firstProject.id);
      expect(task.title, 'Run ${page.workflow.name}');
    }
  });

  testWidgets('test_workflow_detail_screen_build_page_property_deleted_'
      'elsewhere_closes_the_page', (WidgetTester tester) async {
    final Random random = seededRandom(1220507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DetailPage page = await openRandomDetailPage(tester, random);

      await page.workflows.deleteWorkflow(page.workflow.id);
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(
        page.navigation.routes,
        isNot(contains(WorkflowDetailRoute(page.workflow.id))),
      );
    }
  });
}
