import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/chat/chat_message_views.dart';
import 'package:agent_orchestration/screens/chat/conversation_view.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_chat_conversations.dart';
import 'support/shown_chat_items.dart';

const String _emptyTitle = 'No messages yet';
const String _emptyMessage =
    "The agent's replies and the commands it runs show up here as it works.";
const double _tolerance = 0.5;

int _countWaitingMessagesShown(List<ShownChatItem> shown) {
  int count = 0;
  for (final ShownChatItem item in shown) {
    final Widget view = item.view;
    if (view is UserMessageView && view.message.waitingToSend) {
      count += 1;
    }
  }
  return count;
}

ChatMessage _buildNewestMessage(Conversation conversation, Random random) {
  final List<ChatMessage> messages = conversation.messages;
  final DateTime at = messages.isEmpty
      ? DateTime.utc(2026, 11, 8, 15)
      : messages.last.at.add(const Duration(seconds: 5));
  return buildChatMessage(
    at: at,
    author: pickOne(random, ChatAuthor.values),
    text: markChatText(messages.length, 'newest ${randomText(random)}'),
  );
}

void main() {
  test('test_conversation_view_constructor_property_keeps_conversation_'
      'and_runner_name', () {
    final Random random = seededRandom(97101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Conversation conversation = randomChatConversation(random);
      final String runnerName = randomHostileText(random);

      final ConversationView view = ConversationView(
        conversation: conversation,
        runnerName: runnerName,
      );

      expect(identical(view.conversation, conversation), isTrue);
      expect(view.runnerName, runnerName);
    }
  });

  testWidgets('test_conversation_view_constructor_property_runner_name_'
      'reaches_every_waiting_message', (WidgetTester tester) async {
    final Random random = seededRandom(97102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Conversation conversation = randomShortConversation(random);
      final String runnerName = 'runner ${randomText(random)}';

      await pumpConversationView(
        tester,
        size: const Size(desktopWidth, desktopHeight),
        conversation: conversation,
        runnerName: runnerName,
      );

      final List<ShownChatItem> shown = readShownChatItemsTopDown();
      final Finder waitingLabels = find.text('Sends when $runnerName is back');
      expect(tester.takeException(), isNull);
      expect(
        waitingLabels.evaluate().length,
        _countWaitingMessagesShown(shown),
      );
    }
  });

  testWidgets('test_conversation_view_build_property_never_overflows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97103);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Size size = randomChatWindowSize(random);

      await pumpConversationView(
        tester,
        size: size,
        conversation: randomChatConversation(random),
        runnerName: randomChatText(random),
      );

      expect(tester.takeException(), isNull, reason: 'size $size');
    }
  });

  testWidgets('test_conversation_view_build_property_only_a_silent_'
      'conversation_shows_the_design_empty_state', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97104);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = randomConversationOfAtMost(random, 1);
      final bool isSilent = listExpectedChatItems(conversation).isEmpty;

      await pumpConversationView(
        tester,
        size: randomChatWindowSize(random),
        conversation: conversation,
        runnerName: 'mac-studio',
      );

      final Matcher shown = isSilent ? findsOneWidget : findsNothing;
      expect(tester.takeException(), isNull);
      expect(find.text(_emptyTitle), shown);
      expect(find.text(_emptyMessage), shown);
    }
  });

  testWidgets('test_conversation_view_build_property_every_item_stays_'
      'inside_the_view', (WidgetTester tester) async {
    final Random random = seededRandom(97105);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Size size = randomChatWindowSize(random);

      await pumpConversationView(
        tester,
        size: size,
        conversation: randomChatConversation(random),
        runnerName: randomChatText(random),
      );

      final Rect view = readConversationArea(tester);
      for (final ShownChatItem item in readShownChatItemsTopDown()) {
        final String reason = 'size $size, item ${item.label}';
        final double leftmost = view.left - _tolerance;
        final double rightmost = view.right + _tolerance;
        expect(item.area.left, greaterThanOrEqualTo(leftmost), reason: reason);
        expect(item.area.right, lessThanOrEqualTo(rightmost), reason: reason);
        expect(item.area.width, greaterThan(0), reason: reason);
      }
    }
  });

  testWidgets('test_build_items_property_order_is_chronological', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97106);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = randomChatConversation(random);

      await pumpConversationView(
        tester,
        size: randomChatWindowSize(random),
        conversation: conversation,
        runnerName: 'mac-studio',
      );

      final List<String> shown = labelShownChatItems(
        readShownChatItemsTopDown(),
      );
      final List<String> expected = listExpectedChatItems(conversation);
      expect(shown, takeNewestLabels(expected, shown.length));
      expect(shown.isEmpty, expected.isEmpty);
    }
  });

  testWidgets('test_build_items_property_opens_at_the_newest_item', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97107);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = randomChatConversation(random);
      final List<String> expected = listExpectedChatItems(conversation);

      await pumpConversationView(
        tester,
        size: randomChatWindowSize(random),
        conversation: conversation,
        runnerName: 'mac-studio',
      );

      final List<ShownChatItem> shown = readShownChatItemsTopDown();
      if (expected.isEmpty) {
        expect(shown, isEmpty);
        continue;
      }
      final Rect view = readConversationArea(tester);
      final ShownChatItem newest = shown.last;
      expect(newest.label, expected.last);
      expect(newest.area.bottom, lessThanOrEqualTo(view.bottom + _tolerance));
      expect(newest.area.bottom, greaterThan(view.top));
    }
  });

  testWidgets('test_build_items_property_a_new_message_lands_at_the_bottom', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomChatWindowSize(random);
      final Conversation before = randomChatConversation(random);
      final ChatMessage newest = _buildNewestMessage(before, random);
      final Conversation after = before.withMessages(<ChatMessage>[
        ...before.messages,
        newest,
      ]);
      await pumpConversationView(
        tester,
        size: size,
        conversation: before,
        runnerName: 'mac-studio',
      );

      await pumpConversationView(
        tester,
        size: size,
        conversation: after,
        runnerName: 'mac-studio',
      );

      final List<String> shown = labelShownChatItems(
        readShownChatItemsTopDown(),
      );
      final List<String> expected = listExpectedChatItems(after);
      expect(tester.takeException(), isNull);
      expect(shown, takeNewestLabels(expected, shown.length));
      expect(shown, contains(newest.text));
    }
  });
}
