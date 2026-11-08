import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/hostile_texts.dart';
import '../support/node_wire_names.dart';
import '../support/random_account_json.dart';
import '../support/wire_json_edits.dart';

const String _kindField = 'hosting_problem_kind';
const String _problemField = 'hosting_problem';
final RegExp _snakeCase = RegExp(r'^[a-z]+(_[a-z]+)*$');

JsonObject _statusJsonWithKind(Random random, Object? kind) {
  final JsonObject withProblem = replaceWireField(
    randomStatusViewJson(random),
    _problemField,
    randomText(random),
  );
  return replaceWireField(withProblem, _kindField, kind);
}

String _randomUnknownKindName(Random random) {
  String candidate = randomHostileText(random);
  while (nodeHostingProblemKinds.contains(candidate)) {
    candidate = randomHostileText(random);
  }
  return candidate;
}

void main() {
  test('test_hosting_problem_kind_decode_property_round_trips_every_'
      'wire_name', () {
    final Random random = seededRandom(95101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final HostingProblemKind kind = pickOne(
        random,
        HostingProblemKind.values,
      );

      final HostingProblemKind decoded = HostingProblemKind.decode(
        rereadThroughWire(kind.wireName),
      );

      expect(decoded, kind);
    }
  });

  test('test_hosting_problem_kind_decode_property_rejects_unknown_names', () {
    final Random random = seededRandom(95102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String unknownName = _randomUnknownKindName(random);

      expect(
        () => HostingProblemKind.decode(unknownName),
        throwsFormatException,
        reason: unknownName,
      );
    }
  });

  test('test_hosting_problem_kind_wire_name_property_matches_the_rust_'
      'names', () {
    final List<String> wireNames = <String>[
      for (final HostingProblemKind kind in HostingProblemKind.values)
        kind.wireName,
    ];

    expect(wireNames.toSet(), hasLength(wireNames.length));
    expect(wireNames.toSet(), equals(nodeHostingProblemKinds.toSet()));
    for (final String wireName in wireNames) {
      expect(_snakeCase.hasMatch(wireName), isTrue, reason: wireName);
    }
  });

  test('test_status_view_from_json_property_keeps_the_hosting_problem_'
      'kind', () {
    final Random random = seededRandom(95103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final HostingProblemKind kind = pickOne(
        random,
        HostingProblemKind.values,
      );
      final JsonObject statusJson = _statusJsonWithKind(random, kind.wireName);

      final StatusView status = StatusView.fromJson(statusJson);

      expect(status.hostingProblemKind, kind);
      expect(status.hostingProblem, statusJson[_problemField]);
    }
  });

  test('test_status_view_from_json_property_a_missing_or_null_kind_'
      'means_none', () {
    final Random random = seededRandom(95104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject nulledJson = _statusJsonWithKind(random, null);
      final JsonObject shortenedJson = removeWireField(
        _statusJsonWithKind(random, pickOne(random, nodeHostingProblemKinds)),
        _kindField,
      );

      expect(StatusView.fromJson(nulledJson).hostingProblemKind, isNull);
      expect(StatusView.fromJson(shortenedJson).hostingProblemKind, isNull);
    }
  });

  test('test_status_view_from_json_property_rejects_an_unknown_kind', () {
    final Random random = seededRandom(95105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject brokenJson = _statusJsonWithKind(
        random,
        _randomUnknownKindName(random),
      );

      expect(() => StatusView.fromJson(brokenJson), throwsFormatException);
    }
  });

  test('test_status_view_to_json_property_round_trips_the_kind', () {
    final Random random = seededRandom(95106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String? kindName = random.nextBool()
          ? pickOne(random, nodeHostingProblemKinds)
          : null;
      final StatusView status = StatusView.fromJson(
        _statusJsonWithKind(random, kindName),
      );

      final JsonObject encoded = decodeObject(reencodeAsJsonText(status));
      final StatusView decoded = StatusView.fromJson(encoded);

      expect(encoded.containsKey(_kindField), isTrue);
      expect(encoded[_kindField], kindName);
      expect(decoded.hostingProblemKind, status.hostingProblemKind);
    }
  });
}
