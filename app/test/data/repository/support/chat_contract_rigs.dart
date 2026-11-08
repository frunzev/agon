import 'dart:math';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';

import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_work_repositories.dart';
import '../../../support/random_inputs.dart';
import '../../node_backed/support/simulated_node_replies.dart';
import '../../node_backed/support/task_repository_rig.dart';
import 'white_space_inputs.dart';

const int _largestSeed = 1 << 30;
const int _largestMissingNumber = 1 << 30;

typedef NamedChatRepository = ({String name, ChatRepository repository});

typedef MessageProjection = ({ChatAuthor author, String text, bool isError});

typedef ChatContractWorld = ({
  List<NamedChatRepository> implementations,
  List<RunId> runIds,
});

Future<ChatContractWorld> buildEveryChatRepository(Random random) async {
  final int seed = random.nextInt(_largestSeed);
  final TaskRepositoryRig nodeRig = await openSeededTaskRepositoryRig(
    seededRandom(seed),
  );
  final TaskRepositoryRig fakeRig = await openSeededTaskRepositoryRig(
    seededRandom(seed),
  );
  final TaskRepositoryRig refusingRig = await openSeededTaskRepositoryRig(
    seededRandom(seed),
  );

  final List<RunId> runIds = <RunId>[
    for (final Run run in listEveryListedRun(nodeRig.tasks)) run.id,
  ];
  final List<NamedChatRepository> implementations = <NamedChatRepository>[
    (name: 'fake', repository: _buildFakeChat(fakeRig, random)),
    (
      name: 'node backed',
      repository: NodeBackedChatRepository(
        channel: buildSimulatedChannel(nodeRig.node.answer),
        runSource: nodeRig.tasks,
        workspaceRepository: nodeRig.workspaces,
      ),
    ),
    (
      name: 'refusing double',
      repository: RefusingChatRepository(
        stored: _buildFakeChat(refusingRig, random),
        refusal: PlannedRefusal(),
      ),
    ),
  ];
  return (implementations: implementations, runIds: runIds);
}

FakeChatRepository _buildFakeChat(TaskRepositoryRig rig, Random random) {
  return FakeChatRepository(
    conversations: const <Conversation>[],
    taskRepository: rig.tasks,
    clock: FixedClock(randomUtcMoment(random)),
  );
}

RunId pickRunId(Random random, List<RunId> knownRunIds) {
  if (knownRunIds.isEmpty || random.nextInt(4) == 0) {
    return RunId('missing-run-${random.nextInt(_largestMissingNumber)}');
  }
  return pickOne(random, knownRunIds);
}

String randomBlankMessage(Random random) {
  return '${pickOne(random, unicodeWhiteSpaces)}'
      '${randomWhiteSpacePadding(random)}';
}

String randomPaddedMessage(Random random) {
  final List<String> cores = <String>[
    'hello',
    randomText(random),
    byteOrderMark,
    '${byteOrderMark}hi$byteOrderMark',
    randomWordPhrase(random),
  ];
  return '${randomWhiteSpacePadding(random)}'
      '${pickOne(random, cores)}'
      '${randomWhiteSpacePadding(random)}';
}

List<MessageProjection> projectMessages(List<ChatMessage> messages) {
  final List<MessageProjection> projections = <MessageProjection>[];
  for (final ChatMessage message in messages) {
    projections.add(projectMessage(message));
  }
  return projections;
}

MessageProjection projectMessage(ChatMessage message) {
  return (
    author: message.author,
    text: message.text,
    isError: message.isError,
  );
}
