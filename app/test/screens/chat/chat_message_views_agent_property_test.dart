import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/chat/chat_message_views.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/blinking_cursor.dart';
import 'package:agent_orchestration/widgets/log_block.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_chat_conversations.dart';

const String _agentLabel = 'Agent';
const double _tolerance = 0.5;

double _randomViewWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Finder _findAgentWords() {
  return find.descendant(
    of: find.byType(AgentMessageView),
    matching: find.byType(RichText),
  );
}

Finder _findInAgentMessage(Finder matching) {
  return find.descendant(
    of: find.byType(AgentMessageView),
    matching: matching,
  );
}

Future<double> _pumpAgentMessage(
  WidgetTester tester,
  Random random,
  AgentMessageView view,
) async {
  final double width = _randomViewWidth(random);
  await pumpScrollableAtWidth(tester, width: width, child: view);
  return width;
}

void main() {
  test('test_agent_message_view_constructor_property_keeps_text_and_'
      'cursor', () {
    final Random random = seededRandom(97501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = randomChatText(random);
      final CursorVisibility cursor = pickOne(random, CursorVisibility.values);

      final AgentMessageView view = AgentMessageView(
        text: text,
        cursor: cursor,
      );

      expect(view.text, text);
      expect(view.cursor, cursor);
    }
  });

  testWidgets('test_agent_message_view_constructor_property_shows_the_'
      'agent_and_the_words', (WidgetTester tester) async {
    final Random random = seededRandom(97502);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final String text = markChatText(i, randomChatText(random));
      final AgentMessageView view = AgentMessageView(
        text: text,
        cursor: pickOne(random, CursorVisibility.values),
      );

      await _pumpAgentMessage(tester, random, view);

      final Finder words = find.textContaining(text, findRichText: true);
      expect(_findInAgentMessage(find.text(_agentLabel)), findsOneWidget);
      expect(_findInAgentMessage(words), findsWidgets);
    }
  });

  testWidgets('test_agent_message_view_constructor_property_cursor_blinks_'
      'only_when_shown', (WidgetTester tester) async {
    final Random random = seededRandom(97503);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final CursorVisibility cursor = pickOne(random, CursorVisibility.values);

      await _pumpAgentMessage(
        tester,
        random,
        AgentMessageView(text: randomChatText(random), cursor: cursor),
      );

      final bool isShown = cursor == CursorVisibility.shown;
      final Finder cursors = find.byType(BlinkingCursor);
      expect(cursors, isShown ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('test_agent_message_view_build_property_left_aligned_within_'
      'the_measure', (WidgetTester tester) async {
    final Random random = seededRandom(97504);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final AgentMessageView view = AgentMessageView(
        text: randomChatText(random),
        cursor: pickOne(random, CursorVisibility.values),
      );

      final double width = await _pumpAgentMessage(tester, random, view);

      final Rect words = tester.getRect(_findAgentWords().last);
      expect(words.left, closeTo(0, _tolerance));
      expect(words.width, lessThanOrEqualTo(AppSizes.measure + _tolerance));
      expect(words.right, lessThanOrEqualTo(width + _tolerance));
    }
  });

  testWidgets('test_agent_message_view_build_property_label_sits_above_the_'
      'words', (WidgetTester tester) async {
    final Random random = seededRandom(97505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentMessageView view = AgentMessageView(
        text: markChatText(i, randomChatText(random)),
        cursor: pickOne(random, CursorVisibility.values),
      );

      await _pumpAgentMessage(tester, random, view);

      final Rect label = tester.getRect(find.text(_agentLabel));
      final Rect words = tester.getRect(_findAgentWords().last);
      expect(label.bottom, lessThanOrEqualTo(words.top));
    }
  });

  testWidgets('test_agent_message_view_build_property_never_overflows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97506);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final String text = random.nextInt(4) == 0 ? '' : randomChatText(random);

      final double width = await _pumpAgentMessage(
        tester,
        random,
        AgentMessageView(
          text: text,
          cursor: pickOne(random, CursorVisibility.values),
        ),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });
}
