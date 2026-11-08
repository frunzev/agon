import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/random_inputs.dart';
import '../../node_backed/support/simulated_work_node.dart';

const String contractDeviceText = 'contract-device';
const String _commandField = 'command';
const String _statusField = 'status';
const String _numberField = 'number';
const String _taskIdField = 'task_id';
const List<String> _finishedRunStatuses = <String>[
  'done',
  'failed',
  'cancelled',
];
const List<String> _retryableRunStatuses = <String>['failed', 'cancelled'];
const List<String> _anyRunStatuses = <String>[
  'queued',
  'running',
  'waiting_for_approval',
  'done',
  'failed',
  'cancelled',
];
const int _largestTaskCount = 5;
const int _largestRunsPerTask = 3;

bool _isFinished(WireRecord run) {
  return _finishedRunStatuses.contains(run[_statusField]);
}

final class RustLikeWorkNode {
  final SimulatedWorkNode work = SimulatedWorkNode(
    thisDeviceId: contractDeviceText,
  );

  String answer(String inputJson) {
    final WireRecord command = jsonDecode(inputJson) as WireRecord;
    final String? refusal = _findRustRefusal(command);
    if (refusal != null) {
      return encodeErrorReply(refusal);
    }
    return work.answer(inputJson);
  }

  List<WireRecord> listRunsOf(Object? taskId) {
    return <WireRecord>[
      for (final WireRecord run in work.runs.values)
        if (run[_taskIdField] == taskId) run,
    ];
  }

  String? _findRustRefusal(WireRecord command) {
    final Object? name = command[_commandField];
    if (name == 'create_task' || name == 'update_task') {
      final WireRecord task = command['task']! as WireRecord;
      final String title = task['title']! as String;
      if (trimUnicodeWhiteSpace(title).isEmpty) {
        return 'the title cannot be empty';
      }
    }
    if (name == 'start_task') {
      return _refuseActiveRun(command[_taskIdField]);
    }
    if (name == 'delete_task') {
      return _refuseActiveRun(command[_taskIdField]);
    }
    if (name == 'cancel_run') {
      final WireRecord? run = work.runs[command['run_id']];
      if (run != null && _isFinished(run)) {
        return 'the run has already finished';
      }
    }
    if (name == 'retry_run') {
      return _refuseRetry(work.runs[command['run_id']]);
    }
    return null;
  }

  String? _refuseActiveRun(Object? taskId) {
    for (final WireRecord run in listRunsOf(taskId)) {
      if (!_isFinished(run)) {
        return 'the task is already running';
      }
    }
    return null;
  }

  String? _refuseRetry(WireRecord? run) {
    if (run == null) {
      return null;
    }
    if (!_retryableRunStatuses.contains(run[_statusField])) {
      return 'only a failed or cancelled run can be retried';
    }
    final String? activeRefusal = _refuseActiveRun(run[_taskIdField]);
    if (activeRefusal != null) {
      return activeRefusal;
    }
    int latestNumber = 0;
    for (final WireRecord sibling in listRunsOf(run[_taskIdField])) {
      latestNumber = max(latestNumber, sibling[_numberField]! as int);
    }
    if (run[_numberField] != latestNumber) {
      return 'only the latest run of the task can be retried';
    }
    return null;
  }
}

void _seedRuns(Random random, RustLikeWorkNode node, String taskId) {
  final int runCount = random.nextInt(_largestRunsPerTask + 1);
  for (int number = 1; number <= runCount; number += 1) {
    final String runId = node.work.addRunFromElsewhere(random, taskId);
    final WireRecord run = node.work.runs[runId]!;
    final bool isLatest = number == runCount;
    run[_numberField] = number;
    run['steps'] = <Object?>[];
    run[_statusField] = isLatest
        ? pickOne(random, _anyRunStatuses)
        : pickOne(random, _finishedRunStatuses);
  }
  final List<WireRecord> runs = node.listRunsOf(taskId);
  if (runs.isNotEmpty) {
    node.work.changeRunFromElsewhere(random, runs.last['id']! as String);
  }
}

RustLikeWorkNode buildRandomWorkNode(Random random) {
  final RustLikeWorkNode node = RustLikeWorkNode();
  final int taskCount = random.nextInt(_largestTaskCount + 1);
  for (int i = 0; i < taskCount; i += 1) {
    final String taskId = node.work.addTaskFromElsewhere(random);
    final WireRecord task = node.work.tasks[taskId]!;
    task['schedule'] = null;
    task['doer'] = <String, Object?>{'kind': 'one_agent', 'agent': 'codex'};
    _seedRuns(random, node, taskId);
  }
  return node;
}
