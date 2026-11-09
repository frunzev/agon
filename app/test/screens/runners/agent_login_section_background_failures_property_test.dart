import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';

import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'agent_login_probe.dart';
import 'failing_agent_login_probe.dart';

void main() {
  testWidgets('test_agent_login_section_check_status_property_a_refused_'
      'check_shows_an_unknown_status', (WidgetTester tester) async {
    final Random random = seededRandom(110501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
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

      expect(tester.takeException(), isNull);
      expect(find.text(describeAgentLoginTitle(place)), findsOneWidget);
      expect(
        readShownStatusText(tester),
        describeAgentLogin(
          place: place,
          status: unknownLoginStatus,
        ).statusText,
      );
    }
  });

  testWidgets('test_agent_login_section_find_shown_status_property_a_refused_'
      'check_keeps_a_known_status', (WidgetTester tester) async {
    final Random random = seededRandom(110502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = randomLoginStatus(random);
      final FailingAgentLoginRepository repository =
          buildFailingLoginRepository(status);
      repository.statusRefusal.problem = randomPeopleFacingRefusal(random);

      await pumpOneLoginSection(
        tester,
        random,
        place: place,
        repository: repository,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        readShownStatusText(tester),
        describeAgentLogin(place: place, status: status).statusText,
      );
    }
  });

  testWidgets('test_agent_login_section_check_status_property_a_refusal_'
      'after_leaving_is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(110503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FailingAgentLoginRepository repository =
          buildFailingLoginRepository(null);
      final Completer<void> pending = Completer<void>();
      repository.pendingStatusCheck = pending;
      repository.statusRefusal.problem = randomPeopleFacingRefusal(random);
      await pumpOneLoginSection(
        tester,
        random,
        place: pickOne(random, AgentPlace.values),
        repository: repository,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.statusRefusal.attempts, 1);
    }
  });

  testWidgets('test_agent_login_section_dispose_property_a_refused_close_'
      'is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(110504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final FailingAgentLoginRepository repository =
          buildFailingLoginRepository(randomLoginStatus(random));
      await pumpOneLoginSection(
        tester,
        random,
        place: place,
        repository: repository,
      );
      await repository.stored.openTerminal(place);
      await tester.pump();
      repository.closeRefusal.problem = randomPeopleFacingRefusal(random);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.closeRefusal.attempts, 1);
    }
  });

  testWidgets('test_agent_login_section_dispose_property_a_late_refusal_'
      'is_quiet', (WidgetTester tester) async {
    final Random random = seededRandom(110505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final FailingAgentLoginRepository repository =
          buildFailingLoginRepository(randomLoginStatus(random));
      await pumpOneLoginSection(
        tester,
        random,
        place: place,
        repository: repository,
      );
      await repository.stored.openTerminal(place);
      await tester.pump();
      final Completer<void> pending = Completer<void>();
      repository.pendingClose = pending;
      repository.closeRefusal.problem = randomExplainedRefusal(random).problem;

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.closeRefusal.attempts, 1);
    }
  });

  testWidgets('test_agent_login_section_dispose_property_a_failed_close_'
      'still_lets_a_new_section_check', (WidgetTester tester) async {
    final Random random = seededRandom(110506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = randomLoginStatus(random);
      final FailingAgentLoginRepository repository =
          buildFailingLoginRepository(status);
      await pumpOneLoginSection(
        tester,
        random,
        place: place,
        repository: repository,
      );
      await repository.stored.openTerminal(place);
      await tester.pump();
      repository.closeRefusal.problem = randomPeopleFacingRefusal(random);

      await pumpOneLoginSection(
        tester,
        random,
        place: place,
        repository: repository,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(repository.statusRefusal.attempts, 2);
      expect(
        readShownStatusText(tester),
        describeAgentLogin(place: place, status: status).statusText,
      );
    }
  });
}
