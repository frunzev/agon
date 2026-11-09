import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/data/repository/agent_login_repository.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_app_server_refusals.dart';
import '../support/planned_refusal.dart';
import 'agent_login_probe.dart';

const AgentLoginStatus unknownLoginStatus = AgentLoginStatus(
  claudeLogin: ClaudeLogin.unknown,
  containerCredential: null,
);

final class FailingAgentLoginRepository extends ChangeNotifier
    implements AgentLoginRepository {
  FailingAgentLoginRepository({required this.stored}) {
    stored.addListener(notifyListeners);
  }

  final FakeAgentLoginRepository stored;
  final PlannedRefusal statusRefusal = PlannedRefusal();
  final PlannedRefusal closeRefusal = PlannedRefusal();
  Completer<void>? pendingStatusCheck;
  Completer<void>? pendingClose;
  AgentLoginStatus? deliveredStatus;

  void deliverStatus(AgentLoginStatus status) {
    deliveredStatus = status;
    notifyListeners();
  }

  @override
  AgentLoginStatus? findStatus() => deliveredStatus ?? stored.findStatus();

  @override
  LoginTerminal? findTerminal() => stored.findTerminal();

  @override
  Future<void> checkStatus() async {
    final Completer<void>? pending = pendingStatusCheck;
    if (pending != null) {
      await pending.future;
    }
    await statusRefusal.refuseOr(stored.checkStatus);
  }

  @override
  Future<void> openTerminal(AgentPlace place) => stored.openTerminal(place);

  @override
  Future<void> typeIntoTerminal(String keys) {
    return stored.typeIntoTerminal(keys);
  }

  @override
  Future<void> closeTerminal() async {
    final Completer<void>? pending = pendingClose;
    if (pending != null) {
      await pending.future;
    }
    await closeRefusal.refuseOr(stored.closeTerminal);
  }

  @override
  Future<void> saveApiKey(String apiKey) => stored.saveApiKey(apiKey);

  @override
  Future<void> forgetCredential() => stored.forgetCredential();
}

PeopleFacingRefusal randomPeopleFacingRefusal(Random random) {
  return PeopleFacingRefusal(randomRefusalReason(random));
}

String readShownStatusText(WidgetTester tester) {
  return tester.widget<StatusLabel>(find.byType(StatusLabel)).text;
}

FailingAgentLoginRepository buildFailingLoginRepository(
  AgentLoginStatus? status,
) {
  return FailingAgentLoginRepository(
    stored: FakeAgentLoginRepository(status: status),
  );
}

Future<void> pumpOneLoginSection(
  WidgetTester tester,
  Random random, {
  required AgentPlace place,
  required AgentLoginRepository repository,
}) {
  return pumpLoginSections(
    tester,
    random,
    places: <AgentPlace>[place],
    repository: repository,
  );
}
