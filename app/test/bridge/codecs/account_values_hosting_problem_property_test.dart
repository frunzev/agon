import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/codecs/json_values.dart';

import '../../support/random_inputs.dart';
import '../support/random_account_json.dart';
import '../support/wire_json_edits.dart';

const String _hostingProblemField = 'hosting_problem';
const List<String> _sampleProblems = <String>[
  'the app server cannot listen on port 8731: address in use',
  'the hosted app server record is damaged',
  '',
  '   ',
  'Ünïcødé problem 🚧',
  'line one\nline two',
];
const List<Object> _nonTextProblems = <Object>[
  true,
  0,
  1.5,
  <Object?>['the app server cannot listen'],
  <String, Object?>{'problem': 'the app server cannot listen'},
];

String _randomProblem(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _sampleProblems);
  }
  return randomText(random);
}

JsonObject _statusJsonWithProblem(Random random, Object? problem) {
  return replaceWireField(
    randomStatusViewJson(random),
    _hostingProblemField,
    problem,
  );
}

StatusView _withHostingProblem(StatusView status, String? problem) {
  return StatusView(
    serverAddress: status.serverAddress,
    serverReachable: status.serverReachable,
    hostedServerAddress: status.hostedServerAddress,
    hostingProblem: problem,
    hostingProblemKind: status.hostingProblemKind,
    deviceId: status.deviceId,
    account: status.account,
    pendingJoin: status.pendingJoin,
    peer: status.peer,
    rendezvousProblem: status.rendezvousProblem,
    runnerSettings: status.runnerSettings,
    appServers: status.appServers,
  );
}

void main() {
  test('test_status_view_from_json_property_keeps_hosting_problem', () {
    final Random random = seededRandom(94101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = _randomProblem(random);

      final StatusView status = StatusView.fromJson(
        _statusJsonWithProblem(random, problem),
      );

      expect(status.hostingProblem, problem);
    }
  });

  test('test_status_view_from_json_property_'
      'missing_or_null_hosting_problem_means_none', () {
    final Random random = seededRandom(94102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject nulledJson = _statusJsonWithProblem(random, null);
      final JsonObject shortenedJson = removeWireField(
        _statusJsonWithProblem(random, _randomProblem(random)),
        _hostingProblemField,
      );

      expect(StatusView.fromJson(nulledJson).hostingProblem, isNull);
      expect(StatusView.fromJson(shortenedJson).hostingProblem, isNull);
    }
  });

  test('test_status_view_from_json_property_'
      'rejects_hosting_problem_that_is_not_text', () {
    final Random random = seededRandom(94103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject brokenJson = _statusJsonWithProblem(
        random,
        pickOne(random, _nonTextProblems),
      );

      expect(() => StatusView.fromJson(brokenJson), throwsFormatException);
    }
  });

  test('test_status_view_from_json_property_'
      'hosting_problem_leaves_the_rendezvous_problem_alone', () {
    final Random random = seededRandom(94104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final JsonObject statusJson = _statusJsonWithProblem(
        random,
        _randomProblem(random),
      );
      final JsonObject clearedJson = replaceWireField(
        statusJson,
        _hostingProblemField,
        null,
      );

      final StatusView status = StatusView.fromJson(statusJson);
      final StatusView cleared = StatusView.fromJson(clearedJson);

      expect(status.rendezvousProblem, cleared.rendezvousProblem);
      expect(status.serverReachable, cleared.serverReachable);
      expect(status.account?.device.id, cleared.account?.device.id);
    }
  });

  test('test_status_view_to_json_property_'
      'round_trips_hosting_problem_through_json_text', () {
    final Random random = seededRandom(94105);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String? problem = random.nextBool()
          ? _randomProblem(random)
          : null;
      final StatusView status = StatusView.fromJson(
        _statusJsonWithProblem(random, problem),
      );

      final String encodedText = jsonEncode(status.toJson());
      final StatusView decoded = StatusView.fromJson(jsonDecode(encodedText));

      expect(status.toJson()[_hostingProblemField], problem);
      expect(decoded.hostingProblem, problem);
    }
  });

  test('test_status_view_to_json_property_always_writes_hosting_problem', () {
    final Random random = seededRandom(94106);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StatusView status = StatusView.fromJson(
        removeWireField(randomStatusViewJson(random), _hostingProblemField),
      );

      final JsonObject encoded = decodeObject(status.toJson());

      expect(encoded.containsKey(_hostingProblemField), isTrue);
      expect(encoded[_hostingProblemField], isNull);
    }
  });

  test('test_status_view_constructor_property_'
      'hosting_problem_changes_nothing_else', () {
    final Random random = seededRandom(94107);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StatusView original = StatusView.fromJson(
        randomStatusViewJson(random),
      );
      final String problem = _randomProblem(random);

      final StatusView changed = _withHostingProblem(original, problem);
      final JsonObject originalJson = decodeObject(
        reencodeAsJsonText(original),
      );
      final JsonObject changedJson = decodeObject(reencodeAsJsonText(changed));

      expect(changed.hostingProblem, problem);
      expect(
        removeWireField(changedJson, _hostingProblemField),
        equals(removeWireField(originalJson, _hostingProblemField)),
      );
    }
  });

  test('test_status_view_constructor_property_keeps_no_hosting_problem', () {
    final Random random = seededRandom(94108);

    for (int i = 0; i < propertyIterations; i += 1) {
      final StatusView original = StatusView.fromJson(
        _statusJsonWithProblem(random, _randomProblem(random)),
      );

      final StatusView cleared = _withHostingProblem(original, null);

      expect(cleared.hostingProblem, isNull);
      expect(cleared.rendezvousProblem, original.rendezvousProblem);
    }
  });
}
