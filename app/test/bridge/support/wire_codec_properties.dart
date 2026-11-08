import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'node_shapes.dart' show NodeValueDecoder;
import 'wire_contract_checks.dart';
import 'wire_json_edits.dart';

typedef WireJsonBuilder = JsonObject Function(Random random);

const int _largestWholeNumber = 1 << 31;

final class WireCodec {
  const WireCodec({
    required this.typeName,
    required this.seed,
    required this.buildJson,
    required this.decode,
    required this.requiredFields,
    required this.optionalFields,
  });

  final String typeName;
  final int seed;
  final WireJsonBuilder buildJson;
  final NodeValueDecoder decode;
  final Set<String> requiredFields;
  final Set<String> optionalFields;

  WireFields get fields {
    return WireFields(
      requiredFields: requiredFields.toList(),
      optionalFields: optionalFields.toList(),
      defaultedListFields: const <String>[],
    );
  }
}

void testWireDecodingProperties(WireCodec codec) {
  test('test_${codec.typeName}_from_json_property_'
      'needs_every_required_field', () {
    final Random random = seededRandom(codec.seed);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = codec.buildJson(random);

      expectRequiredFieldsAreNeeded(wireJson, codec.fields, codec.decode);
    }
  });

  test('test_${codec.typeName}_from_json_property_'
      'optional_fields_may_be_left_out', () {
    final Random random = seededRandom(codec.seed + 1);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = codec.buildJson(random);

      expectOptionalFieldsMayBeLeftOut(
        random,
        wireJson,
        codec.fields,
        codec.decode,
      );
    }
  });

  test('test_${codec.typeName}_from_json_property_ignores_unknown_fields', () {
    final Random random = seededRandom(codec.seed + 2);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = codec.buildJson(random);
      final JsonObject widenedJson = addUnknownWireFields(random, wireJson);

      final JsonEncodable decoded = codec.decode(widenedJson);

      expect(reencodeAsJsonText(decoded), equals(wireJson));
    }
  });

  test('test_${codec.typeName}_from_json_property_'
      'rejects_wrongly_typed_fields', () {
    final Random random = seededRandom(codec.seed + 3);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = codec.buildJson(random);

      expectWrongKindValuesAreRejected(random, wireJson, codec.decode);
    }
  });

  test('test_${codec.typeName}_from_json_property_'
      'rejects_non_object_json', () {
    final Random random = seededRandom(codec.seed + 4);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Object?> nonObjects = <Object?>[
        null,
        random.nextBool(),
        random.nextInt(_largestWholeNumber),
        random.nextDouble(),
        randomText(random),
        jsonEncode(codec.buildJson(random)),
        <Object?>[codec.buildJson(random)],
      ];
      final Object? nonObjectJson = pickOne(random, nonObjects);

      expect(() => codec.decode(nonObjectJson), throwsFormatException);
    }
  });
}

void testWireEncodingProperties(WireCodec codec) {
  test('test_${codec.typeName}_to_json_property_'
      'is_plain_json_that_decodes_back', () {
    final Random random = seededRandom(codec.seed + 5);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonEncodable value = codec.decode(codec.buildJson(random));

      expectPlainJsonThatDecodesBack(value, codec.decode);
    }
  });

  test('test_${codec.typeName}_to_json_property_'
      'reproduces_the_node_json', () {
    final Random random = seededRandom(codec.seed + 6);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject wireJson = codec.buildJson(random);

      final JsonEncodable decoded = codec.decode(wireJson);

      expect(reencodeAsJsonText(decoded), equals(wireJson));
    }
  });

  test('test_${codec.typeName}_to_json_property_writes_every_node_field', () {
    final Random random = seededRandom(codec.seed + 7);

    for (int i = 0; i < propertyIterations; i += 1) {
      JsonObject requiredJson = codec.buildJson(random);
      for (final String optionalField in codec.optionalFields) {
        requiredJson = removeWireField(requiredJson, optionalField);
      }

      final JsonEncodable decoded = codec.decode(requiredJson);
      final JsonObject encoded = decodeObject(decoded.toJson());

      expect(encoded.keys.toSet(), equals(codec.fields.everyField));
      for (final String optionalField in codec.optionalFields) {
        expect(encoded[optionalField], isNull, reason: optionalField);
      }
    }
  });
}
