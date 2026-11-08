import 'dart:convert';
import 'dart:io';

import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/node_backed/mapping/task_mapping.dart';

const String _fixtureFolder =
    '../rust/crates/orchestration-core/tests/fixtures/';
const String _summaryCasesFile = 'task_summary_cases.json';
const String _branchCasesFile = 'task_branch_cases.json';

typedef _JsonObject = Map<String, Object?>;

final class SharedSummaryCase {
  const SharedSummaryCase({required this.statuses, required this.text});

  final List<TaskStatus> statuses;
  final String text;
}

final class SharedBranchCase {
  const SharedBranchCase({
    required this.title,
    required this.taskId,
    required this.runNumber,
    required this.branch,
  });

  final String title;
  final TaskId taskId;
  final int? runNumber;
  final String branch;
}

List<_JsonObject> _readCaseList(String fileName) {
  final String text = File('$_fixtureFolder$fileName').readAsStringSync();
  final Object? entries = jsonDecode(text);
  if (entries is! List<Object?>) {
    throw FormatException('the shared table $fileName is not a list');
  }

  final List<_JsonObject> cases = <_JsonObject>[];
  for (final Object? entry in entries) {
    if (entry is! _JsonObject) {
      throw FormatException('a shared case is not an object: $entry');
    }
    cases.add(entry);
  }
  return cases;
}

T _readField<T>(_JsonObject entry, String field) {
  final Object? fieldValue = entry[field];
  if (fieldValue is! T) {
    throw FormatException('the shared case field $field is wrong', entry);
  }
  return fieldValue;
}

List<TaskStatus> _readStatuses(_JsonObject entry) {
  final List<Object?> names = _readField<List<Object?>>(entry, 'statuses');
  final List<TaskStatus> statuses = <TaskStatus>[];
  for (final Object? name in names) {
    statuses.add(mapTaskStatusFromNode(node.TaskStatus.decode(name)));
  }
  return statuses;
}

List<SharedSummaryCase> readSharedSummaryCases() {
  return <SharedSummaryCase>[
    for (final _JsonObject entry in _readCaseList(_summaryCasesFile))
      SharedSummaryCase(
        statuses: _readStatuses(entry),
        text: _readField<String>(entry, 'text'),
      ),
  ];
}

List<SharedBranchCase> readSharedBranchCases() {
  return <SharedBranchCase>[
    for (final _JsonObject entry in _readCaseList(_branchCasesFile))
      SharedBranchCase(
        title: _readField<String>(entry, 'title'),
        taskId: TaskId(_readField<String>(entry, 'task_id')),
        runNumber: _readField<int?>(entry, 'run_number'),
        branch: _readField<String>(entry, 'branch'),
      ),
  ];
}
