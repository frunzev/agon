import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';

import '../../../screens/support/planned_refusal.dart';
import '../../../screens/support/refusing_work_repositories.dart';
import '../../../support/random_inputs.dart';
import '../../fakes/support/agent_login_inputs.dart';
import '../../fakes/support/notification_counter.dart';
import '../../node_backed/support/node_backed_agent_login_rig.dart';
import '../../node_backed/support/simulated_agent_login_node.dart';
import 'contract_step_failures.dart';

const int _longestStepSequence = 8;

typedef NamedAgentLoginRepository = ({
  String name,
  AgentLoginRepository repository,
  NotificationCounter notifications,
});

typedef StatusProjection = ({
  ClaudeLogin claudeLogin,
  AgentCredentialKind? containerCredential,
});

typedef TerminalProjection = ({
  AgentPlace place,
  String command,
  LoginTerminalState state,
  String? firstLine,
});

enum LoginStep { open, type, close, saveKey, forget, check }

Future<List<NamedAgentLoginRepository>> buildEveryAgentLoginRepository(
  AgentLoginStatus status,
) async {
  final AgentLoginRig rig = await buildCheckedAgentLoginRig(status);
  final List<NamedAgentLoginRepository> implementations =
      <NamedAgentLoginRepository>[
        _countNotifications('fake', FakeAgentLoginRepository(status: status)),
        _countNotifications('node backed', rig.repository),
        _countNotifications(
          'refusing double',
          RefusingAgentLoginRepository(
            stored: FakeAgentLoginRepository(status: status),
            refusal: PlannedRefusal(),
          ),
        ),
      ];
  return implementations;
}

NamedAgentLoginRepository _countNotifications(
  String name,
  AgentLoginRepository repository,
) {
  final NotificationCounter notifications = NotificationCounter();
  repository.addListener(notifications.record);
  return (name: name, repository: repository, notifications: notifications);
}

StatusProjection? projectStatus(AgentLoginStatus? status) {
  if (status == null) {
    return null;
  }
  return (
    claudeLogin: status.claudeLogin,
    containerCredential: status.containerCredential,
  );
}

TerminalProjection? projectTerminal(LoginTerminal? terminal) {
  if (terminal == null) {
    return null;
  }
  return (
    place: terminal.place,
    command: terminal.command,
    state: terminal.state,
    firstLine: terminal.lines.isEmpty ? null : terminal.lines.first,
  );
}

String randomTypedKeys(Random random) {
  final List<String> typings = <String>[
    randomText(random),
    '${randomText(random)}$enterKey',
    enterKey,
    '',
    randomWordPhrase(random),
  ];
  return pickOne(random, typings);
}

String randomApiKeyAttempt(Random random) {
  if (random.nextBool()) {
    return randomValidApiKey(random);
  }
  return randomRefusedApiKey(random);
}

Future<Object?> runLoginStep(
  AgentLoginRepository repository, {
  required LoginStep step,
  required AgentPlace place,
  required String text,
}) async {
  switch (step) {
    case LoginStep.open:
      await repository.openTerminal(place);
    case LoginStep.type:
      await repository.typeIntoTerminal(text);
    case LoginStep.close:
      await repository.closeTerminal();
    case LoginStep.saveKey:
      await repository.saveApiKey(text);
    case LoginStep.forget:
      await repository.forgetCredential();
    case LoginStep.check:
      await repository.checkStatus();
  }
  return null;
}

String randomStepText(Random random, LoginStep step) {
  if (step == LoginStep.saveKey) {
    return randomApiKeyAttempt(random);
  }
  return randomTypedKeys(random);
}

Future<void> runRandomStepsOnEvery(
  Random random,
  List<NamedAgentLoginRepository> implementations,
) async {
  final int stepCount = 1 + random.nextInt(_longestStepSequence);
  for (int index = 0; index < stepCount; index += 1) {
    final LoginStep step = pickOne(random, LoginStep.values);
    final AgentPlace place = pickOne(random, AgentPlace.values);
    final String text = randomStepText(random, step);
    final List<bool> refusals = <bool>[];
    for (final NamedAgentLoginRepository implementation in implementations) {
      final Object? failure = await findStepFailure(
        () => runLoginStep(
          implementation.repository,
          step: step,
          place: place,
          text: text,
        ),
      );
      expect(failure == null || isContractRefusal(failure), isTrue);
      refusals.add(failure != null);
    }
    expect(refusals.toSet(), hasLength(1), reason: '$step "$text"');
  }
}

Future<List<NamedAgentLoginRepository>> buildRandomAgentLoginRepositories(
  Random random,
) {
  return buildEveryAgentLoginRepository(randomKnownAgentLoginStatus(random));
}

TerminalProjection describeOpenTerminal(AgentPlace place) {
  return (
    place: place,
    command: nodeLoginCommands[place]!,
    state: LoginTerminalState.running,
    firstLine: loginPrompt,
  );
}

Future<void> typeRandomKeys(Random random, AgentLoginRepository repository) {
  return repository.typeIntoTerminal(randomTypedKeys(random));
}
