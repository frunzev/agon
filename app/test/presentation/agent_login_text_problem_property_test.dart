import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/agent_login_text.dart';

import '../support/random_inputs.dart';
import 'support/plain_shown_text.dart';

const String _notLoggedInDesignPage = 'task-run-not-logged-in';
const String _designLoginFailure = 'Not logged in · Please run /login';
const String _runnerNamePlaceholder = '<runner>';
const List<String> _plainRunnerNames = <String>[
  'air-laptop',
  'Mac mini',
  'build box 2',
  'Ünïcødé PC',
];

void main() {
  test('test_is_agent_login_problem_property_joining_text_keeps_a_'
      'problem', () {
    final Random random = seededRandom(91606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String firstReason = random.nextBool()
          ? _designLoginFailure
          : randomText(random);
      final String secondReason = randomText(random);
      final bool isEitherProblem =
          isAgentLoginProblem(firstReason) ||
          isAgentLoginProblem(secondReason);

      final bool isJoinedProblem = isAgentLoginProblem(
        '$firstReason$secondReason',
      );

      expect(isJoinedProblem || !isEitherProblem, isTrue);
    }
  });

  test('test_is_agent_login_problem_property_the_app_own_hints_are_not_'
      'problems', () {
    final Random random = seededRandom(91607);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runnerName = pickOne(random, _plainRunnerNames);
      final List<String> shownHints = <String>[
        thisComputerLoginHint,
        describeOtherRunnerLoginHint(runnerName),
        terminalHint,
        apiKeyHint,
        '',
        ' ' * random.nextInt(8),
      ];

      for (final String hint in shownHints) {
        expect(isAgentLoginProblem(hint), isFalse, reason: hint);
      }
    }
  });

  test('test_is_agent_login_problem_property_spots_the_design_failure', () {
    final String designText = readDesignPageText(_notLoggedInDesignPage);

    expect(designText, contains(_designLoginFailure));
    expect(designText, contains(thisComputerLoginHint));
    expect(isAgentLoginProblem(_designLoginFailure), isTrue);
  });

  test('test_describe_other_runner_login_hint_property_only_the_name_'
      'changes', () {
    final Random random = seededRandom(91608);
    final String template = describeOtherRunnerLoginHint(
      _runnerNamePlaceholder,
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final String runnerName = '${randomText(random)}#$i';

      final String hint = describeOtherRunnerLoginHint(runnerName);

      final String withPlaceholder = hint.replaceFirst(
        runnerName,
        _runnerNamePlaceholder,
      );
      expect(withPlaceholder, template);
    }
  });

  test('test_describe_other_runner_login_hint_property_is_plain_'
      'sentences', () {
    for (final String runnerName in _plainRunnerNames) {
      final String hint = describeOtherRunnerLoginHint(runnerName);

      expectPlainSentences(hint);
      expect(hint, isNot(contains(thisComputerLoginHint)));
    }
  });
}
