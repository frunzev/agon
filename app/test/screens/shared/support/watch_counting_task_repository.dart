import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

final class WatchCountingTaskRepository extends ChangeNotifier
    implements TaskRepository {
  final Map<RunId, int> watcherCounts = <RunId, int>{};
  int watchCalls = 0;
  int stopCalls = 0;

  int countWatchers(RunId runId) => watcherCounts[runId] ?? 0;

  int countAllWatchers() {
    int total = 0;
    for (final int watchers in watcherCounts.values) {
      total += watchers;
    }
    return total;
  }

  @override
  void watchRun(RunId runId) {
    watchCalls += 1;
    watcherCounts[runId] = countWatchers(runId) + 1;
  }

  @override
  void stopWatchingRun(RunId runId) {
    stopCalls += 1;
    watcherCounts[runId] = countWatchers(runId) - 1;
  }

  @override
  List<Task> listTasks() => throw UnimplementedError();

  @override
  Task findTask(TaskId taskId) => throw UnimplementedError();

  @override
  List<Run> listRuns(TaskId taskId) => throw UnimplementedError();

  @override
  Run findRun(RunId runId) => throw UnimplementedError();

  @override
  Future<Task> createTask(TaskDraft draft) => throw UnimplementedError();

  @override
  Future<Task> updateTask(TaskId taskId, TaskDraft draft) {
    throw UnimplementedError();
  }

  @override
  Future<Run> startTask(TaskId taskId) => throw UnimplementedError();

  @override
  Future<Run> cancelRun(RunId runId) => throw UnimplementedError();

  @override
  Future<Run> retryRun(RunId runId) => throw UnimplementedError();

  @override
  Future<void> deleteTask(TaskId taskId) => throw UnimplementedError();
}
