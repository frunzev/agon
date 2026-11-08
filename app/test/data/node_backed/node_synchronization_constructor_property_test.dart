import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/change_values.dart' as node;
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../bridge/node/support/feed_poll_transport.dart';
import '../../support/random_inputs.dart';
import 'support/synchronization_rig.dart';

const int _iterations = 25;
const int _largestRepositoryCount = 6;
const int _settlingTurns = 12;

final class _LoadOrderRepository implements NodeSynchronized {
  _LoadOrderRepository({required this.position, required this.loadOrder});

  final int position;
  final List<int> loadOrder;

  @override
  Future<void> load() async {
    loadOrder.add(position);
  }

  @override
  Future<void> applyChange(node.ChangeTopic topic) async {}
}

List<_LoadOrderRepository> _buildLoadOrderRepositories(
  Random random,
  List<int> loadOrder,
) {
  final int count = random.nextInt(_largestRepositoryCount + 1);
  return <_LoadOrderRepository>[
    for (int i = 0; i < count; i += 1)
      _LoadOrderRepository(position: i, loadOrder: loadOrder),
  ];
}

void main() {
  test('test_node_synchronization_constructor_property_loads_in_the_'
      'given_order', () async {
    final Random random = seededRandom(96301);

    for (int i = 0; i < _iterations; i += 1) {
      final List<int> loadOrder = <int>[];
      final List<_LoadOrderRepository> repositories =
          _buildLoadOrderRepositories(random, loadOrder)..shuffle(random);
      final SynchronizationNode syncNode = SynchronizationNode(
        startSequence: 1,
      );
      final NodeSynchronization synchronization = NodeSynchronization(
        channel: NodeCommandChannel(
          transport: FeedPollTransport(answer: syncNode.answer),
        ),
        repositoriesInLoadOrder: repositories,
        retryDelay: Duration.zero,
        recheckAppServer: AppServerRecheckCounter().recheck,
      );

      await synchronization.start();
      await synchronization.stop();

      expect(loadOrder, <int>[
        for (final _LoadOrderRepository repository in repositories)
          repository.position,
      ]);
    }
  });

  test('test_node_synchronization_constructor_property_later_list_edits_'
      'change_nothing', () async {
    final Random random = seededRandom(96302);

    for (int i = 0; i < _iterations; i += 1) {
      final List<int> loadOrder = <int>[];
      final List<NodeSynchronized> given = _buildLoadOrderRepositories(
        random,
        loadOrder,
      );
      final List<int> expectedOrder = <int>[
        for (int j = 0; j < given.length; j += 1) j,
      ];
      final SynchronizationNode syncNode = SynchronizationNode(
        startSequence: 1,
      );
      final NodeSynchronization synchronization = NodeSynchronization(
        channel: NodeCommandChannel(
          transport: FeedPollTransport(answer: syncNode.answer),
        ),
        repositoriesInLoadOrder: given,
        retryDelay: Duration.zero,
        recheckAppServer: AppServerRecheckCounter().recheck,
      );
      given.shuffle(random);
      given.add(_LoadOrderRepository(position: -1, loadOrder: loadOrder));

      await synchronization.start();
      await synchronization.stop();

      expect(loadOrder, expectedOrder);
    }
  });

  test('test_node_synchronization_constructor_property_contacts_nobody_'
      'before_start', () async {
    final Random random = seededRandom(96303);

    for (int i = 0; i < _iterations; i += 1) {
      final AppServerRecheckCounter serverChecks = AppServerRecheckCounter();
      final SynchronizationNode syncNode = SynchronizationNode(
        startSequence: 1,
      );
      final FeedPollTransport transport = FeedPollTransport(
        answer: syncNode.answer,
      );
      final RecordingSynchronizedRepository repository =
          RecordingSynchronizedRepository();
      final NodeSynchronization synchronization = NodeSynchronization(
        channel: NodeCommandChannel(transport: transport),
        repositoriesInLoadOrder: <NodeSynchronized>[repository],
        retryDelay: Duration.zero,
        recheckAppServer: serverChecks.recheck,
      );

      await letFeedTurnsPass(1 + random.nextInt(_settlingTurns));

      expect(transport.startedPolls, 0);
      expect(serverChecks.checks, 0);
      expect(repository.appliedTopics, isEmpty);
      await synchronization.stop();
      expect(transport.startedPolls, 0);
    }
  });
}
