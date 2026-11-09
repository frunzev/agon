import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../fakes/support/pairing_inputs.dart';

const String _joinLabel = 'Pair this device';
const String _validCode = '4F7-K2Q';
const List<String?> _serverAddresses = <String?>[
  null,
  'https://pair.example.org',
  'peer://abcdef0123456789',
  'ftp://pair.example.org',
  'https://',
  '',
];

String _randomCode(Random random) {
  return pickOne(random, <String>[
    _validCode,
    randomHostileText(random),
    '4F7-K2',
    '4F7-K2QQ',
  ]);
}

Future<SubmitRefusal?> _catchJoinRefusal({
  required String? serverAddress,
  required String code,
  required String deviceName,
}) {
  return catchRefusal(
    actionLabel: _joinLabel,
    action: () async => refuseBadJoinInput(
      serverAddress: serverAddress,
      code: code,
      deviceName: deviceName,
    ),
  );
}

void main() {
  test(
    'test_refuse_bad_join_input_property_input_problems_reach_people',
    () async {
      final Random random = seededRandom(615401);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String? serverAddress = pickOne(random, _serverAddresses);
        final String code = _randomCode(random);
        final String? inputProblem = describeJoinInputProblem(
          serverAddress: serverAddress,
          code: code,
        );

        final SubmitRefusal? refusal = await _catchJoinRefusal(
          serverAddress: serverAddress,
          code: code,
          deviceName: randomDeviceName(random),
        );

        expect(refusal?.explanation, inputProblem);
      }
    },
  );

  test(
    'test_refuse_bad_join_input_property_name_problems_reach_people',
    () async {
      final Random random = seededRandom(615402);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String deviceName = randomHostileText(random);

        final SubmitRefusal? refusal = await _catchJoinRefusal(
          serverAddress: pickOne(random, <String?>[null, _serverAddresses[1]]),
          code: _validCode,
          deviceName: deviceName,
        );

        expect(refusal?.explanation, describeNameProblem(deviceName));
      }
    },
  );

  test('test_refuse_bad_hosted_account_names_property_problems_reach_'
      'people', () async {
    final Random random = seededRandom(615403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String workspaceName = randomHostileText(random);
      final String deviceName = pickOne(random, <String>[
        randomDeviceName(random),
        randomHostileText(random),
      ]);
      final String? expectedProblem =
          describeNameProblem(deviceName) ??
          describeNameProblem(workspaceName);

      final SubmitRefusal? refusal = await catchRefusal(
        actionLabel: _joinLabel,
        action: () async => refuseBadHostedAccountNames(
          workspaceName: workspaceName,
          deviceName: deviceName,
        ),
      );

      expect(refusal?.explanation, expectedProblem);
    }
  });
}
