import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/pairing_inputs.dart';
import '../repository/support/contract_step_failures.dart';

const String _validCode = '4F7-K2Q';
const List<String?> _validServerAddresses = <String?>[
  null,
  'https://pair.example.org',
  'peer://abcdef0123456789',
];

String _randomName(Random random) {
  if (random.nextBool()) {
    return randomDeviceName(random);
  }
  return randomHostileText(random);
}

String? _randomServerAddress(Random random) {
  if (random.nextBool()) {
    return pickOne(random, _validServerAddresses);
  }
  return randomHostileText(random);
}

String _randomCode(Random random) {
  if (random.nextBool()) {
    return _validCode;
  }
  return randomHostileText(random);
}

Future<Object?> _findJoinFailure({
  required String? serverAddress,
  required String code,
  required String deviceName,
}) {
  return findStepFailure(
    () async => refuseBadJoinInput(
      serverAddress: serverAddress,
      code: code,
      deviceName: deviceName,
    ),
  );
}

Future<Object?> _findHostingFailure({
  required String workspaceName,
  required String deviceName,
}) {
  return findStepFailure(
    () async => refuseBadHostedAccountNames(
      workspaceName: workspaceName,
      deviceName: deviceName,
    ),
  );
}

void main() {
  test('test_refuse_bad_join_input_property_accepts_exactly_the_valid_'
      'inputs', () async {
    final Random random = seededRandom(85431);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? serverAddress = _randomServerAddress(random);
      final String code = _randomCode(random);
      final String deviceName = _randomName(random);
      final bool isValid =
          describeJoinInputProblem(serverAddress: serverAddress, code: code) ==
              null &&
          describeNameProblem(deviceName) == null;

      final Object? failure = await _findJoinFailure(
        serverAddress: serverAddress,
        code: code,
        deviceName: deviceName,
      );

      expect(failure == null, isValid, reason: '$failure');
    }
  });

  test('test_refuse_bad_join_input_property_input_problems_come_before_'
      'name_problems', () async {
    final Random random = seededRandom(85432);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String? serverAddress = _randomServerAddress(random);
      final String code = _randomCode(random);
      final String? inputProblem = describeJoinInputProblem(
        serverAddress: serverAddress,
        code: code,
      );
      if (inputProblem == null) {
        continue;
      }

      final Object? failure = await _findJoinFailure(
        serverAddress: serverAddress,
        code: code,
        deviceName: _randomName(random),
      );

      expect(failure, isA<PeopleFacingRefusal>());
      expect((failure! as PeopleFacingRefusal).message, inputProblem);
    }
  });

  test('test_refuse_bad_join_input_property_bad_names_explain_the_name_'
      'rule', () async {
    final Random random = seededRandom(85433);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String deviceName = randomHostileText(random);
      final String? nameProblem = describeNameProblem(deviceName);
      if (nameProblem == null) {
        continue;
      }

      final Object? failure = await _findJoinFailure(
        serverAddress: pickOne(random, _validServerAddresses),
        code: _validCode,
        deviceName: deviceName,
      );

      expect(failure, isA<PeopleFacingRefusal>());
      expect((failure! as PeopleFacingRefusal).message, nameProblem);
    }
  });

  test('test_refuse_bad_hosted_account_names_property_accepts_exactly_two_'
      'valid_names', () async {
    final Random random = seededRandom(85434);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String workspaceName = _randomName(random);
      final String deviceName = _randomName(random);
      final bool isValid =
          describeNameProblem(workspaceName) == null &&
          describeNameProblem(deviceName) == null;

      final Object? failure = await _findHostingFailure(
        workspaceName: workspaceName,
        deviceName: deviceName,
      );

      expect(failure == null, isValid, reason: '$failure');
      if (failure != null) {
        expect(failure, isA<PeopleFacingRefusal>());
      }
    }
  });

  test('test_refuse_bad_hosted_account_names_property_explains_the_device_'
      'name_first', () async {
    final Random random = seededRandom(85435);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String deviceName = randomHostileText(random);
      final String? deviceProblem = describeNameProblem(deviceName);
      if (deviceProblem == null) {
        continue;
      }

      final Object? failure = await _findHostingFailure(
        workspaceName: _randomName(random),
        deviceName: deviceName,
      );

      expect((failure! as PeopleFacingRefusal).message, deviceProblem);
    }
  });

  test('test_refuse_bad_hosted_account_names_property_a_good_device_'
      'leaves_the_workspace_problem', () async {
    final Random random = seededRandom(85436);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String workspaceName = randomHostileText(random);
      final String? workspaceProblem = describeNameProblem(workspaceName);

      final Object? failure = await _findHostingFailure(
        workspaceName: workspaceName,
        deviceName: randomDeviceName(random),
      );

      if (workspaceProblem == null) {
        expect(failure, isNull);
      } else {
        expect(
          (failure! as PeopleFacingRefusal).message,
          workspaceProblem,
        );
      }
    }
  });
}
