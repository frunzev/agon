import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/bridge/node/node_transport.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';

import '../../../bridge/support/scripted_node_transport.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/workspace_inputs.dart';
import '../../fakes/support/workspace_scope_inputs.dart';
import 'simulated_workflow_node.dart';
import 'simulated_workflow_views.dart';

const int _largestSeededWorkflowCount = 6;
const String _commandField = 'command';
const List<String> _seededStates = <String>[
  signedState,
  changedState,
  unsignedState,
];

typedef WorkflowWorkspaceRig = ({
  SimulatedWorkflowNode simulated,
  ScriptedNodeTransport transport,
  SeededWorkspaces workspaces,
  List<WorkspaceId> workspaceIds,
  NodeBackedWorkflowRepository repository,
});

Map<String, Object?> readSimulatedWorkflowRecord(Map<String, Object?> view) {
  return view['workflow']! as Map<String, Object?>;
}

String readSimulatedWorkflowId(Map<String, Object?> view) {
  return readSimulatedWorkflowRecord(view)['id']! as String;
}

void seedWorkflowAvailableOver(
  Random random,
  SimulatedWorkflowNode simulated,
  List<WorkspaceId> workspaceIds,
) {
  final Map<String, Object?> view = simulated.addWorkflow(
    name: 'seeded-${simulated.views.length}',
    state: pickOne(random, _seededStates),
  );
  final WorkspaceScope availability = randomWorkspaceScopeOver(
    random,
    workspaceIds,
  );
  final Object? availabilityJson = mapWorkspaceScopeToNode(availability)
      .toJson();
  readSimulatedWorkflowRecord(view)['availability'] = jsonDecode(
    jsonEncode(availabilityJson),
  );
}

NodeBackedWorkflowRepository buildWorkflowRepositoryOver({
  required NodeTransport transport,
  required SeededWorkspaces workspaces,
}) {
  return NodeBackedWorkflowRepository(
    channel: NodeCommandChannel(transport: transport),
    workspaceRepository: workspaces.repository,
    draftPollInterval: Duration.zero,
  );
}

WorkflowWorkspaceRig openWorkflowWorkspaceRig(Random random) {
  final SeededWorkspaces workspaces = seedRandomWorkspaces(random);
  final List<WorkspaceId> workspaceIds = listWorkspaceIds(
    workspaces.workspaces,
  );
  final SimulatedWorkflowNode simulated = SimulatedWorkflowNode(
    pollsBeforeDraftIsDone: random.nextInt(3),
  );
  final int seededCount = random.nextInt(_largestSeededWorkflowCount + 1);
  for (int index = 0; index < seededCount; index += 1) {
    seedWorkflowAvailableOver(random, simulated, workspaceIds);
  }
  final ScriptedNodeTransport transport = ScriptedNodeTransport(
    answer: simulated.answer,
  );
  return (
    simulated: simulated,
    transport: transport,
    workspaces: workspaces,
    workspaceIds: workspaceIds,
    repository: buildWorkflowRepositoryOver(
      transport: transport,
      workspaces: workspaces,
    ),
  );
}

List<String> predictListedWorkflowIds(
  SimulatedWorkflowNode simulated,
  WorkspaceId workspaceId,
) {
  return <String>[
    for (final Map<String, Object?> view in simulated.views)
      if (isSimulatedWorkflowAvailableIn(view, workspaceId.value))
        readSimulatedWorkflowId(view),
  ];
}

Set<String> predictChangedWorkflowIds(
  SimulatedWorkflowNode simulated,
  WorkspaceId workspaceId,
) {
  return <String>{
    for (final Map<String, Object?> view in simulated.views)
      if (isSimulatedWorkflowAvailableIn(view, workspaceId.value) &&
          view['signature_state'] == changedState)
        readSimulatedWorkflowId(view),
  };
}

List<String> listShownWorkflowIds(NodeBackedWorkflowRepository repository) {
  return <String>[
    for (final Workflow workflow in repository.listWorkflows())
      workflow.id.value,
  ];
}

Set<String> listShownChangedWorkflowIds(
  NodeBackedWorkflowRepository repository,
  SimulatedWorkflowNode simulated,
) {
  return <String>{
    for (final Map<String, Object?> view in simulated.views)
      if (repository.findPendingChange(
            WorkflowId(readSimulatedWorkflowId(view)),
          ) !=
          null)
        readSimulatedWorkflowId(view),
  };
}

int countSentCommands(ScriptedNodeTransport transport, String commandName) {
  int count = 0;
  for (final RecordedExchange exchange in transport.exchanges) {
    final Map<String, Object?> command =
        jsonDecode(exchange.inputJson) as Map<String, Object?>;
    if (command[_commandField] == commandName) {
      count += 1;
    }
  }
  return count;
}

WorkspaceId currentRigWorkspaceId(WorkflowWorkspaceRig rig) {
  return rig.workspaces.repository.currentWorkspace().id;
}
