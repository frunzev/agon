import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/chat/chat_composer.dart';
import 'package:agent_orchestration/screens/chat/chat_context_panel.dart';
import 'package:agent_orchestration/screens/chat/chat_page_layout.dart';
import 'package:agent_orchestration/screens/chat/conversation_view.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/theme/layout_size.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/random_inputs.dart';
import 'support/random_chat_conversations.dart';
import 'support/random_chat_page_layouts.dart';
import 'support/scripted_message_sends.dart';

const String _messageHint = 'Message the agent';
const String _openRunLabel = 'Open run';
const Rect _landscapePhones = Rect.fromLTRB(568, 320, 932, 430);
const Rect _phonesWithKeyboardOpen = Rect.fromLTRB(320, 360, 430, 520);

Size _randomSizeWithin(Random random, Rect sizes) {
  final double width = sizes.left + random.nextDouble() * sizes.width;
  final double height = sizes.top + random.nextDouble() * sizes.height;
  return Size(width, height);
}

Size _randomPageSize(Random random) {
  final int choice = random.nextInt(3);
  if (choice == 0) {
    return _randomSizeWithin(random, _landscapePhones);
  }
  if (choice == 1) {
    return _randomSizeWithin(random, _phonesWithKeyboardOpen);
  }
  return randomChatWindowSize(random);
}

Finder _findInHeader(Finder matching) {
  return find.descendant(of: find.byType(PageHeader), matching: matching);
}

void main() {
  test('test_chat_page_layout_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(97901);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ChatPageLayout sample = buildRandomChatPageLayout(
        random,
        onBack: ignoreGoingBack,
        onSend: acceptEveryMessage,
      );

      final ChatPageLayout layout = ChatPageLayout(
        runContext: sample.runContext,
        conversation: sample.conversation,
        runner: sample.runner,
        thisDevice: sample.thisDevice,
        onBack: sample.onBack,
        onSend: sample.onSend,
      );

      expect(identical(layout.runContext, sample.runContext), isTrue);
      expect(identical(layout.conversation, sample.conversation), isTrue);
      expect(identical(layout.runner, sample.runner), isTrue);
      expect(identical(layout.thisDevice, sample.thisDevice), isTrue);
      expect(layout.onBack, ignoreGoingBack);
      expect(layout.onSend, acceptEveryMessage);
    }
  });

  testWidgets('test_chat_page_layout_constructor_property_back_link_and_'
      'open_run_go_back', (WidgetTester tester) async {
    final Random random = seededRandom(97902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      int backs = 0;
      final Size size = randomChatWindowSize(random);
      final ChatPageLayout layout = buildRandomChatPageLayout(
        random,
        onBack: () => backs += 1,
        onSend: acceptEveryMessage,
      );
      final bool isLarge = LayoutSize.forWidth(size.width).isLarge;
      await pumpChatWidget(tester, size: size, child: layout);

      await tester.tap(find.byType(BackLinkButton));
      await tester.pump();
      if (isLarge) {
        await tester.ensureVisible(find.text(_openRunLabel));
        await tester.tap(find.text(_openRunLabel));
        await tester.pump();
      }

      expect(backs, isLarge ? 2 : 1, reason: 'size $size');
    }
  });

  testWidgets('test_chat_page_layout_constructor_property_composer_sends_'
      'through_on_send', (WidgetTester tester) async {
    final Random random = seededRandom(97903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedMessageSends sends = ScriptedMessageSends();
      final ChatPageLayout layout = buildRandomChatPageLayout(
        random,
        onBack: ignoreGoingBack,
        onSend: sends.send,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await pumpChatWidget(
        tester,
        size: randomChatWindowSize(random),
        child: layout,
      );
      final String typedMessage = randomTypedChatMessage(random);

      await typeAndSendChatMessage(tester, typedMessage);
      sends.pending.single.complete(ActionOutcome.done);
      await tester.pump();

      expect(sends.sentMessages, <String>[typedMessage.trim()]);
      expect(readComposerText(tester), isEmpty);
    }
  });

  testWidgets('test_chat_page_layout_build_property_never_overflows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(97904);

    for (int i = 0; i < widgetPropertyIterations * 3; i += 1) {
      final Size size = _randomPageSize(random);

      await pumpChatWidget(
        tester,
        size: size,
        child: buildRandomChatPageLayout(
          random,
          onBack: ignoreGoingBack,
          onSend: acceptEveryMessage,
        ),
      );

      final Rect composer = tester.getRect(find.byType(ChatComposer));
      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(composer.bottom, lessThanOrEqualTo(size.height));
      expect(composer.top, greaterThanOrEqualTo(0));
    }
  });

  testWidgets('test_chat_page_layout_build_property_context_panel_only_on_'
      'large_windows', (WidgetTester tester) async {
    final Random random = seededRandom(97905);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final Size size = randomChatWindowSize(random);

      await pumpChatWidget(
        tester,
        size: size,
        child: buildRandomChatPageLayout(
          random,
          onBack: ignoreGoingBack,
          onSend: acceptEveryMessage,
        ),
      );

      final bool isLarge = size.width >= LayoutSize.largeMinimumWidth;
      final Matcher expected = isLarge ? findsOneWidget : findsNothing;
      expect(find.byType(ChatContextPanel), expected, reason: 'size $size');
      if (isLarge) {
        final Rect panel = tester.getRect(find.byType(ChatContextPanel));
        final Rect chat = tester.getRect(find.byType(ConversationView));
        expect(chat.right, lessThanOrEqualTo(panel.left));
      }
    }
  });

  testWidgets('test_chat_page_layout_build_property_header_names_agent_'
      'step_and_run', (WidgetTester tester) async {
    final Random random = seededRandom(97906);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final ChatPageLayout layout = buildRandomChatPageLayout(
        random,
        onBack: ignoreGoingBack,
        onSend: acceptEveryMessage,
      );

      await pumpChatWidget(
        tester,
        size: randomChatWindowSize(random),
        child: layout,
      );

      final PageHeader header = tester.widget(find.byType(PageHeader));
      final Finder runLabel = find.text(layout.runContext.runLabel);
      expect(header.title, layout.runContext.agentTitle);
      expect(joinTextSegments(header.summary), layout.runContext.agentSummary);
      expect(_findInHeader(runLabel), findsOneWidget);
      expect(find.text(_messageHint), findsOneWidget);
    }
  });
}
