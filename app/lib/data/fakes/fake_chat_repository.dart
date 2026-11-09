import 'package:flutter/foundation.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/fakes/record_lists.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/chat_repository.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/task_repository.dart';
import 'package:agent_orchestration/data/rules/run_conversation.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String _conversationKind = 'conversation';

String _identifyConversationRun(Conversation conversation) {
  return conversation.runId.value;
}

final class FakeChatRepository extends ChangeNotifier
    implements ChatRepository {
  FakeChatRepository({
    required List<Conversation> conversations,
    required TaskRepository taskRepository,
    required Clock clock,
  }) : _seededConversations = <RunId, Conversation>{
         for (final Conversation conversation in conversations)
           conversation.runId: conversation,
       },
       _taskRepository = taskRepository,
       _clock = clock {
    refuseDuplicateIdentifiers(
      conversations,
      identify: _identifyConversationRun,
      kind: _conversationKind,
    );
  }

  final Clock _clock;
  final TaskRepository _taskRepository;
  final Map<RunId, Conversation> _seededConversations;
  final Map<RunId, List<ChatMessage>> _sentMessages =
      <RunId, List<ChatMessage>>{};

  @override
  Conversation findConversation(RunId runId) {
    final Conversation conversation =
        _seededConversations[runId] ??
        buildConversationFromRun(_taskRepository.findRun(runId));
    final List<ChatMessage>? sentMessages = _sentMessages[runId];
    if (sentMessages == null) {
      return conversation;
    }
    return conversation.withMessages(<ChatMessage>[
      ...conversation.messages,
      ...sentMessages,
    ]);
  }

  @override
  Future<ChatMessage> sendMessage(RunId runId, String text) async {
    final String trimmedText = trimUnicodeWhiteSpace(text);
    if (trimmedText.isEmpty) {
      throw PeopleFacingRefusal('Write a message first');
    }

    findConversation(runId);
    final ChatMessage message = ChatMessage(
      at: _clock.now(),
      author: ChatAuthor.you,
      text: trimmedText,
      isError: false,
      waitingToSend: false,
    );

    _sentMessages[runId] = <ChatMessage>[...?_sentMessages[runId], message];
    notifyListeners();
    return message;
  }
}
