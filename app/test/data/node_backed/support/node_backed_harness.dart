import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/task_values.dart' as node;
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/workspace_repository.dart';

import '../../../bridge/support/random_work_json.dart';

const WorkspaceId harnessWorkspaceId = WorkspaceId('simulated-workspace');
const String _harnessServerAddress = 'http://127.0.0.1:7000';
const Duration _harnessRetryInterval = Duration(seconds: 30);
const DeviceId _harnessDeviceId = DeviceId('simulated-this-device');

final DateTime _harnessMoment = DateTime.utc(2026, 10, 31, 9);

WorkspaceRepository buildSingleWorkspaceRepository() {
  return FakeWorkspaceRepository(
    workspaces: <Workspace>[
      Workspace(
        id: harnessWorkspaceId,
        name: 'home',
        appServerAddress: _harnessServerAddress,
        protectedFiles: const <String>[],
        approvalPolicy: ApprovalPolicy.neverAsk,
      ),
    ],
    currentWorkspaceId: harnessWorkspaceId,
    appServerStatus: AppServerStatus(
      address: _harnessServerAddress,
      state: AppServerState.online,
      lastConnectedAt: _harnessMoment,
      retryInterval: _harnessRetryInterval,
    ),
    appServerGroup: AppServerGroup(
      members: const <AppServerMember>[],
      thisDeviceStanding: ThisDeviceStanding.none,
      canKeepBackup: false,
    ),
    currentDeviceId: _harnessDeviceId,
    clock: FixedClock(_harnessMoment),
  );
}

TaskDraft randomTaskDraft(Random random) {
  final Map<String, Object?> taskJson = randomTaskJson(random);
  taskJson['title'] = 'Task ${taskJson['title']}';
  final node.Task wire = node.Task.fromJson(taskJson);
  return mapTaskFromNode(wire).toDraft();
}
