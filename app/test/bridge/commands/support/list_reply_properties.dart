import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../../support/random_inputs.dart';
import '../../support/command_shape.dart';
import '../../support/list_copy_properties.dart';
import '../../support/wire_json_edits.dart';
import 'command_reply_properties.dart';

const int _largestReplyLength = 6;

void testListReplyRows(List<ReplyRow> rows, int firstSeed) {
  for (int i = 0; i < rows.length; i += 1) {
    _testListReplyProperties(rows[i], firstSeed + i * seedsPerReplyRow);
  }
}

List<Object?> _randomElementJsons(Random random, ReplyRow row) {
  final int elementCount = random.nextInt(_largestReplyLength);
  final List<Object?> elementJsons = <Object?>[];
  for (int i = 0; i < elementCount; i += 1) {
    elementJsons.add(row.buildObjectJson(random));
  }
  if (elementJsons.isNotEmpty && random.nextBool()) {
    final Object? repeatedElement = pickOne(random, elementJsons);
    elementJsons.insert(random.nextInt(elementCount + 1), repeatedElement);
  }
  return elementJsons;
}

void _testListReplyProperties(ReplyRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_decode_reply_property';
  final CommandShape shape = findCommandShape(row.commandName);

  test('${testPrefix}_keeps_every_element_in_order', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final List<Object?> replyJson = _randomElementJsons(random, row);

      final Object? reencoded = reencodeReply(
        shape: shape,
        command: command,
        replyJson: rereadThroughWire(replyJson),
      );

      expect(reencoded, equals(replyJson));
    }
  });

  test('${testPrefix}_rejects_one_broken_element', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final List<Object?> replyJson = <Object?>[
        row.buildObjectJson(random),
        ..._randomElementJsons(random, row),
      ];
      final JsonObject brokenElement = removeWireField(
        row.buildObjectJson(random),
        pickOne(random, row.requiredFields),
      );
      final List<Object?> brokenElements = <Object?>[brokenElement, null];
      final int brokenIndex = random.nextInt(replyJson.length);
      replyJson[brokenIndex] = pickOne(random, brokenElements);

      expect(() => command.decodeReply(replyJson), throwsFormatException);
    }
  });

  test('${testPrefix}_rejects_replies_that_are_not_lists', () {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject elementJson = row.buildObjectJson(random);
      final List<Object?> notLists = <Object?>[elementJson];
      for (final Object? reply in listRepliesOfAnotherKind(
        random,
        elementJson,
      )) {
        if (reply is! List<Object?>) {
          notLists.add(reply);
        }
      }
      final Object? replyJson = pickOne(random, notLists);

      expect(
        () => command.decodeReply(replyJson),
        throwsFormatException,
        reason: '$replyJson',
      );
    }
  });

  test('${testPrefix}_cannot_be_changed', () {
    final Random random = seededRandom(seed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final List<Object?> replyJson = _randomElementJsons(random, row);
      final Object? decodedReply = command.decodeReply(replyJson);
      final List<Object?> decodedElements = decodedReply! as List<Object?>;
      final Object? extraReply = command.decodeReply(<Object?>[
        row.buildObjectJson(random),
      ]);
      final List<Object?> extraElements = extraReply! as List<Object?>;

      expectListRefusesChanges(decodedElements, extraElements.single);
      expect(decodedElements, hasLength(replyJson.length));
    }
  });
}
