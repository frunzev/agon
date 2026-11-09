import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/account_values.dart';
import 'package:agent_orchestration/bridge/node/node_command_failure.dart';
import 'package:agent_orchestration/data/node_backed/node_command_execution.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/device_without_account.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/screens/task_form/submit_refusal.dart';
import 'package:agent_orchestration/startup/hosting_problem.dart';

import '../bridge/support/hostile_texts.dart';
import '../support/random_app_server_refusals.dart';
import '../support/random_inputs.dart';

typedef _ExplainedProblem = ({Object problem, String message});

const String _actionLabel = 'Save';
const List<String> _wrapperWords = <String>[
  'Bad state',
  'Invalid argument',
  'Instance of',
  appServerRefusalPrefix,
];

String _randomMessage(Random random) {
  return '${randomHostileText(random)}refused${randomHostileText(random)}';
}

_ExplainedProblem _randomExplainedProblem(Random random) {
  final String message = _randomMessage(random);
  final List<Object> problems = <Object>[
    PeopleFacingRefusal(message),
    AppServerRefusal(status: 400 + random.nextInt(200), reason: message),
    DeviceWithoutAccount(message),
    HostingProblem(message, kind: null),
    HostingProblem(message, kind: pickOne(random, HostingProblemKind.values)),
  ];
  return (problem: pickOne(random, problems), message: message);
}

String _randomNodeMessage(Random random) {
  final String message = _randomMessage(random);
  return pickOne(random, <String>[
    message,
    renderRefusalMessage(status: 400 + random.nextInt(200), reason: message),
    'task ${randomText(random)} was not found',
  ]);
}

Object _randomUnexplainedProblem(Random random) {
  final String text = randomHostileText(random);
  return pickOne(random, <Object>[
    TypeError(),
    FormatException(text),
    RangeError(text),
    IndexError.withLength(random.nextInt(9), 0),
    UnsupportedError(text),
    UnimplementedError(text),
    Exception(text),
    ArgumentError(),
    ArgumentError.value(text, 'name'),
    ArgumentError(random.nextInt(99)),
    ArgumentError(text),
    ArgumentError.value(text, 'name', text),
    StateError(text),
    NodeCommandFailure(text),
    text,
    random.nextInt(99),
  ]);
}

Future<Object> _catchRethrownProblem(Object problem) async {
  try {
    await catchRefusal(
      actionLabel: _actionLabel,
      action: () async {
        Error.throwWithStackTrace(problem, StackTrace.current);
      },
    );
  } on Object catch (rethrown) {
    return rethrown;
  }
  fail('the problem was swallowed');
}

void main() {
  test('test_describe_problem_for_people_property_refusals_show_message', () {
    final Random random = seededRandom(930401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _ExplainedProblem explained = _randomExplainedProblem(random);

      final String? shown = describeProblemForPeople(explained.problem);

      expect(shown, explained.message);
      for (final String wrapperWord in _wrapperWords) {
        expect(shown, isNot(startsWith(wrapperWord)));
      }
    }
  });

  test('test_describe_problem_for_people_property_bugs_never_say_null', () {
    final Random random = seededRandom(930402);
    for (int i = 0; i < propertyIterations; i += 1) {
      final Object problem = _randomUnexplainedProblem(random);

      expect(describeProblemForPeople(problem), isNull, reason: '$problem');
    }
  });

  test(
    'test_describe_problem_for_people_property_node_failures_explained',
    () {
      final Random random = seededRandom(930403);
      for (int i = 0; i < propertyIterations; i += 1) {
        final String nodeMessage = _randomNodeMessage(random);
        final String? kind = random.nextBool() ? noAccountFailureKind : null;

        final String? shown = describeProblemForPeople(
          translateNodeFailure(NodeCommandFailure(nodeMessage, kind: kind)),
        );

        expect(shown, isNotNull);
        expect(shown, isNot(startsWith('NodeCommandFailure')));
        expect(shown, isNot(startsWith('Bad state')));
      }
    },
  );

  test(
    'test_describe_problem_for_people_property_unexplained_are_rethrown',
    () async {
      final Random random = seededRandom(930404);
      for (int i = 0; i < propertyIterations; i += 1) {
        final Object problem = _randomUnexplainedProblem(random);

        final Object rethrown = await _catchRethrownProblem(problem);

        expect(rethrown, same(problem));
      }
    },
  );

  test(
    'test_describe_problem_for_people_property_refusals_become_explanations',
    () async {
      final Random random = seededRandom(930405);
      for (int i = 0; i < propertyIterations; i += 1) {
        final _ExplainedProblem explained = _randomExplainedProblem(random);

        final SubmitRefusal? refusal = await catchRefusal(
          actionLabel: _actionLabel,
          action: () async {
            Error.throwWithStackTrace(explained.problem, StackTrace.current);
          },
        );

        expect(refusal!.explanation, explained.message);
        expect(refusal.actionLabel, _actionLabel);
      }
    },
  );
}
