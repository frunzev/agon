import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/conversation.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/run.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/record_not_found.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

import '../../support/random_inputs.dart';
import 'support/chat_contract_rigs.dart';
import 'support/contract_step_failures.dart';

const String _typePrefix = 'test_chat_repository';
const int _worldIterations = 25;
const int _longestSequence = 6;

typedef _SendOutcome = ({
  String name,
  Object? failure,
  MessageProjection? sent,
});

String _randomMessage(Random random) {
  if (random.nextInt(4) == 0) {
    return randomBlankMessage(random);
  }
  return randomPaddedMessage(random);
}

Future<List<_SendOutcome>> _sendOnEvery(
  List<NamedChatRepository> implementations, {
  required RunId runId,
  required String text,
}) async {
  final List<_SendOutcome> outcomes = <_SendOutcome>[];
  for (final NamedChatRepository implementation in implementations) {
    MessageProjection? sent;
    final Object? failure = await findStepFailure(() async {
      final ChatMessage message = await implementation.repository.sendMessage(
        runId,
        text,
      );
      sent = projectMessage(message);
    });
    outcomes.add((name: implementation.name, failure: failure, sent: sent));
  }
  return outcomes;
}

List<MessageProjection>? _readMessages(
  NamedChatRepository implementation,
  RunId runId,
) {
  try {
    return projectMessages(
      implementation.repository.findConversation(runId).messages,
    );
  } on RecordNotFound {
    return null;
  }
}

Future<void> _sendRandomlyOnEvery(
  Random random,
  ChatContractWorld world,
) async {
  await _sendOnEvery(
    world.implementations,
    runId: pickRunId(random, world.runIds),
    text: _randomMessage(random),
  );
}

void main() {
  test('${_typePrefix}_send_message_property_keeps_the_text_without_'
      'unicode_white_space_edges', () async {
    final Random random = seededRandom(84401);
    for (int i = 0; i < _worldIterations; i += 1) {
      final ChatContractWorld world = await buildEveryChatRepository(random);
      if (world.runIds.isEmpty) {
        continue;
      }
      final String text = randomPaddedMessage(random);
      final RunId runId = pickOne(random, world.runIds);

      final List<_SendOutcome> outcomes = await _sendOnEvery(
        world.implementations,
        runId: runId,
        text: text,
      );

      final String expectedText = trimUnicodeWhiteSpace(text);
      for (final _SendOutcome outcome in outcomes) {
        if (expectedText.isEmpty) {
          expect(
            outcome.failure,
            isA<PeopleFacingRefusal>(),
            reason: outcome.name,
          );
          continue;
        }
        expect(outcome.failure, isNull, reason: outcome.name);
        expect(outcome.sent, (
          author: ChatAuthor.you,
          text: expectedText,
          isError: false,
        ), reason: outcome.name);
      }
    }
  });

  test('${_typePrefix}_send_message_property_blank_texts_are_refused_and_'
      'nothing_is_added', () async {
    final Random random = seededRandom(84402);
    for (int i = 0; i < _worldIterations; i += 1) {
      final ChatContractWorld world = await buildEveryChatRepository(random);
      final RunId runId = pickRunId(random, world.runIds);
      final List<List<MessageProjection>?> before = <List<MessageProjection>?>[
        for (final NamedChatRepository implementation in world.implementations)
          _readMessages(implementation, runId),
      ];

      final List<_SendOutcome> outcomes = await _sendOnEvery(
        world.implementations,
        runId: runId,
        text: randomBlankMessage(random),
      );

      for (int index = 0; index < outcomes.length; index += 1) {
        expect(outcomes[index].failure, isA<PeopleFacingRefusal>());
        expect(
          _readMessages(world.implementations[index], runId),
          before[index],
          reason: outcomes[index].name,
        );
      }
    }
  });

  test('${_typePrefix}_send_message_property_unknown_runs_are_refused_by_'
      'every_implementation', () async {
    final Random random = seededRandom(84403);
    for (int i = 0; i < _worldIterations; i += 1) {
      final ChatContractWorld world = await buildEveryChatRepository(random);
      final RunId missing = pickRunId(random, const <RunId>[]);

      final List<_SendOutcome> outcomes = await _sendOnEvery(
        world.implementations,
        runId: missing,
        text: 'hello ${randomWordPhrase(random)}',
      );

      for (final _SendOutcome outcome in outcomes) {
        expect(outcome.failure, isA<RecordNotFound>(), reason: outcome.name);
        final RecordNotFound notFound = outcome.failure! as RecordNotFound;
        expect(notFound.identifier, missing.value, reason: outcome.name);
      }
    }
  });

  test('${_typePrefix}_send_message_property_the_sent_message_ends_the_'
      'conversation', () async {
    final Random random = seededRandom(84404);
    for (int i = 0; i < _worldIterations; i += 1) {
      final ChatContractWorld world = await buildEveryChatRepository(random);
      if (world.runIds.isEmpty) {
        continue;
      }
      final RunId runId = pickOne(random, world.runIds);

      final List<_SendOutcome> outcomes = await _sendOnEvery(
        world.implementations,
        runId: runId,
        text: 'note ${randomPaddedMessage(random)}',
      );

      for (int index = 0; index < outcomes.length; index += 1) {
        final List<MessageProjection> messages = _readMessages(
          world.implementations[index],
          runId,
        )!;
        expect(
          messages.last,
          outcomes[index].sent,
          reason: outcomes[index].name,
        );
      }
    }
  });

  test('${_typePrefix}_find_conversation_property_every_implementation_'
      'shows_the_same_messages', () async {
    final Random random = seededRandom(84405);
    for (int i = 0; i < _worldIterations; i += 1) {
      final ChatContractWorld world = await buildEveryChatRepository(random);
      final int stepCount = random.nextInt(_longestSequence);
      for (int step = 0; step < stepCount; step += 1) {
        await _sendRandomlyOnEvery(random, world);
      }

      for (final RunId runId in world.runIds) {
        final List<MessageProjection>? expected = _readMessages(
          world.implementations.first,
          runId,
        );
        for (final NamedChatRepository implementation
            in world.implementations) {
          expect(
            _readMessages(implementation, runId),
            expected,
            reason: implementation.name,
          );
        }
      }
    }
  });

  test('${_typePrefix}_find_conversation_property_unknown_runs_are_not_'
      'found', () async {
    final Random random = seededRandom(84406);
    for (int i = 0; i < _worldIterations; i += 1) {
      final ChatContractWorld world = await buildEveryChatRepository(random);
      final RunId missing = RunId('absent ${randomText(random)}');

      for (final NamedChatRepository implementation in world.implementations) {
        final Object? failure = await findStepFailure(
          () async => implementation.repository.findConversation(missing),
        );

        expect(failure, isA<RecordNotFound>(), reason: implementation.name);
        expect((failure! as RecordNotFound).identifier, missing.value);
      }
    }
  });

  test('${_typePrefix}_find_conversation_property_sending_only_appends_'
      'and_keeps_the_run', () async {
    final Random random = seededRandom(84407);
    for (int i = 0; i < _worldIterations; i += 1) {
      final ChatContractWorld world = await buildEveryChatRepository(random);
      if (world.runIds.isEmpty) {
        continue;
      }
      final RunId runId = pickOne(random, world.runIds);

      for (final NamedChatRepository implementation in world.implementations) {
        final Conversation before = implementation.repository.findConversation(
          runId,
        );
        final int stepCount = 1 + random.nextInt(_longestSequence);
        for (int step = 0; step < stepCount; step += 1) {
          await findStepFailure(
            () => implementation.repository.sendMessage(
              runId,
              _randomMessage(random),
            ),
          );
        }
        final Conversation after = implementation.repository.findConversation(
          runId,
        );

        expect(after.runId, runId, reason: implementation.name);
        expect(
          projectMessages(after.messages).take(before.messages.length),
          orderedEquals(projectMessages(before.messages)),
          reason: implementation.name,
        );
      }
    }
  });
}
