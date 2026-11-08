import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/action_refusal.dart';

import '../../support/chat_composer_harness.dart';
import '../../support/message_keys.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'support/scripted_message_sends.dart';

double _randomComposerWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

void main() {
  testWidgets('test_chat_composer_build_property_send_is_off_only_while_'
      'a_send_is_pending', (WidgetTester tester) async {
    final Random random = seededRandom(94521);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await pumpScriptedComposerAtRandomWidth(
        tester,
        random: random,
        sends: sends,
      );
      expect(isComposerSendOffered(tester), isTrue);

      await typeAndSendChatMessage(tester, randomTypedChatMessage(random));
      expect(isComposerSendOffered(tester), isFalse);
      sends.pending.single.complete(pickOne(random, ActionOutcome.values));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(isComposerSendOffered(tester), isTrue);
    }
  });

  testWidgets('test_chat_composer_build_property_enter_while_sending_sends_'
      'nothing_more', (WidgetTester tester) async {
    final Random random = seededRandom(94522);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      await pumpScriptedComposer(
        tester,
        width: desktopWidth,
        platform: pickOne(random, computerPlatformList),
        sends: sends,
      );
      final String typedMessage = randomTypedChatMessage(random);
      await tester.enterText(findComposerField(), typedMessage);
      await pressEnter(tester);
      final int extraPresses = 1 + random.nextInt(3);

      for (int press = 0; press < extraPresses; press += 1) {
        await pressEnter(tester);
      }

      expect(sends.sentMessages, <String>[typedMessage.trim()]);
      expect(readComposerText(tester), typedMessage);
      sends.pending.single.complete(ActionOutcome.done);
      await tester.pump();
      expect(readComposerText(tester), isEmpty);
    }
  });

  testWidgets('test_chat_composer_build_property_layout_holds_while_'
      'sending', (WidgetTester tester) async {
    final Random random = seededRandom(94523);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      final double width = _randomComposerWidth(random);
      await pumpScriptedComposer(
        tester,
        width: width,
        platform: pickOne(random, everyPlatformList),
        sends: sends,
      );
      await tester.enterText(findComposerField(), 'one line');
      await tester.pump();
      final Rect idleButton = tester.getRect(findComposerSendButton());

      await tester.tap(findComposerSendButton());
      await tester.pump();
      final Rect sendingButton = tester.getRect(findComposerSendButton());
      final Rect sendingField = tester.getRect(findComposerField());

      final String reason = 'width $width';
      expect(tester.takeException(), isNull, reason: reason);
      expect(sendingButton, idleButton, reason: reason);
      expect(sendingField.top, sendingButton.top, reason: reason);
      expect(sendingButton.right, lessThanOrEqualTo(width), reason: reason);
      sends.pending.single.complete(ActionOutcome.refused);
      await tester.pump();
    }
  });
}
