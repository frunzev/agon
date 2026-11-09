import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/data/repository/rule_repository.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';

typedef HeldSave<Result> = Future<Result> Function();

final class SaveHold {
  Completer<void>? hold;
  int saveCount = 0;

  Future<Result> waitThenSave<Result>(HeldSave<Result> save) async {
    saveCount += 1;
    final Completer<void>? currentHold = hold;
    if (currentHold != null) {
      await currentHold.future;
    }
    return save();
  }
}

final class HeldRuleRepository implements RuleRepository {
  HeldRuleRepository({required this.stored, required this.saveHold});

  final RuleRepository stored;
  final SaveHold saveHold;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Rule> listRules() => stored.listRules();

  @override
  Rule findRule(RuleId ruleId) => stored.findRule(ruleId);

  @override
  Future<Rule> createRule(RuleDraft draft) {
    return saveHold.waitThenSave(() => stored.createRule(draft));
  }

  @override
  Future<Rule> updateRule(RuleId ruleId, RuleDraft draft) {
    return saveHold.waitThenSave(() => stored.updateRule(ruleId, draft));
  }

  @override
  Future<Rule> turnRuleOn(RuleId ruleId) => stored.turnRuleOn(ruleId);

  @override
  Future<Rule> turnRuleOff(RuleId ruleId) => stored.turnRuleOff(ruleId);

  @override
  Future<void> deleteRule(RuleId ruleId) => stored.deleteRule(ruleId);
}

final class HeldJobRepository implements JobRepository {
  HeldJobRepository({required this.stored, required this.saveHold});

  final JobRepository stored;
  final SaveHold saveHold;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Task> listJobs() => stored.listJobs();

  @override
  Task findJob(TaskId jobId) => stored.findJob(jobId);

  @override
  Future<Task> createJob(JobDraft draft) {
    return saveHold.waitThenSave(() => stored.createJob(draft));
  }

  @override
  Future<Task> updateJob(TaskId jobId, JobDraft draft) {
    return saveHold.waitThenSave(() => stored.updateJob(jobId, draft));
  }

  @override
  Future<void> deleteJob(TaskId jobId) => stored.deleteJob(jobId);
}

final class HeldTaskRepository implements TaskRepository {
  HeldTaskRepository({required this.stored, required this.saveHold});

  final TaskRepository stored;
  final SaveHold saveHold;

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
  Future<Task> createTask(TaskDraft draft) {
    return saveHold.waitThenSave(() => stored.createTask(draft));
  }

  @override
  Future<Task> updateTask(TaskId taskId, TaskDraft draft) {
    return saveHold.waitThenSave(() => stored.updateTask(taskId, draft));
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
