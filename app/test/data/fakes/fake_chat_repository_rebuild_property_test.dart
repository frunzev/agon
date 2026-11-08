import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_runs.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_conversation.dart';

import '../../support/random_inputs.dart';
import 'support/chat_inputs.dart';

const String _typePrefix = 'test_fake_chat_repository';
const int _largestSendCount = 4;

FakeChatRepository _buildChat(Random random, TaskRepository runs) {
  return FakeChatRepository(
    conversations: const <Conversation>[],
    taskRepository: runs,
    clock: FixedClock(randomUtcMoment(random)),
  );
}

List<RunId> _listRepliedRunIds() {
  return <RunId>[
    for (final Run run in galleryRuns)
      if (run.steps.any((RunStep step) => step.status == StepStatus.running))
        run.id,
  ];
}

void _expectRebuiltFromRun(
  Conversation conversation,
  Run run,
  List<ChatMessage> sentMessages,
) {
  final Conversation fromRun = buildConversationFromRun(run);
  expect(conversation.link, fromRun.link);
  expect(conversation.linkLostAt, fromRun.linkLostAt);
  expect(conversation.agentActivity, fromRun.agentActivity);
  expect(
    conversation.messages,
    orderedEquals(<ChatMessage>[...run.chat, ...sentMessages]),
  );
}

void main() {
  test('${_typePrefix}_find_conversation_property_follows_the_run_after_'
      'a_send', () async {
    final Random random = seededRandom(88201);
    final List<RunId> repliedRunIds = _listRepliedRunIds();

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final TaskRepository runs = buildGalleryDependencies().taskRepository;
      final FakeChatRepository repository = _buildChat(random, runs);
      final RunId runId = pickOne(random, repliedRunIds);

      final ChatMessage sent = await repository.sendMessage(
        runId,
        randomChatMessageText(random),
      );
      await runs.cancelRun(runId);

      final Conversation conversation = repository.findConversation(runId);
      _expectRebuiltFromRun(conversation, runs.findRun(runId), <ChatMessage>[
        sent,
      ]);
      expect(conversation.agentActivity, AgentActivity.idle);
    }
  });

  test('${_typePrefix}_send_message_property_never_waits_to_send', () async {
    final Random random = seededRandom(88202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeChatRepository repository = _buildChat(
        random,
        buildChatTaskRepository(random),
      );
      final RunId runId = pickChatRunId(random, const <Conversation>[]);

      final ChatMessage sent = await repository.sendMessage(
        runId,
        randomChatMessageText(random),
      );

      expect(sent.waitingToSend, isFalse);
      expect(repository.findConversation(runId).messages.last, sent);
    }
  });

  test('${_typePrefix}_find_conversation_property_is_the_run_chat_then_'
      'the_sent_messages', () async {
    final Random random = seededRandom(88203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeTaskRepository runs = buildChatTaskRepository(random);
      final FakeChatRepository repository = _buildChat(random, runs);
      final Map<RunId, List<ChatMessage>> sentByRun =
          <RunId, List<ChatMessage>>{};
      final int sendCount = random.nextInt(_largestSendCount + 1);

      for (int send = 0; send < sendCount; send += 1) {
        final RunId runId = pickChatRunId(random, const <Conversation>[]);
        final ChatMessage sent = await repository.sendMessage(
          runId,
          randomChatMessageText(random),
        );
        sentByRun.putIfAbsent(runId, () => <ChatMessage>[]).add(sent);
      }

      for (int index = 0; index < otherChatRunCount; index += 1) {
        final RunId runId = RunId('$otherChatRunPrefix$index');
        _expectRebuiltFromRun(
          repository.findConversation(runId),
          runs.findRun(runId),
          sentByRun[runId] ?? const <ChatMessage>[],
        );
      }
    }
  });
}
