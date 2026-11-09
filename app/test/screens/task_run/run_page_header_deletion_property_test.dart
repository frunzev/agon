import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_lifecycle.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/run_page_header_pages.dart';
import 'support/run_page_retry_harness.dart';

const String _deleteLabel = 'Delete';
const int _mostAttempts = 40;

typedef _DeletionLabels = ({String keep, String delete});

RunPageCase _randomFinishedRunPage(Random random) {
  for (int attempt = 0; attempt < _mostAttempts; attempt += 1) {
    final RunPageCase page = randomRunPageCase(random);
    if (!isRunActive(page.run)) {
      return page;
    }
  }
  throw StateError('No finished run came up');
}

_DeletionLabels _labelsFor(Task task) {
  if (task.schedule == null) {
    return (keep: 'Keep task', delete: 'Delete task');
  }
  return (keep: 'Keep job', delete: 'Delete job');
}

Future<void> _openDeletion(WidgetTester tester) async {
  await tapAppButton(tester, _deleteLabel);
  await pumpFrames(tester);
}

Future<void> _choose(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await pumpFrames(tester);
  await pumpFrames(tester);
}

void _expectTaskStored(TaskRepository repository, Task task) {
  expect(repository.findTask(task.id).id, task.id);
}

void _expectTaskGone(TaskRepository repository, Task task) {
  expect(() => repository.findTask(task.id), throwsA(isA<RecordNotFound>()));
}

void main() {
  testWidgets('test_build_delete_action_property_only_finished_runs_in_'
      'the_main_window', (WidgetTester tester) async {
    final Random random = seededRandom(1141601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = randomRunPageCase(random);
      final bool isMainWindow = random.nextBool();

      if (isMainWindow) {
        await openRunPageInMainWindow(
          tester,
          random: random,
          page: page,
          routesBelow: randomRoutesBelowRun(random),
          opener: null,
        );
      } else {
        await openRunPageInRunWindow(tester, page: page);
      }

      final bool offersDelete = isMainWindow && !isRunActive(page.run);
      expect(
        findAppButton(_deleteLabel),
        offersDelete ? findsOneWidget : findsNothing,
      );
    }
  });

  testWidgets('test_build_delete_action_property_is_a_plain_secondary_'
      'button', (WidgetTester tester) async {
    final Random random = seededRandom(1141602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openRunPageInMainWindow(
        tester,
        random: random,
        page: _randomFinishedRunPage(random),
        routesBelow: randomRoutesBelowRun(random),
        opener: null,
      );

      final AppButton delete = tester.widget(findAppButton(_deleteLabel));
      expect(delete.tone, ButtonTone.secondary);
      expect(delete.icon, isNull);
      expect(delete.onPressed, isNotNull);
    }
  });

  testWidgets('test_build_delete_action_property_asks_with_the_task_kind', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1141603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = _randomFinishedRunPage(random);
      final Task task = page.task;
      await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: randomRoutesBelowRun(random),
        opener: null,
      );

      await _openDeletion(tester);

      final _DeletionLabels labels = _labelsFor(task);
      expect(find.text('Delete "${task.title}"?'), findsOneWidget);
      expect(find.text(labels.keep), findsOneWidget);
      expect(find.text(labels.delete), findsOneWidget);
      await _choose(tester, labels.keep);
    }
  });

  testWidgets('test_run_page_header_review_deletion_property_keeping_'
      'changes_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(1141604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = _randomFinishedRunPage(random);
      final Task task = page.task;
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: randomRoutesBelowRun(random),
        opener: null,
      );
      final List<AppRoute> routesBefore = navigation.routes;

      await _openDeletion(tester);
      await _choose(tester, _labelsFor(task).keep);

      expect(tester.takeException(), isNull);
      _expectTaskStored(page.dependencies.taskRepository, task);
      expect(navigation.routes, routesBefore);
    }
  });

  testWidgets('test_run_page_header_review_deletion_property_deleting_'
      'lands_on_tasks', (WidgetTester tester) async {
    final Random random = seededRandom(1141605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = _randomFinishedRunPage(random);
      final List<AppRoute> below = randomRoutesBelowRun(random);
      final AppNavigation navigation = await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: below,
        opener: null,
      );

      await _openDeletion(tester);
      await _choose(tester, _labelsFor(page.task).delete);

      expect(tester.takeException(), isNull);
      expect(navigation.currentRoute, tasksSectionRoute);
      expect(navigation.routes.whereType<RunPageRoute>(), isEmpty);
    }
  });

  testWidgets('test_run_page_header_review_deletion_property_runs_go_with_'
      'the_task', (WidgetTester tester) async {
    final Random random = seededRandom(1141606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RunPageCase page = _randomFinishedRunPage(random);
      final Task task = page.task;
      final TaskRepository repository = page.dependencies.taskRepository;
      await openRunPageInMainWindow(
        tester,
        random: random,
        page: page,
        routesBelow: randomRoutesBelowRun(random),
        opener: null,
      );

      await _openDeletion(tester);
      await _choose(tester, _labelsFor(task).delete);

      _expectTaskGone(repository, task);
      expect(repository.listRuns(task.id), isEmpty);
      expect(
        () => repository.findRun(page.run.id),
        throwsA(isA<RecordNotFound>()),
      );
    }
  });
}
