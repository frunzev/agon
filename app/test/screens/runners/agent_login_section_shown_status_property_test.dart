import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';

import '../../support/random_inputs.dart';
import 'agent_login_probe.dart';
import 'failing_agent_login_probe.dart';

void main() {
  testWidgets('test_agent_login_section_check_status_property_a_refused_'
      'check_is_tried_once', (WidgetTester tester) async {
    final Random random = seededRandom(112001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FailingAgentLoginRepository repository =
          buildFailingLoginRepository(
            random.nextBool() ? null : randomLoginStatus(random),
          );
      repository.statusRefusal.problem = randomPeopleFacingRefusal(random);

      await pumpOneLoginSection(
        tester,
        random,
        place: pickOne(random, AgentPlace.values),
        repository: repository,
      );
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.statusRefusal.attempts, 1);
    }
  });

  testWidgets('test_agent_login_section_find_shown_status_property_hidden_'
      'while_the_check_runs', (WidgetTester tester) async {
    final Random random = seededRandom(112002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final FailingAgentLoginRepository repository =
          buildFailingLoginRepository(null);
      final Completer<void> pending = Completer<void>();
      repository.pendingStatusCheck = pending;
      repository.statusRefusal.problem = randomPeopleFacingRefusal(random);

      await pumpOneLoginSection(
        tester,
        random,
        place: place,
        repository: repository,
      );
      final int titlesWhileChecking = find
          .text(describeAgentLoginTitle(place))
          .evaluate()
          .length;
      pending.complete();
      await tester.pump();
      await tester.pump();

      expect(titlesWhileChecking, 0);
      expect(find.text(describeAgentLoginTitle(place)), findsOneWidget);
    }
  });

  testWidgets('test_agent_login_section_find_shown_status_property_a_'
      'later_status_replaces_unknown', (WidgetTester tester) async {
    final Random random = seededRandom(112003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = randomLoginStatus(random);
      final FailingAgentLoginRepository repository =
          buildFailingLoginRepository(null);
      repository.statusRefusal.problem = randomPeopleFacingRefusal(random);
      await pumpOneLoginSection(
        tester,
        random,
        place: place,
        repository: repository,
      );
      await tester.pump();
      final String unknownText = readShownStatusText(tester);

      repository.deliverStatus(status);
      await tester.pump();

      expect(
        unknownText,
        describeAgentLogin(
          place: place,
          status: unknownLoginStatus,
        ).statusText,
      );
      expect(
        readShownStatusText(tester),
        describeAgentLogin(place: place, status: status).statusText,
      );
    }
  });
}
