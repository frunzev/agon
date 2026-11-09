import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/chat/chat_message_views.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../bridge/support/random_moments.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/random_chat_conversations.dart';

const double _userWidthShare = 0.85;
const double _tolerance = 0.5;

double _randomViewWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Finder _findInUserMessage(Finder matching) {
  return find.descendant(of: find.byType(UserMessageView), matching: matching);
}

ChatMessage _randomUserMessage(Random random, {required String text}) {
  return ChatMessage(
    at: randomPreciseMoment(random),
    author: ChatAuthor.you,
    text: text,
    isError: random.nextBool(),
    waitingToSend: random.nextBool(),
  );
}

String _describeWaiting(String runnerName) => 'Sends when $runnerName is back';

Future<double> _pumpUserMessage(
  WidgetTester tester,
  Random random, {
  required ChatMessage message,
  required String runnerName,
}) async {
  final double width = _randomViewWidth(random);
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: UserMessageView(
      message: message,
      runnerName: runnerName,
      availableWidth: width,
    ),
  );
  return width;
}

Rect _readBubble(WidgetTester tester) {
  return tester.getRect(_findInUserMessage(find.byType(Container)).first);
}

void main() {
  test('test_user_message_view_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(97507);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatMessage message = _randomUserMessage(
        random,
        text: randomChatText(random),
      );
      final String runnerName = randomChatText(random);
      final double availableWidth = _randomViewWidth(random);

      final UserMessageView view = UserMessageView(
        message: message,
        runnerName: runnerName,
        availableWidth: availableWidth,
      );

      expect(identical(view.message, message), isTrue);
      expect(view.runnerName, runnerName);
      expect(view.availableWidth, availableWidth);
    }
  });

  testWidgets('test_user_message_view_constructor_property_shows_exactly_'
      'the_message_text', (WidgetTester tester) async {
    final Random random = seededRandom(97508);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatMessage message = _randomUserMessage(
        random,
        text: markChatText(i, randomChatText(random)),
      );

      await _pumpUserMessage(
        tester,
        random,
        message: message,
        runnerName: 'mac-studio',
      );

      expect(_findInUserMessage(find.text(message.text)), findsOneWidget);
    }
  });

  testWidgets('test_user_message_view_constructor_property_waiting_names_'
      'the_given_runner', (WidgetTester tester) async {
    final Random random = seededRandom(97509);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatMessage message = _randomUserMessage(
        random,
        text: markChatText(i, randomChatText(random)),
      );
      final String runnerName = 'runner ${randomChatText(random)}';

      await _pumpUserMessage(
        tester,
        random,
        message: message,
        runnerName: runnerName,
      );

      final Finder waiting = find.text(_describeWaiting(runnerName));
      expect(waiting, message.waitingToSend ? findsOneWidget : findsNothing);
    }
  });

  testWidgets('test_user_message_view_build_property_bubble_hugs_the_right_'
      'edge', (WidgetTester tester) async {
    final Random random = seededRandom(97510);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final double width = await _pumpUserMessage(
        tester,
        random,
        message: _randomUserMessage(random, text: randomChatText(random)),
        runnerName: randomChatText(random),
      );

      final Rect bubble = _readBubble(tester);
      expect(bubble.right, closeTo(width, _tolerance));
      expect(bubble.left, greaterThanOrEqualTo(-_tolerance));
    }
  });

  testWidgets('test_user_message_view_build_property_bubble_never_exceeds_'
      'its_share', (WidgetTester tester) async {
    final Random random = seededRandom(97511);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final double width = await _pumpUserMessage(
        tester,
        random,
        message: _randomUserMessage(random, text: randomChatText(random)),
        runnerName: randomChatText(random),
      );

      final double share = min(AppSizes.measure, width * _userWidthShare);
      final Rect bubble = _readBubble(tester);
      expect(bubble.width, lessThanOrEqualTo(share + _tolerance));
    }
  });

  testWidgets('test_user_message_view_build_property_waiting_label_stays_'
      'inside_the_bubble', (WidgetTester tester) async {
    final Random random = seededRandom(97512);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatMessage message = ChatMessage(
        at: randomPreciseMoment(random),
        author: ChatAuthor.you,
        text: randomChatText(random),
        isError: false,
        waitingToSend: true,
      );
      final String runnerName = randomChatText(random);

      final double width = await _pumpUserMessage(
        tester,
        random,
        message: message,
        runnerName: runnerName,
      );

      final Rect bubble = _readBubble(tester);
      final Rect label = tester.getRect(
        find.text(_describeWaiting(runnerName)),
      );
      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(bubble.contains(label.topLeft), isTrue);
      expect(label.right, lessThanOrEqualTo(bubble.right + _tolerance));
      expect(label.bottom, lessThanOrEqualTo(bubble.bottom + _tolerance));
    }
  });
}
