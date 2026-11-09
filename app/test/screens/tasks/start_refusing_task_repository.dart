import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

final class StartRefusingTaskRepository implements TaskRepository {
  StartRefusingTaskRepository(this.stored);

  final TaskRepository stored;
  final List<Task> createdTasks = <Task>[];
  final List<TaskId> startAttempts = <TaskId>[];
  Object? startProblem;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Task> listTasks() => stored.listTasks();

  @override
  Task findTask(TaskId taskId) => stored.findTask(taskId);

  @override
  List<Run> listRuns(TaskId taskId) => stored.listRuns(taskId);

  @override
  Run findRun(RunId runId) => stored.findRun(runId);

  @override
  Future<Task> createTask(TaskDraft draft) async {
    final Task created = await stored.createTask(draft);
    createdTasks.add(created);
    return created;
  }

  @override
  Future<Task> updateTask(TaskId taskId, TaskDraft draft) {
    return stored.updateTask(taskId, draft);
  }

  @override
  Future<Run> startTask(TaskId taskId) {
    startAttempts.add(taskId);
    final Object? problem = startProblem;
    if (problem != null) {
      return Future<Run>.error(problem);
    }
    return stored.startTask(taskId);
  }

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
