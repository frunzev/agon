import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';
import 'package:agent_orchestration/bridge/commands/node_command.dart';

import '../../../support/random_inputs.dart';
import '../../support/all_command_shapes.dart';
import '../../support/arbitrary_json.dart';
import '../../support/command_shape.dart';
import '../../support/decoding_outcome.dart';
import '../../support/hostile_texts.dart';
import '../../support/node_json_primitives.dart';
import '../../support/wire_json_edits.dart';
import 'modelled_command_properties.dart';

typedef ReplyObjectBuilder = JsonObject Function(Random random);

const int seedsPerReplyRow = 10;
const int _wholeNumberSpan = 1 << 31;
const String _wrappingField = 'items';

final class ReplyRow {
  const ReplyRow({
    required this.typeName,
    required this.commandName,
    required this.buildObjectJson,
    required this.requiredFields,
  });

  final String typeName;
  final String commandName;
  final ReplyObjectBuilder buildObjectJson;
  final List<String> requiredFields;
}

CommandShape findCommandShape(String commandName) {
  for (final CommandShape shape in allCommandShapes) {
    if (shape.commandName == commandName) {
      return shape;
    }
  }
  throw StateError('no command shape for $commandName');
}

List<Object?> listRepliesOfAnotherKind(Random random, Object? replyJson) {
  return <Object?>[
    null,
    randomHostileText(random),
    random.nextInt(_wholeNumberSpan),
    random.nextDouble(),
    random.nextBool(),
    <Object?>[replyJson],
    <String, Object?>{_wrappingField: replyJson},
  ];
}

Object? reencodeReply({
  required CommandShape shape,
  required NodeCommand<Object?> command,
  required Object? replyJson,
}) {
  final Object? decodedReply = command.decodeReply(replyJson);
  return rereadThroughWire(shape.encodeReply(decodedReply));
}

void _testReplyRoundTripProperty({
  required String typeName,
  required CommandShape shape,
  required NodeJsonBuilder buildReplyJson,
  required int seed,
}) {
  test(
    'test_${typeName}_decode_reply_property_round_trips_the_node_reply',
    () {
      final Random random = seededRandom(seed);

      for (int i = 0; i < propertyIterations; i += 1) {
        final NodeCommand<Object?> command = shape.buildCommand(random);
        final Object? replyJson = buildReplyJson(random);

        final Object? reencoded = reencodeReply(
          shape: shape,
          command: command,
          replyJson: rereadThroughWire(replyJson),
        );

        expect(reencoded, equals(replyJson));
      }
    },
  );
}

void _testHostileReplyProperty({
  required String typeName,
  required CommandShape shape,
  required NodeJsonBuilder buildReplyJson,
  required int seed,
}) {
  test('test_${typeName}_decode_reply_property_'
      'hostile_replies_raise_only_format_errors', () {
    final Random random = seededRandom(seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final Object? mutatedReply = mutateJson(random, buildReplyJson(random));

      final DecodingOutcome outcome = attemptDecoding(
        () => command.decodeReply(mutatedReply),
      );

      if (outcome == DecodingOutcome.decoded) {
        final Object? encodedOnce = reencodeReply(
          shape: shape,
          command: command,
          replyJson: mutatedReply,
        );
        final Object? encodedTwice = reencodeReply(
          shape: shape,
          command: shape.buildCommand(random),
          replyJson: encodedOnce,
        );
        expect(encodedTwice, equals(encodedOnce));
      }
    }
  });
}

void testCommandReplyRows(List<ModelledCommandRow> rows, int firstSeed) {
  for (int i = 0; i < rows.length; i += 1) {
    final int seed = firstSeed + i * seedsPerReplyRow;
    final CommandShape shape = findCommandShape(rows[i].commandName);
    _testShapeReplyProperties(rows[i].typeName, shape, seed);
  }
}

void testObjectReplyRows(List<ReplyRow> rows, int firstSeed) {
  for (int i = 0; i < rows.length; i += 1) {
    _testObjectReplyProperties(rows[i], firstSeed + i * seedsPerReplyRow);
  }
}

void _testShapeReplyProperties(String typeName, CommandShape shape, int seed) {
  final String testPrefix = 'test_${typeName}_decode_reply_property';

  _testReplyRoundTripProperty(
    typeName: typeName,
    shape: shape,
    buildReplyJson: shape.buildReplyJson,
    seed: seed,
  );

  test('${testPrefix}_needs_every_reply_field', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = decodeObject(shape.buildReplyJson(random));
      final List<Object?> nonObjectReplies = <Object?>[];
      for (final Object? reply in listRepliesOfAnotherKind(
        random,
        replyJson,
      )) {
        if (reply is! JsonObject) {
          nonObjectReplies.add(reply);
        }
      }
      final Object? nonObjectReply = pickOne(random, nonObjectReplies);

      for (final String field in replyJson.keys) {
        final JsonObject shortened = removeWireField(replyJson, field);
        expect(
          () => command.decodeReply(shortened),
          throwsFormatException,
          reason: field,
        );
      }
      expect(
        () => command.decodeReply(nonObjectReply),
        throwsFormatException,
        reason: '$nonObjectReply',
      );
    }
  });

  _testHostileReplyProperty(
    typeName: typeName,
    shape: shape,
    buildReplyJson: shape.buildReplyJson,
    seed: seed + 2,
  );

  test('${testPrefix}_ignores_the_command_fields', () {
    final Random random = seededRandom(seed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> first = shape.buildCommand(random);
      final NodeCommand<Object?> second = shape.buildCommand(random);
      final Object? replyJson = shape.buildReplyJson(random);

      expect(
        jsonEncode(shape.encodeReply(second.decodeReply(replyJson))),
        jsonEncode(shape.encodeReply(first.decodeReply(replyJson))),
      );
    }
  });
}

void _testObjectReplyProperties(ReplyRow row, int seed) {
  final String testPrefix = 'test_${row.typeName}_decode_reply_property';
  final CommandShape shape = findCommandShape(row.commandName);

  _testReplyRoundTripProperty(
    typeName: row.typeName,
    shape: shape,
    buildReplyJson: row.buildObjectJson,
    seed: seed,
  );

  test('${testPrefix}_rejects_a_missing_or_wrong_kind_reply', () {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final NodeCommand<Object?> command = shape.buildCommand(random);
      final JsonObject replyJson = row.buildObjectJson(random);
      final Object? wrongKindReply = pickOne(
        random,
        listRepliesOfAnotherKind(random, replyJson),
      );

      for (final String field in row.requiredFields) {
        final JsonObject shortened = removeWireField(replyJson, field);
        final JsonObject nulled = replaceWireField(replyJson, field, null);
        expect(() => command.decodeReply(shortened), throwsFormatException);
        expect(() => command.decodeReply(nulled), throwsFormatException);
      }
      expect(
        () => command.decodeReply(wrongKindReply),
        throwsFormatException,
        reason: '$wrongKindReply',
      );
    }
  });

  _testHostileReplyProperty(
    typeName: row.typeName,
    shape: shape,
    buildReplyJson: row.buildObjectJson,
    seed: seed + 2,
  );
}
