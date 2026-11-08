import 'dart:convert';
import 'dart:math';

import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import 'arbitrary_json.dart';

const String _unknownFieldPrefix = 'field_the_app_does_not_know_';
const int _largestUnknownFieldCount = 4;

Object? rereadThroughWire(Object? json) => jsonDecode(jsonEncode(json));

Object? reencodeAsJsonText(JsonEncodable value) {
  return rereadThroughWire(value.toJson());
}

JsonObject removeWireField(JsonObject json, String field) {
  final JsonObject shortened = Map<String, Object?>.of(json);
  shortened.remove(field);
  return shortened;
}

JsonObject replaceWireField(JsonObject json, String field, Object? value) {
  return <String, Object?>{...json, field: value};
}

JsonObject addUnknownWireFields(Random random, JsonObject json) {
  final JsonObject widened = Map<String, Object?>.of(json);
  final int unknownFieldCount = 1 + random.nextInt(_largestUnknownFieldCount);

  for (int i = 0; i < unknownFieldCount; i += 1) {
    final String field = '$_unknownFieldPrefix$i${randomText(random)}';
    widened[field] = randomArbitraryJson(random);
  }

  return widened;
}
