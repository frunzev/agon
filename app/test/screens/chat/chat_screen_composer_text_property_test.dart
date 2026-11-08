import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_chat.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/screens/chat/chat_composer.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import '../support/refusing_work_repositories.dart';

const ChatRoute _chatRoute = ChatRoute(GalleryRunIds.release42);
const String _sendLabel = 'Send';

final class _ChatPage {
  _ChatPage({required this.refusal, required this.chatRepository});

  final PlannedRefusal refusal;
  final RefusingChatRepository chatRepository;

  List<ChatMessage> readMessages() {
    final Conversation conversation = chatRepository.findConversation(
      GalleryRunIds.release42,
    );
    return conversation.messages;
  }
}

Future<_ChatPage> _openChat(WidgetTester tester, Random random) async {
  final AppDependencies base = buildDependenciesWithConversation(
    pickOne(random, <Conversation>[
      galleryConversationReconnecting,
      galleryConversationReplying,
    ]),
  );
  final PlannedRefusal refusal = PlannedRefusal();
  final RefusingChatRepository chatRepository = RefusingChatRepository(
    stored: base.chatRepository,
    refusal: refusal,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: randomActionWindowSize(random),
    route: _chatRoute,
    dependencies: replaceRepositories(base, chatRepository: chatRepository),
  );
  return _ChatPage(refusal: refusal, chatRepository: chatRepository);
}

Finder _findComposerField() {
  return find.descendant(
    of: find.byType(ChatComposer),
    matching: find.byType(TextField),
  );
}

String _readComposerText(WidgetTester tester) {
  return tester.widget<TextField>(_findComposerField()).controller!.text;
}

String _randomTypedMessage(Random random) {
  return '  ask ${randomWordPhrase(random)} ${randomText(random)} \n';
}

Future<void> _typeMessage(WidgetTester tester, String typedMessage) async {
  await tester.enterText(_findComposerField(), typedMessage);
  await tester.pump();
}

void main() {
  testWidgets('test_send_message_property_a_refused_message_stays_in_the_'
      'composer', (WidgetTester tester) async {
    final Random random = seededRandom(94511);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ChatPage page = await _openChat(tester, random);
      final ExplainedRefusal planned = randomExplainedRefusal(random);
      final int messageCount = page.readMessages().length;
      final String typedMessage = _randomTypedMessage(random);
      page.refusal.problem = planned.problem;

      await _typeMessage(tester, typedMessage);
      await tapButtonLabelled(tester, _sendLabel);
      expect(find.text(planned.explanation), findsOneWidget);
      await tapButtonLabelled(tester, refusalCloseLabel);

      expect(tester.takeException(), isNull);
      expect(_readComposerText(tester), typedMessage);
      expect(page.readMessages(), hasLength(messageCount));
    }
  });

  testWidgets('test_send_message_property_a_sent_message_leaves_the_'
      'composer_empty', (WidgetTester tester) async {
    final Random random = seededRandom(94512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ChatPage page = await _openChat(tester, random);
      final String typedMessage = _randomTypedMessage(random);

      await _typeMessage(tester, typedMessage);
      await tapButtonLabelled(tester, _sendLabel);

      expect(tester.takeException(), isNull);
      expect(_readComposerText(tester), isEmpty);
      expect(page.readMessages().last.text, typedMessage.trim());
      expect(page.refusal.attempts, 1);
    }
  });

  testWidgets('test_send_message_property_sending_again_after_a_refusal_'
      'sends_the_kept_text', (WidgetTester tester) async {
    final Random random = seededRandom(94513);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ChatPage page = await _openChat(tester, random);
      final String typedMessage = _randomTypedMessage(random);
      final int refusals = 1 + random.nextInt(3);

      await _typeMessage(tester, typedMessage);
      for (int refusal = 0; refusal < refusals; refusal += 1) {
        page.refusal.problem = randomExplainedRefusal(random).problem;
        await tapButtonLabelled(tester, _sendLabel);
        await tapButtonLabelled(tester, refusalCloseLabel);
      }
      page.refusal.problem = null;
      await tapButtonLabelled(tester, _sendLabel);

      expect(tester.takeException(), isNull);
      expect(page.refusal.attempts, refusals + 1);
      expect(page.readMessages().last.text, typedMessage.trim());
      expect(_readComposerText(tester), isEmpty);
    }
  });
}
