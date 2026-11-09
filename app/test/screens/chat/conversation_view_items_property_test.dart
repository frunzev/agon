import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_chat_conversations.dart';
import 'support/shown_chat_items.dart';

const Size _desktopSize = Size(desktopWidth, desktopHeight);
const String _runnerName = 'mac-studio';
const double _tolerance = 0.5;
const Duration _momentStep = Duration(minutes: 1);

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

Conversation _withLinkLostAt(Conversation conversation, DateTime lostAt) {
  return buildChatConversation(
    messages: conversation.messages,
    linkLostAt: lostAt,
    agentActivity: conversation.agentActivity,
    link: RunnerLink.unreachable,
  );
}

Rect _findArea(List<ShownChatItem> shown, String label) {
  return shown.firstWhere((ShownChatItem item) => item.label == label).area;
}

void main() {
  testWidgets('test_find_first_message_after_property_banner_splits_messages_'
      'by_the_lost_moment', (WidgetTester tester) async {
    final Random random = seededRandom(97201);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = randomShortConversation(random);
      final DateTime? lostAt = conversation.linkLostAt;
      final List<ShownChatItem> shown = await _showConversation(
        tester,
        conversation,
      );
      if (lostAt == null) {
        continue;
      }

      final Rect banner = _findArea(shown, lostLinkBannerLabel);
      for (final ChatMessage message in conversation.messages) {
        final Rect area = _findArea(shown, message.text);
        if (message.at.isAfter(lostAt)) {
          expect(area.top, greaterThan(banner.bottom - _tolerance));
        } else {
          expect(area.bottom, lessThan(banner.top + _tolerance));
        }
      }
    }
  });

  testWidgets('test_find_first_message_after_property_messages_at_the_lost_'
      'moment_stay_above_the_banner', (WidgetTester tester) async {
    final Random random = seededRandom(97202);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation sample = randomShortConversation(random);
      if (sample.messages.isEmpty) {
        continue;
      }
      final ChatMessage lostWith = pickOne(random, sample.messages);

      final List<ShownChatItem> shown = await _showConversation(
        tester,
        _withLinkLostAt(sample, lostWith.at),
      );

      final Rect banner = _findArea(shown, lostLinkBannerLabel);
      expect(_findArea(shown, lostWith.text).bottom, lessThan(banner.top));
    }
  });

  testWidgets('test_find_first_message_after_property_banner_goes_to_the_'
      'edge_the_moment_lies_beyond', (WidgetTester tester) async {
    final Random random = seededRandom(97203);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation sample = randomShortConversation(random);
      final List<ChatMessage> messages = sample.messages;
      final bool isBeforeAll = messages.isEmpty || random.nextBool();
      final DateTime lostAt = isBeforeAll
          ? DateTime.utc(2026, 11, 8, 14).subtract(_momentStep)
          : messages.last.at.add(_momentStep);

      final List<String> shown = labelShownChatItems(
        await _showConversation(tester, _withLinkLostAt(sample, lostAt)),
      );

      final List<String> messagesAndBanner = <String>[
        for (final String label in shown)
          if (label != workingLineLabel) label,
      ];
      final String expectedEdge = isBeforeAll
          ? messagesAndBanner.first
          : messagesAndBanner.last;
      expect(expectedEdge, lostLinkBannerLabel);
    }
  });

  testWidgets('test_build_separator_property_items_are_one_gap_apart', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97204);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Size size = randomChatWindowSize(random);
      await pumpConversationView(
        tester,
        size: size,
        conversation: randomChatConversation(random),
        runnerName: _runnerName,
      );

      final List<ShownChatItem> shown = readShownChatItemsTopDown();
      for (int index = 1; index < shown.length; index += 1) {
        final double previousBottom = shown[index - 1].area.bottom;
        final double gap = shown[index].area.top - previousBottom;
        expect(gap, closeTo(AppSpacing.space4, _tolerance), reason: '$size');
      }
    }
  });

  testWidgets('test_build_separator_property_no_gap_above_the_oldest_item', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97205);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final List<ShownChatItem> shown = await _showConversation(
        tester,
        randomShortConversation(random),
      );
      if (shown.isEmpty) {
        continue;
      }

      final Rect view = readConversationArea(tester);
      expect(shown.first.area.top, closeTo(view.top, _tolerance));
    }
  });

  testWidgets('test_build_separator_property_banner_and_working_line_are_'
      'spaced_like_messages', (WidgetTester tester) async {
    final Random random = seededRandom(97206);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation sample = randomShortConversation(random);
      final DateTime lostAt = sample.messages.isEmpty
          ? DateTime.utc(2026, 11, 8, 14)
          : pickOne(random, sample.messages).at;
      final Conversation conversation = buildChatConversation(
        messages: sample.messages,
        linkLostAt: lostAt,
        agentActivity: AgentActivity.replying,
        link: RunnerLink.unreachable,
      );

      final List<ShownChatItem> shown = await _showConversation(
        tester,
        conversation,
      );

      for (int index = 1; index < shown.length; index += 1) {
        final double previousBottom = shown[index - 1].area.bottom;
        final double gap = shown[index].area.top - previousBottom;
        expect(gap, closeTo(AppSpacing.space4, _tolerance));
      }
    }
  });
}
