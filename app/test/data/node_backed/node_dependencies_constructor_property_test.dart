import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/support/scripted_node_transport.dart';
import '../../support/random_inputs.dart';
import 'support/node_dependencies_building.dart';

const int _iterations = 20;

void main() {
  test('test_node_dependencies_constructor_property_keeps_both_'
      'parts', () {
    final Random random = seededRandom(96601);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeCommandChannel channel = NodeCommandChannel(
        transport: ScriptedNodeTransport(answer: encodeErrorReply),
      );
      final NodeDependencies first = buildDependenciesWith(
        channel,
        randomDependencyCollaborators(random),
      );
      final NodeDependencies second = buildDependenciesWith(
        channel,
        randomDependencyCollaborators(random),
      );

      final NodeDependencies mixed = NodeDependencies(
        app: first.app,
        synchronization: second.synchronization,
      );

      expect(identical(mixed.app, first.app), isTrue);
      expect(identical(mixed.synchronization, second.synchronization), isTrue);
      expect(identical(mixed.app, mixed.app), isTrue);
    }
  });

  test('test_node_dependencies_constructor_property_rewrapping_keeps_'
      'the_built_parts', () {
    final Random random = seededRandom(96607);

    for (int i = 0; i < _iterations; i += 1) {
      final NodeDependencies built = buildDependenciesWith(
        NodeCommandChannel(
          transport: ScriptedNodeTransport(answer: encodeErrorReply),
        ),
        randomDependencyCollaborators(random),
      );

      final NodeDependencies rewrapped = NodeDependencies(
        app: built.app,
        synchronization: built.synchronization,
      );

      expect(identical(rewrapped.app, built.app), isTrue);
      expect(
        identical(rewrapped.synchronization, built.synchronization),
        isTrue,
      );
    }
  });

  test('test_node_dependencies_constructor_property_holding_contacts_'
      'nobody', () async {
    final Random random = seededRandom(96608);

    for (int i = 0; i < _iterations; i += 1) {
      final ScriptedNodeTransport transport = ScriptedNodeTransport(
        answer: encodeErrorReply,
      );
      final NodeDependencies built = buildDependenciesWith(
        NodeCommandChannel(transport: transport),
        randomDependencyCollaborators(random),
      );

      final NodeDependencies held = NodeDependencies(
        app: built.app,
        synchronization: built.synchronization,
      );
      await Future<void>.delayed(Duration.zero);

      expect(transport.exchanges, isEmpty);
      expect(held.app.workspaceRepository.listWorkspaces(), isEmpty);
    }
  });
}
