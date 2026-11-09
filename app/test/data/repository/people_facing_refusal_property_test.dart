import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/device_without_account.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/startup/hosting_problem.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

String _randomSentence(Random random) {
  return 'Refused ${randomHostileText(random)}.';
}

List<PeopleFacingRefusal> _buildEveryRefusalKind(
  Random random,
  String message,
) {
  return <PeopleFacingRefusal>[
    PeopleFacingRefusal(message),
    AppServerRefusal(status: 400 + random.nextInt(200), reason: message),
    DeviceWithoutAccount(message),
    HostingProblem(message, kind: null),
    HostingProblem(message, kind: pickOne(random, HostingProblemKind.values)),
  ];
}

void main() {
  test(
    'test_people_facing_refusal_constructor_property_keeps_the_message',
    () {
      final Random random = seededRandom(615201);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String message = randomHostileText(random);

        final PeopleFacingRefusal refusal = PeopleFacingRefusal(message);

        expect(refusal.message, message);
        expect(refusal.toString(), contains(message));
      }
    },
  );

  test('test_people_facing_refusal_constructor_property_people_read_the_'
      'sentence', () {
    final Random random = seededRandom(615202);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String sentence = _randomSentence(random);

      final String? shown = describeProblemForPeople(
        PeopleFacingRefusal(sentence),
      );

      expect(shown, sentence);
    }
  });

  test('test_people_facing_refusal_constructor_property_app_refusals_share_'
      'the_type', () {
    final Random random = seededRandom(615203);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String sentence = _randomSentence(random);

      for (final PeopleFacingRefusal refusal in _buildEveryRefusalKind(
        random,
        sentence,
      )) {
        expect(refusal.message, sentence);
        expect(describeProblemForPeople(refusal), sentence);
      }
    }
  });
}
