import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'node_shapes.dart' show NodeValueDecoder;
import 'wire_json_edits.dart';

const String _utcZoneLetter = 'Z';
const int _wholeNumberSpan = 1 << 31;
const double _fractionShift = 0.25;

enum _JsonKind { flag, whole, fraction, text, list, object }

final class WireFields {
  const WireFields({
    required this.requiredFields,
    required this.optionalFields,
    required this.defaultedListFields,
  });

  final List<String> requiredFields;
  final List<String> optionalFields;
  final List<String> defaultedListFields;

  Set<String> get everyField {
    return <String>{
      ...requiredFields,
      ...optionalFields,
      ...defaultedListFields,
    };
  }
}

void expectRequiredFieldsAreNeeded(
  JsonObject json,
  WireFields fields,
  NodeValueDecoder decode,
) {
  expect(json.keys.toSet(), equals(fields.everyField));

  for (final String field in fields.requiredFields) {
    final JsonObject shortened = removeWireField(json, field);
    final JsonObject nulled = replaceWireField(json, field, null);
    expect(() => decode(shortened), throwsFormatException, reason: field);
    expect(() => decode(nulled), throwsFormatException, reason: field);
  }
}

void expectOptionalFieldsMayBeLeftOut(
  Random random,
  JsonObject json,
  WireFields fields,
  NodeValueDecoder decode,
) {
  JsonObject shortened = json;
  final JsonObject expected = Map<String, Object?>.of(json);

  for (final String field in fields.optionalFields) {
    if (random.nextBool()) {
      shortened = removeWireField(shortened, field);
      expected[field] = null;
    }
  }

  for (final String field in fields.defaultedListFields) {
    if (random.nextBool()) {
      shortened = removeWireField(shortened, field);
      expected[field] = <Object?>[];
    }
  }

  expect(reencodeAsJsonText(decode(shortened)), equals(expected));
}

void expectWrongKindValuesAreRejected(
  Random random,
  JsonObject json,
  NodeValueDecoder decode,
) {
  for (final MapEntry<String, Object?> field in json.entries) {
    final Object? fieldValue = field.value;
    if (fieldValue == null) {
      continue;
    }

    final Object wrongValue = _buildWrongKindJson(random, fieldValue);
    final JsonObject broken = replaceWireField(json, field.key, wrongValue);
    final String reason = '${field.key} = $wrongValue';
    expect(() => decode(broken), throwsFormatException, reason: reason);

    if (fieldValue is List<Object?> && fieldValue.isNotEmpty) {
      final List<Object?> brokenList = _breakOneElement(random, fieldValue);
      final JsonObject brokenElement = replaceWireField(
        json,
        field.key,
        brokenList,
      );
      final String elementReason = '${field.key} = $brokenList';
      expect(
        () => decode(brokenElement),
        throwsFormatException,
        reason: elementReason,
      );
    }
  }
}

void expectPlainJsonThatDecodesBack(
  JsonEncodable value,
  NodeValueDecoder decode,
) {
  final Object? encoded = value.toJson();
  final Object? reread = rereadThroughWire(encoded);

  expect(reread, equals(encoded));
  expect(decode(encoded).toJson(), equals(encoded));
  expect(decode(reread).toJson(), equals(encoded));
}

void expectUtcMomentText(Object? encodedMoment, DateTime moment) {
  expect(encodedMoment, isA<String>());

  final String momentText = encodedMoment.toString();
  expect(momentText, endsWith(_utcZoneLetter));
  expect(DateTime.parse(momentText).isAtSameMomentAs(moment), isTrue);
}

void expectOptionalUtcMomentText(Object? encodedMoment, DateTime? moment) {
  if (moment == null) {
    expect(encodedMoment, isNull);
    return;
  }
  expectUtcMomentText(encodedMoment, moment);
}

void expectSameMoment(DateTime? decodedMoment, Object? momentText) {
  if (momentText == null) {
    expect(decodedMoment, isNull);
    return;
  }

  final DateTime expectedMoment = DateTime.parse(momentText.toString());
  expect(decodedMoment, isNotNull);
  expect(decodedMoment!.isUtc, isTrue);
  expect(decodedMoment.isAtSameMomentAs(expectedMoment), isTrue);
}

List<Object?> _breakOneElement(Random random, List<Object?> elements) {
  final List<Object?> broken = List<Object?>.of(elements);
  final int index = random.nextInt(elements.length);
  final Object? element = elements[index];

  if (element != null) {
    broken[index] = _buildWrongKindJson(random, element);
  }

  return broken;
}

Object _buildWrongKindJson(Random random, Object fieldValue) {
  final List<Object> candidates = <Object>[
    random.nextBool(),
    random.nextInt(_wholeNumberSpan) - _wholeNumberSpan ~/ 2,
    random.nextDouble() + _fractionShift,
    randomText(random),
    <Object?>[randomText(random)],
    <String, Object?>{randomText(random): randomText(random)},
  ];
  final _JsonKind fieldKind = _classifyJson(fieldValue);

  final List<Object> otherKinds = <Object>[];
  for (final Object candidate in candidates) {
    if (_classifyJson(candidate) != fieldKind) {
      otherKinds.add(candidate);
    }
  }

  return pickOne(random, otherKinds);
}

_JsonKind _classifyJson(Object json) {
  return switch (json) {
    bool() => _JsonKind.flag,
    int() => _JsonKind.whole,
    double() => _JsonKind.fraction,
    String() => _JsonKind.text,
    List<Object?>() => _JsonKind.list,
    _ => _JsonKind.object,
  };
}
