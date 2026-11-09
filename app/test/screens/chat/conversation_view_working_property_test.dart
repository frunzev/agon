import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/chat/chat_message_views.dart';
import 'package:agent_orchestration/widgets/blinking_cursor.dart';
import 'package:agent_orchestration/widgets/log_block.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../bridge/support/random_moments.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_chat_conversations.dart';
import 'support/shown_chat_items.dart';

const String _agentLabel = 'Agent';
const String _bannerBody =
    'Trying the relay now. The agent keeps working in its sandbox, '
    'and your messages wait here until it is back.';
final Conversation _emptyReplyingConversation = buildChatConversation(
  messages: const <ChatMessage>[],
  linkLostAt: null,
  agentActivity: AgentActivity.replying,
  link: RunnerLink.direct,
);
final RegExp _bannerTitlePattern = RegExp(
  r'^Lost the direct link at \d\d:\d\d$',
);

Conversation _withActivity(Conversation sample, AgentActivity activity) {
  return buildChatConversation(
    messages: sample.messages,
    linkLostAt: sample.linkLostAt,
    agentActivity: activity,
    link: sample.link,
  );
}

Conversation _withNewestAuthor(Conversation sample, ChatAuthor author) {
  final ChatMessage newest = buildChatMessage(
    at: DateTime.utc(2026, 11, 8, 17),
    author: author,
    text: markChatText(sample.messages.length, 'newest words'),
  );
  return buildChatConversation(
    messages: <ChatMessage>[...sample.messages, newest],
    linkLostAt: sample.linkLostAt,
    agentActivity: AgentActivity.replying,
    link: sample.link,
  );
}

Future<List<ShownChatItem>> _showAtRandomSize(
  WidgetTester tester,
  Random random,
  Conversation conversation,
) async {
  final Size size = randomChatWindowSize(random);
  await pumpConversationView(
    tester,
    size: size,
    conversation: conversation,
    runnerName: 'mac-studio',
  );
  expect(tester.takeException(), isNull, reason: 'size $size');
  return readShownChatItemsTopDown();
}

Finder _findWorkingLine() {
  return find.byWidgetPredicate(
    (Widget view) => view is AgentMessageView && view.text.isEmpty,
  );
}

void main() {
  testWidgets('test_is_working_before_its_next_words_property_replying_'
      'without_agent_words_shows_a_working_line', (WidgetTester tester) async {
    final Random random = seededRandom(97301);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatAuthor newestAuthor = pickOne(random, <ChatAuthor>[
        ChatAuthor.you,
        ChatAuthor.tool,
      ]);
      final Conversation sample = randomChatConversation(random);
      final Conversation conversation = random.nextInt(4) == 0
          ? _emptyReplyingConversation
          : _withNewestAuthor(sample, newestAuthor);

      final List<ShownChatItem> shown = await _showAtRandomSize(
        tester,
        random,
        conversation,
      );

      expect(shown.last.label, workingLineLabel);
      expect(_findWorkingLine(), findsOneWidget);
    }
  });

  testWidgets('test_is_working_before_its_next_words_property_idle_never_'
      'shows_a_working_line', (WidgetTester tester) async {
    final Random random = seededRandom(97302);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = _withActivity(
        randomChatConversation(random),
        AgentActivity.idle,
      );

      await _showAtRandomSize(tester, random, conversation);

      expect(_findWorkingLine(), findsNothing);
      expect(find.byType(BlinkingCursor), findsNothing);
    }
  });

  testWidgets('test_is_working_before_its_next_words_property_replying_'
      'agent_words_carry_the_cursor', (WidgetTester tester) async {
    final Random random = seededRandom(97303);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation sample = randomChatConversation(random);
      final Conversation conversation = _withNewestAuthor(
        sample,
        ChatAuthor.agent,
      );

      final List<ShownChatItem> shown = await _showAtRandomSize(
        tester,
        random,
        conversation,
      );

      final ShownChatItem newest = shown.last;
      final AgentMessageView newestView = newest.view as AgentMessageView;
      expect(newest.label, conversation.messages.last.text);
      expect(newestView.cursor, CursorVisibility.shown);
      expect(_findWorkingLine(), findsNothing);
    }
  });

  testWidgets('test_build_working_agent_line_property_reads_as_the_agent_'
      'with_a_cursor_and_no_words', (WidgetTester tester) async {
    final Random random = seededRandom(97304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Conversation conversation = _withNewestAuthor(
        randomShortConversation(random),
        ChatAuthor.you,
      );

      await _showAtRandomSize(tester, random, conversation);

      final Finder workingLine = _findWorkingLine();
      final Finder cursorInLine = find.descendant(
        of: workingLine,
        matching: find.byType(BlinkingCursor),
      );
      final Finder labelInLine = find.descendant(
        of: workingLine,
        matching: find.text(_agentLabel),
      );
      expect(cursorInLine, findsOneWidget);
      expect(labelInLine, findsOneWidget);
    }
  });

  testWidgets('test_build_working_agent_line_property_sits_below_every_'
      'other_item', (WidgetTester tester) async {
    final Random random = seededRandom(97305);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = _withNewestAuthor(
        randomChatConversation(random),
        ChatAuthor.tool,
      );

      final List<ShownChatItem> shown = await _showAtRandomSize(
        tester,
        random,
        conversation,
      );

      final Rect workingLine = shown.last.area;
      expect(shown.last.label, workingLineLabel);
      for (final ShownChatItem item in shown.take(shown.length - 1)) {
        expect(item.area.bottom, lessThan(workingLine.top));
      }
    }
  });

  testWidgets('test_build_working_agent_line_property_one_cursor_on_screen', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97306);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = _withNewestAuthor(
        randomChatConversation(random),
        pickOne(random, <ChatAuthor>[ChatAuthor.you, ChatAuthor.tool]),
      );

      await _showAtRandomSize(tester, random, conversation);

      final Finder cursorInLine = find.descendant(
        of: _findWorkingLine(),
        matching: find.byType(BlinkingCursor),
      );
      expect(find.byType(BlinkingCursor), findsOneWidget);
      expect(cursorInLine, findsOneWidget);
    }
  });

  testWidgets('test_build_lost_link_banner_property_title_names_the_local_'
      'clock_time', (WidgetTester tester) async {
    final Random random = seededRandom(97307);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final DateTime lostAt = randomPreciseMoment(random);
      final Conversation conversation = buildChatConversation(
        messages: const <ChatMessage>[],
        linkLostAt: lostAt,
        agentActivity: pickOne(random, AgentActivity.values),
        link: RunnerLink.unreachable,
      );

      await _showAtRandomSize(tester, random, conversation);

      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));
      expect(banner.title, matches(_bannerTitlePattern));
      expect(banner.title, endsWith(formatClockTime(lostAt)));
      expect(find.text(banner.title), findsOneWidget);
    }
  });

  testWidgets('test_build_lost_link_banner_property_body_matches_the_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97308);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Conversation sample = randomShortConversation(random);
      final DateTime lostAt = sample.linkLostAt ?? randomPreciseMoment(random);
      final Conversation conversation = buildChatConversation(
        messages: sample.messages,
        linkLostAt: lostAt,
        agentActivity: sample.agentActivity,
        link: RunnerLink.unreachable,
      );

      await _showAtRandomSize(tester, random, conversation);

      final Finder body = find.descendant(
        of: find.byType(NoticeBanner),
        matching: find.text(_bannerBody),
      );
      expect(body, findsOneWidget);
    }
  });

  testWidgets('test_build_lost_link_banner_property_one_banner_exactly_when_'
      'the_link_was_lost', (WidgetTester tester) async {
    final Random random = seededRandom(97309);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Conversation conversation = randomShortConversation(random);

      await pumpConversationView(
        tester,
        size: const Size(desktopWidth, desktopHeight),
        conversation: conversation,
        runnerName: 'mac-studio',
      );

      final bool isLinkLost = conversation.linkLostAt != null;
      final Matcher expected = isLinkLost ? findsOneWidget : findsNothing;
      expect(find.byType(NoticeBanner), expected);
    }
  });
}
