import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/live_run_values.dart'
    as node;
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/person_step.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/screens/shared/status_labels.dart';
import 'package:agent_orchestration/screens/task_run/task_run_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/lists/list_row_data.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../data/node_backed/mapping/support/live_run_event_sequences.dart';
import '../../data/node_backed/mapping/support/live_run_views.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'support/run_page_retry_harness.dart';
import 'support/run_steps_section_scenes.dart';
import 'support/task_run_screen_scenes.dart';

const int _mostLiveViews = 6;
const Duration _betweenViews = Duration(seconds: 3);

final class _LiveTaskRepository extends ChangeNotifier
    implements TaskRepository {
  _LiveTaskRepository({required this.stored, required Run liveRun})
    : _liveRun = liveRun;

  final FakeTaskRepository stored;
  Run _liveRun;

  Run get liveRun => _liveRun;

  void applyServerView(node.WatchView view, DateTime at) {
    _liveRun = applyLiveRunView(run: _liveRun, view: view, at: at);
    notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    stored.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    stored.removeListener(listener);
  }

  @override
  List<Task> listTasks() => stored.listTasks();

  @override
  Task findTask(TaskId taskId) => stored.findTask(taskId);

  @override
  List<Run> listRuns(TaskId taskId) {
    return <Run>[
      for (final Run run in stored.listRuns(taskId))
        if (run.id == _liveRun.id) _liveRun else run,
    ];
  }

  @override
  Run findRun(RunId runId) {
    if (runId == _liveRun.id) {
      return _liveRun;
    }
    return stored.findRun(runId);
  }

  @override
  Future<Task> createTask(TaskDraft draft) => stored.createTask(draft);

  @override
  Future<Task> updateTask(TaskId taskId, TaskDraft draft) {
    return stored.updateTask(taskId, draft);
  }

  @override
  Future<Run> startTask(TaskId taskId) => stored.startTask(taskId);

  @override
  Future<Run> cancelRun(RunId runId) => stored.cancelRun(runId);

  @override
  Future<Run> retryRun(RunId runId) => stored.retryRun(runId);

  @override
  Future<void> deleteTask(TaskId taskId) => stored.deleteTask(taskId);

  @override
  void watchRun(RunId runId) => stored.watchRun(runId);

  @override
  void stopWatchingRun(RunId runId) => stored.stopWatchingRun(runId);
}

typedef _LiveScene = ({
  AppDependencies dependencies,
  _LiveTaskRepository tasks,
});

_LiveScene _randomLiveScene(Random random) {
  final Run run = randomRunOfTask(
    random,
    task: pickOne(random, listGalleryWork()),
  );
  final RunPageScene scene = buildRunPageScene(
    run: run,
    openSteps: const <OpenPersonStep>[],
    approvals: const <ApprovalRequest>[],
  );
  final _LiveTaskRepository tasks = _LiveTaskRepository(
    stored: scene.tasks,
    liveRun: run,
  );
  return (
    dependencies: replaceRepositories(
      scene.dependencies,
      taskRepository: tasks,
    ),
    tasks: tasks,
  );
}

node.WatchView _randomServerView(Random random, Run run, int position) {
  return buildLiveView(<node.RunEvent>[
    randomServerEvent(random, run, position),
  ]);
}

List<String> _readShownStatuses(WidgetTester tester) {
  return <String>[
    for (final ListRowData row in readStepRows(tester))
      (row.end! as StatusLabel).text,
  ];
}

List<String> _describeStatuses(Run run) {
  return <String>[
    for (final RunStep step in run.steps)
      buildStepStatusLabel(step.status).text,
  ];
}

void main() {
  testWidgets(
    'test_task_run_screen_build_property_live_views_mirror_the_run',
    (WidgetTester tester) async {
      final Random random = seededRandom(115901);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _LiveScene scene = _randomLiveScene(random);
        await openRunPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
          runId: scene.tasks.liveRun.id,
        );

        DateTime receivedAt = galleryNow;
        final int views = 1 + random.nextInt(_mostLiveViews);
        for (int position = 0; position < views; position += 1) {
          receivedAt = receivedAt.add(_betweenViews);
          scene.tasks.applyServerView(
            _randomServerView(random, scene.tasks.liveRun, position),
            receivedAt,
          );
          await tester.pump();

          expect(
            _readShownStatuses(tester),
            _describeStatuses(scene.tasks.liveRun),
          );
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'test_task_run_screen_build_property_closed_page_ignores_views',
    (WidgetTester tester) async {
      final Random random = seededRandom(115902);

      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final _LiveScene scene = _randomLiveScene(random);
        final AppNavigation navigation = await openRunPage(
          tester,
          random: random,
          dependencies: scene.dependencies,
          runId: scene.tasks.liveRun.id,
        );
        navigation.openSection(const SectionRoute(AppSection.tasks));
        await pumpFrames(tester);

        scene.tasks.applyServerView(
          _randomServerView(random, scene.tasks.liveRun, 0),
          galleryNow.add(_betweenViews),
        );
        await tester.pump();

        expect(find.byType(TaskRunScreen), findsNothing);
        expect(
          scene.tasks.stored.isWatchingRun(scene.tasks.liveRun.id),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('test_task_run_screen_build_property_reopening_shows_latest', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(115903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _LiveScene scene = _randomLiveScene(random);
      final RunId runId = scene.tasks.liveRun.id;
      final AppNavigation navigation = await openRunPage(
        tester,
        random: random,
        dependencies: scene.dependencies,
        runId: runId,
      );
      navigation.openSection(const SectionRoute(AppSection.tasks));
      await pumpFrames(tester);
      scene.tasks.applyServerView(
        _randomServerView(random, scene.tasks.liveRun, 0),
        galleryNow.add(_betweenViews),
      );

      navigation.openRoute(TaskRunRoute(runId));
      await pumpFrames(tester);

      expect(
        _readShownStatuses(tester),
        _describeStatuses(scene.tasks.liveRun),
      );
      expect(scene.tasks.stored.isWatchingRun(runId), isTrue);
    }
  });
}
