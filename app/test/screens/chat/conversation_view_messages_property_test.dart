import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/chat/chat_message_views.dart';
import 'package:agent_orchestration/widgets/log_block.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_chat_conversations.dart';
import 'support/shown_chat_items.dart';

const Size _desktopSize = Size(desktopWidth, desktopHeight);
const String _runnerName = 'mac-studio';
const double _tolerance = 0.5;

Future<List<ShownChatItem>> _showConversation(
  WidgetTester tester,
  Conversation conversation,
) async {
  await pumpConversationView(
    tester,
    size: _desktopSize,
    conversation: conversation,
    runnerName: _runnerName,
  );
  expect(tester.takeException(), isNull);
  return readShownChatItemsTopDown();
}

Map<String, ChatAuthor> _mapAuthorsByText(Conversation conversation) {
  return <String, ChatAuthor>{
    for (final ChatMessage message in conversation.messages)
      message.text: message.author,
  };
}

Type _viewTypeFor(ChatAuthor author) {
  switch (author) {
    case ChatAuthor.tool:
      return ToolStepView;
    case ChatAuthor.you:
      return UserMessageView;
    case ChatAuthor.agent:
      return AgentMessageView;
  }
}

Conversation _repeatNewestAgentMessage(Random random) {
  final Conversation conversation = randomShortConversation(random);
  final List<ChatMessage> messages = <ChatMessage>[...conversation.messages];
  final ChatMessage newest = buildChatMessage(
    at: DateTime.utc(2026, 11, 8, 16),
    author: ChatAuthor.agent,
    text: markChatText(messages.length, 'same words again'),
  );
  messages.insert(random.nextInt(messages.length + 1), newest);
  messages.add(newest);
  return buildChatConversation(
    messages: messages,
    linkLostAt: null,
    agentActivity: AgentActivity.replying,
    link: RunnerLink.direct,
  );
}

int _countShownCursors(WidgetTester tester) {
  final Iterable<AgentMessageView> views = tester.widgetList<AgentMessageView>(
    find.byType(AgentMessageView),
  );
  int count = 0;
  for (final AgentMessageView view in views) {
    if (view.cursor == CursorVisibility.shown) {
      count += 1;
    }
  }
  return count;
}

void main() {
  testWidgets('test_build_message_property_each_author_gets_its_own_view', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97207);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = randomChatConversation(random);
      final Map<String, ChatAuthor> authors = _mapAuthorsByText(conversation);
      await pumpConversationView(
        tester,
        size: randomChatWindowSize(random),
        conversation: conversation,
        runnerName: _runnerName,
      );

      for (final ShownChatItem item in readShownChatItemsTopDown()) {
        final ChatAuthor? author = authors[item.label];
        if (author != null) {
          expect(item.view.runtimeType, _viewTypeFor(author));
        }
      }
    }
  });

  testWidgets('test_build_message_property_user_messages_get_the_runner_'
      'name_and_the_view_width', (WidgetTester tester) async {
    final Random random = seededRandom(97208);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final String runnerName = randomChatText(random);
      await pumpConversationView(
        tester,
        size: randomChatWindowSize(random),
        conversation: randomChatConversation(random),
        runnerName: runnerName,
      );

      final double viewWidth = readConversationArea(tester).width;
      final Iterable<UserMessageView> views = tester
          .widgetList<UserMessageView>(find.byType(UserMessageView));
      for (final UserMessageView view in views) {
        expect(view.runnerName, runnerName);
        expect(view.availableWidth, closeTo(viewWidth, _tolerance));
      }
    }
  });

  testWidgets('test_build_message_property_only_the_newest_agent_message_'
      'blinks', (WidgetTester tester) async {
    final Random random = seededRandom(97209);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = _repeatNewestAgentMessage(random);

      final List<ShownChatItem> shown = await _showConversation(
        tester,
        conversation,
      );

      final AgentMessageView newest = shown.last.view as AgentMessageView;
      expect(_countShownCursors(tester), 1);
      expect(newest.cursor, CursorVisibility.shown);
    }
  });
}
