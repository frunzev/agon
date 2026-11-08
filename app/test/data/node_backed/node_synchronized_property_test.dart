import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/random_account_json.dart';
import '../../bridge/support/scripted_node_transport.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/fixed_qr_code_scanner.dart';
import '../../support/memory_workspace_choice_store.dart';
import '../../support/random_inputs.dart';
import 'support/identifier_ordered_records.dart';
import 'support/simulated_catalog_node.dart';

const int _iterations = 20;
const int _largestRecordCount = 4;
const int _largestTopicCount = 6;
const List<String> _catalogListings = <String>[
  'list_workspaces',
  'list_projects',
  'list_skills',
  'list_rules',
];
final DateTime _contractMoment = DateTime.utc(2026, 11, 7, 10);

SimulatedCatalogNode _buildCatalog(Random random) {
  final SimulatedCatalogNode catalog = SimulatedCatalogNode(hasAccount: true);
  catalog.addWorkspace(randomWordPhrase(random));
  final int workspaceCount = random.nextInt(_largestRecordCount);
  for (int i = 0; i < workspaceCount; i += 1) {
    catalog.addWorkspace(randomWordPhrase(random));
  }
  _addLibraryRecords(random, catalog);
  return catalog;
}

void _addLibraryRecords(Random random, SimulatedCatalogNode catalog) {
  final int recordCount = random.nextInt(_largestRecordCount);
  for (int i = 0; i < recordCount; i += 1) {
    final Map<String, Object?> workspace = pickOne(random, catalog.workspaces);
    final String workspaceId = workspace['id']! as String;
    catalog.addSkill(workspaceId: workspaceId, name: randomWordPhrase(random));
    catalog.addRule(workspaceId: workspaceId, title: randomWordPhrase(random));
  }
}

AppDependencies _buildApp(SimulatedCatalogNode catalog) {
  return buildNodeDependencies(
    channel: NodeCommandChannel(
      transport: ScriptedNodeTransport(
        answer: IdentifierOrderedCatalogNode(catalog).answer,
      ),
    ),
    clock: FixedClock(_contractMoment),
    qrCodeScanner: FixedQrCodeScanner(null),
    folderPicker: FixedFolderPicker(null),
    workspaceChoiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
    runnerPresence: null,
  ).app;
}

List<NodeSynchronized> _listCatalogRepositories(AppDependencies app) {
  return <NodeSynchronized>[
    app.workspaceRepository as NodeSynchronized,
    app.projectRepository as NodeSynchronized,
    app.skillRepository as NodeSynchronized,
    app.ruleRepository as NodeSynchronized,
  ];
}

Future<void> _loadAll(AppDependencies app) async {
  for (final NodeSynchronized repository in _listCatalogRepositories(app)) {
    await repository.load();
  }
}

List<String> _describeCatalog(AppDependencies app) {
  final List<String> shown = <String>[];
  for (final Workspace workspace in app.workspaceRepository.listWorkspaces()) {
    shown.add('workspace ${workspace.id.value} ${workspace.name}');
    for (final Project project in app.projectRepository.listProjects(
      workspace.id,
    )) {
      shown.add('project ${project.id.value}');
    }
  }
  for (final Skill skill in app.skillRepository.listSkills()) {
    shown.add('skill ${skill.id.value} ${skill.name}');
  }
  for (final Rule rule in app.ruleRepository.listRules()) {
    shown.add('rule ${rule.id.value} ${rule.title}');
  }
  return shown;
}

List<node.ChangeTopic> _listEveryAreaTopic() {
  return <node.ChangeTopic>[
    for (final node.ChangeArea area in node.ChangeArea.values)
      node.AreaChanged(area: area),
  ];
}

void main() {
  test('test_node_synchronized_load_property_a_second_load_changes_'
      'nothing', () async {
    final Random random = seededRandom(96701);

    for (int i = 0; i < _iterations; i += 1) {
      final AppDependencies app = _buildApp(_buildCatalog(random));
      await _loadAll(app);
      final List<String> firstShown = _describeCatalog(app);

      await _loadAll(app);

      expect(_describeCatalog(app), firstShown);
    }
  });

  test('test_node_synchronized_load_property_loads_at_once_end_like_'
      'one', () async {
    final Random random = seededRandom(96702);

    for (int i = 0; i < _iterations; i += 1) {
      final SimulatedCatalogNode catalog = _buildCatalog(random);
      final AppDependencies app = _buildApp(catalog);
      final AppDependencies reference = _buildApp(catalog);
      await _loadAll(reference);
      await (app.workspaceRepository as NodeSynchronized).load();

      await Future.wait(<Future<void>>[
        for (final NodeSynchronized repository in _listCatalogRepositories(
          app,
        )) ...<Future<void>>[repository.load(), repository.load()],
      ]);

      expect(_describeCatalog(app), _describeCatalog(reference));
    }
  });

  test('test_node_synchronized_load_property_a_refused_load_keeps_the_'
      'last_listing', () async {
    final Random random = seededRandom(96703);

    for (int i = 0; i < _iterations; i += 1) {
      final SimulatedCatalogNode catalog = _buildCatalog(random);
      final AppDependencies app = _buildApp(catalog);
      await _loadAll(app);
      final List<String> shownBefore = _describeCatalog(app);
      final int refusedPosition = random.nextInt(_catalogListings.length);
      catalog.failingCommands.add(_catalogListings[refusedPosition]);
      _addLibraryRecords(random, catalog);

      final NodeSynchronized refused = _listCatalogRepositories(
        app,
      )[refusedPosition];

      await expectLater(refused.load(), throwsStateError);
      expect(_describeCatalog(app), shownBefore);
    }
  });

  test('test_node_synchronized_apply_change_property_an_unchanged_node_'
      'shows_the_same', () async {
    final Random random = seededRandom(96704);

    for (int i = 0; i < _iterations; i += 1) {
      final AppDependencies app = _buildApp(_buildCatalog(random));
      await _loadAll(app);
      final List<String> shownBefore = _describeCatalog(app);
      final int topicCount = 1 + random.nextInt(_largestTopicCount);

      for (int j = 0; j < topicCount; j += 1) {
        final node.ChangeTopic topic = node.ChangeTopic.fromJson(
          randomChangeTopicJson(random),
        );
        for (final NodeSynchronized repository in _listCatalogRepositories(
          app,
        )) {
          await repository.applyChange(topic);
        }
      }

      expect(_describeCatalog(app), shownBefore);
    }
  });

  test('test_node_synchronized_apply_change_property_every_area_once_'
      'equals_a_fresh_load', () async {
    final Random random = seededRandom(96705);

    for (int i = 0; i < _iterations; i += 1) {
      final SimulatedCatalogNode catalog = _buildCatalog(random);
      final AppDependencies app = _buildApp(catalog);
      await _loadAll(app);
      catalog.addWorkspace(randomWordPhrase(random));
      _addLibraryRecords(random, catalog);

      for (final node.ChangeTopic topic in _listEveryAreaTopic()) {
        for (final NodeSynchronized repository in _listCatalogRepositories(
          app,
        )) {
          await repository.applyChange(topic);
        }
      }
      final AppDependencies fresh = _buildApp(catalog);
      await _loadAll(fresh);

      expect(_describeCatalog(app), _describeCatalog(fresh));
    }
  });

  test('test_node_synchronized_apply_change_property_a_change_then_a_'
      'load_ends_like_the_load', () async {
    final Random random = seededRandom(96706);

    for (int i = 0; i < _iterations; i += 1) {
      final SimulatedCatalogNode catalog = _buildCatalog(random);
      final AppDependencies app = _buildApp(catalog);
      await _loadAll(app);
      _addLibraryRecords(random, catalog);
      final node.ChangeTopic topic = node.ChangeTopic.fromJson(
        randomChangeTopicJson(random),
      );

      for (final NodeSynchronized repository in _listCatalogRepositories(
        app,
      )) {
        await repository.applyChange(topic);
      }
      await _loadAll(app);
      final AppDependencies fresh = _buildApp(catalog);
      await _loadAll(fresh);

      expect(_describeCatalog(app), _describeCatalog(fresh));
    }
  });
}
