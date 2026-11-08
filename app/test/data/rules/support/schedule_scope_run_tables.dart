import 'dart:convert';
import 'dart:io';

import 'package:agent_orchestration/bridge/codecs/run_values.dart' as node;
import 'package:agent_orchestration/bridge/codecs/schedule_values.dart'
    as node;
import 'package:agent_orchestration/bridge/codecs/workspace_values.dart'
    as node;
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/schedule.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

typedef SharedCase = Map<String, Object?>;
typedef SharedNextRunCase = ({
  Schedule schedule,
  DateTime after,
  DateTime next,
});
typedef SharedScopeCase = ({
  Scope scope,
  WorkspaceId workspaceId,
  ProjectId projectId,
  bool includesWorkspace,
  bool includesProject,
  bool applies,
});
typedef SharedRunStatusCase = ({
  RunStatus status,
  bool isFinished,
  bool canRetry,
});
typedef SharedCancelCase = ({
  List<StepStatus> steps,
  List<StepStatus> afterCancel,
});
typedef SharedRetryCase = ({
  List<StepStatus> steps,
  List<StepStatus> afterRetry,
  RunStatus statusAfterRetry,
});

const String _fixtureFolder =
    '../rust/crates/orchestration-core/tests/fixtures/';
const String _nextRunCasesFile = 'schedule_next_run_cases.json';
const String _scopeCasesFile = 'scope_rule_cases.json';
const String _runLifecycleCasesFile = 'run_lifecycle_cases.json';
const String _defaultPatternsFile = 'default_protected_patterns.json';

List<Object?> _readSharedList(String fileName, String listName) {
  final String text = File('$_fixtureFolder$fileName').readAsStringSync();
  final Object? table = jsonDecode(text);
  if (table is! SharedCase) {
    throw FormatException('the shared table $fileName is not an object');
  }
  final Object? entries = table[listName];
  if (entries is! List<Object?> || entries.isEmpty) {
    throw FormatException('the shared table $fileName has no $listName');
  }
  return entries;
}

List<SharedCase> _readSharedCases(String fileName, String listName) {
  return <SharedCase>[
    for (final Object? entry in _readSharedList(fileName, listName))
      entry! as SharedCase,
  ];
}

List<StepStatus> _readStepStatuses(Object? wireNames) {
  return <StepStatus>[
    for (final Object? wireName in wireNames! as List<Object?>)
      mapStepStatusFromNode(node.StepStatus.decode(wireName)),
  ];
}

RunStatus _readRunStatus(Object? wireName) {
  return mapRunStatusFromNode(node.RunStatus.decode(wireName));
}

List<SharedNextRunCase> readSharedNextRunCases() {
  return <SharedNextRunCase>[
    for (final SharedCase entry in _readSharedCases(
      _nextRunCasesFile,
      'next_runs',
    ))
      (
        schedule: mapScheduleFromNode(
          node.Schedule.fromJson(entry['schedule']),
        ),
        after: DateTime.parse(entry['after']! as String),
        next: DateTime.parse(entry['next']! as String),
      ),
  ];
}

List<SharedScopeCase> readSharedScopeCases() {
  return <SharedScopeCase>[
    for (final SharedCase entry in _readSharedCases(
      _scopeCasesFile,
      'scope_rules',
    ))
      (
        scope: mapScopeFromNode(node.Scope.fromJson(entry['scope'])),
        workspaceId: WorkspaceId(entry['workspace_id']! as String),
        projectId: ProjectId(entry['project_id']! as String),
        includesWorkspace: entry['includes_workspace']! as bool,
        includesProject: entry['includes_project']! as bool,
        applies: entry['applies']! as bool,
      ),
  ];
}

List<SharedRunStatusCase> readSharedRunStatusCases() {
  return <SharedRunStatusCase>[
    for (final SharedCase entry in _readSharedCases(
      _runLifecycleCasesFile,
      'run_statuses',
    ))
      (
        status: _readRunStatus(entry['status']),
        isFinished: entry['is_finished']! as bool,
        canRetry: entry['can_retry']! as bool,
      ),
  ];
}

List<SharedCancelCase> readSharedCancelCases() {
  return <SharedCancelCase>[
    for (final SharedCase entry in _readSharedCases(
      _runLifecycleCasesFile,
      'cancels',
    ))
      (
        steps: _readStepStatuses(entry['steps']),
        afterCancel: _readStepStatuses(entry['after_cancel']),
      ),
  ];
}

List<SharedRetryCase> readSharedRetryCases() {
  return <SharedRetryCase>[
    for (final SharedCase entry in _readSharedCases(
      _runLifecycleCasesFile,
      'retries',
    ))
      (
        steps: _readStepStatuses(entry['steps']),
        afterRetry: _readStepStatuses(entry['after_retry']),
        statusAfterRetry: _readRunStatus(entry['status_after_retry']),
      ),
  ];
}

List<String> readSharedDefaultProtectedPatterns() {
  return <String>[
    for (final Object? pattern in _readSharedList(
      _defaultPatternsFile,
      'default_protected_patterns',
    ))
      pattern! as String,
  ];
}
