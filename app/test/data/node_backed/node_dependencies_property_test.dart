import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/node/support/feed_poll_transport.dart';
import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/identifier_ordered_records.dart';
import 'support/node_dependencies_building.dart';
import 'support/simulated_catalog_node.dart';
import 'support/workspace_repository_rig.dart';

const int _iterations = 20;
const int _largestWorkspaceCount = 4;
const String _commandField = 'command';
const String _workspaceField = 'workspace_id';
const String _pollEventsCommand = 'poll_events';
const String _listProjectsCommand = 'list_projects';
const List<String> _workspaceLoadCommands = <String>[
  'status',
  'list_workspaces',
];

final class _CatalogWithFeed {
  _CatalogWithFeed(this.catalog);

  final SimulatedCatalogNode catalog;

  String answer(String inputJson) {
    final Map<String, Object?> command =
        jsonDecode(inputJson) as Map<String, Object?>;
    if (command[_commandField] == _pollEventsCommand) {
      return encodeEventsReply(<Object?>[], latestSequence: 0);
    }
    return IdentifierOrderedCatalogNode(catalog).answer(inputJson);
  }
}

SimulatedCatalogNode _buildCatalog(Random random) {
  final SimulatedCatalogNode catalog = SimulatedCatalogNode(hasAccount: true);
  final int workspaceCount = 1 + random.nextInt(_largestWorkspaceCount);
  for (int i = 0; i < workspaceCount; i += 1) {
    catalog.addWorkspace(randomWordPhrase(random));
  }
  return catalog;
}

List<Map<String, Object?>> _readSentCommands(ScriptedNodeTransport transport) {
  return <Map<String, Object?>>[
    for (final RecordedExchange exchange in transport.exchanges)
      jsonDecode(exchange.inputJson) as Map<String, Object?>,
  ];
}

List<Object> _listRepositories(AppDependencies app) {
  return <Object>[
    app.taskRepository,
    app.jobRepository,
    app.chatRepository,
    app.approvalRepository,
    app.personStepRepository,
    app.projectRepository,
    app.workspaceRepository,
    app.workflowRepository,
    app.skillRepository,
    app.ruleRepository,
    app.runnerRepository,
    app.agentLoginRepository,
    app.deviceRepository,
    app.pairingRepository,
    app.auditRepository,
    app.fileRepository,
    app.itemDraftRepository,
  ];
}

List<NodeSynchronized> _listSynchronizedRepositories(AppDependencies app) {
  return <NodeSynchronized>[
    for (final Object repository in _listRepositories(app))
      if (repository is NodeSynchronized) repository,
  ];
}

void main() {
  test('test_build_node_dependencies_property_passes_the_collaborators_'
      'through', () {
    final Random random = seededRandom(96602);

    for (int i = 0; i < _iterations; i += 1) {
      final DependencyCollaborators collaborators =
          randomDependencyCollaborators(random);
      final NodeDependencies built = buildDependenciesWith(
        NodeCommandChannel(
          transport: ScriptedNodeTransport(answer: encodeErrorReply),
        ),
        collaborators,
      );

      expect(identical(built.app.clock, collaborators.clock), isTrue);
      expect(
        identical(built.app.qrCodeScanner, collaborators.qrCodeScanner),
        isTrue,
      );
      expect(
        identical(built.app.folderPicker, collaborators.folderPicker),
        isTrue,
      );
      expect(
        identical(built.app.runnerPresence, collaborators.runnerPresence),
        isTrue,
      );
    }
  });

  test('test_build_node_dependencies_property_every_build_is_its_'
      'own_graph', () {
    final Random random = seededRandom(96603);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(answer: encodeErrorReply),
      );
      final DependencyCollaborators collaborators =
          randomDependencyCollaborators(random);

      final NodeDependencies first = buildDependenciesWith(
        channel,
        collaborators,
      );
      final NodeDependencies second = buildDependenciesWith(
        channel,
        collaborators,
      );

      final List<Object> firstRepositories = _listRepositories(first.app);
      final List<Object> secondRepositories = _listRepositories(second.app);
      expect(firstRepositories.toSet(), hasLength(firstRepositories.length));
      for (int j = 0; j < firstRepositories.length; j += 1) {
        expect(
          identical(firstRepositories[j], secondRepositories[j]),
          isFalse,
        );
      }
      expect(
        identical(first.synchronization, second.synchronization),
        isFalse,
      );
    }
  });

  test('test_build_node_dependencies_property_one_workspace_repository_'
      'backs_the_app', () async {
    final Random random = seededRandom(96604);

    for (int i = 0; i < _iterations; i += 1) {
      final SimulatedCatalogNode catalog = _buildCatalog(random);
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: IdentifierOrderedCatalogNode(catalog).answer,
      );
      final NodeDependencies built = buildDependenciesWith(
        NodeCommandChannel(transport: transport),
        randomDependencyCollaborators(random),
      );

      await (built.app.workspaceRepository as NodeSynchronized).load();
      await (built.app.projectRepository as NodeSynchronized).load();

      final Set<Object?> projectWorkspaces = <Object?>{
        for (final Map<String, Object?> command in _readSentCommands(
          transport,
        ))
          if (command[_commandField] == _listProjectsCommand)
            command[_workspaceField],
      };
      expect(projectWorkspaces, <Object?>{
        for (final Workspace workspace
            in built.app.workspaceRepository.listWorkspaces())
          workspace.id.value,
      });
    }
  });

  test('test_build_node_dependencies_property_every_synchronized_'
      'repository_uses_the_given_channel', () async {
    final Random random = seededRandom(96605);

    for (int i = 0; i < _iterations; i += 1) {
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: IdentifierOrderedCatalogNode(_buildCatalog(random)).answer,
      );
      final NodeDependencies built = buildDependenciesWith(
        NodeCommandChannel(transport: transport),
        randomDependencyCollaborators(random),
      );
      final List<NodeSynchronized> repositories =
          _listSynchronizedRepositories(built.app);
      await (built.app.workspaceRepository as NodeSynchronized).load();

      for (final NodeSynchronized repository in repositories) {
        final int exchangesBefore = transport.exchanges.length;
        final Object? problem = await readRepositoryProblem(repository.load);
        expect(problem, anyOf(isNull, isA<StateError>()));
        expect(
          transport.exchanges.length,
          greaterThan(exchangesBefore),
          reason: '${repository.runtimeType}',
        );
      }
    }
  });

  test('test_build_node_dependencies_property_the_workspace_loads_'
      'first', () async {
    final Random random = seededRandom(96606);

    for (int i = 0; i < _iterations; i += 1) {
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: _CatalogWithFeed(_buildCatalog(random)).answer,
      );
      final NodeDependencies built = buildDependenciesWith(
        NodeCommandChannel(transport: transport),
        randomDependencyCollaborators(random),
      );

      final Object? problem = await readRepositoryProblem(
        built.synchronization.start,
      );
      await built.synchronization.stop();

      final List<Object?> sentNames = <Object?>[
        for (final Map<String, Object?> command in _readSentCommands(
          transport,
        ))
          command[_commandField],
      ];
      expect(problem, isA<StateError>());
      expect(sentNames.first, _pollEventsCommand);
      expect(sentNames.sublist(1, 3), _workspaceLoadCommands);
    }
  });
}
