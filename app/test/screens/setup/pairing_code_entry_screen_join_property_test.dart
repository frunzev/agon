import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/screens/setup/pairing_code_entry_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'pairing_code_entry_probe.dart';

Future<PairingCodeEntryProbe> _pumpWithCode(
  WidgetTester tester,
  Random random,
  String code,
) async {
  final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
  await pumpPairingCodeEntry(tester, random, probe);
  await enterFieldText(tester, label: pairingCodeLabel, text: code);
  return probe;
}

Future<void> _tapPair(WidgetTester tester, PairingCodeEntryProbe probe) async {
  await tapVisible(tester, findPairingButton(probe.pairLabel));
  await tester.pump();
}

void main() {
  testWidgets('test_join_property_valid_codes_are_sent_as_typed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(110901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String code = randomValidPairingCode(random);
      final PairingCodeEntryProbe probe = await _pumpWithCode(
        tester,
        random,
        code,
      );

      await _tapPair(tester, probe);

      expect(tester.takeException(), isNull);
      expect(probe.repository.joinedCodes, <String>[code]);
      expect(probe.repository.joinedServerAddresses, <String?>[null]);
      expect(probe.navigation.currentRoute, isA<PairingDoneRoute>());
      expect(probe.navigation.routes, hasLength(1));
    }
  });

  testWidgets('test_join_property_bad_codes_are_explained_and_never_sent', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(110902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String code = randomBadPairingCode(random);
      final String? problem = describePairingCodeProblem(code);
      final PairingCodeEntryProbe probe = await _pumpWithCode(
        tester,
        random,
        code,
      );

      await _tapPair(tester, probe);

      expect(problem, isNotNull, reason: code);
      expect(findFieldText(pairingCodeLabel, problem!), findsOneWidget);
      expect(probe.repository.joinedCodes, isEmpty);
      expect(probe.navigation.routes, <AppRoute>[
        PairingCodeEntryRoute(probe.role),
      ]);
    }
  });

  testWidgets('test_join_property_a_double_tap_joins_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(110903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = await _pumpWithCode(
        tester,
        random,
        randomValidPairingCode(random),
      );
      final Completer<void> pending = Completer<void>();
      probe.repository.pendingJoin = pending;
      final Finder pair = findPairingButton(probe.pairLabel);
      await tester.ensureVisible(pair);
      await tester.pump();

      await tester.tap(pair);
      await tester.tap(pair);
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.repository.joinedCodes, hasLength(1));
    }
  });

  testWidgets('test_join_property_a_refusal_shows_its_reason_until_the_'
      'code_changes', (WidgetTester tester) async {
    final Random random = seededRandom(110904);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = await _pumpWithCode(
        tester,
        random,
        randomValidPairingCode(random),
      );
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      probe.repository.joinRefusal.problem = refusal.problem;

      await _tapPair(tester, probe);
      final Finder shownReason = findFieldText(
        pairingCodeLabel,
        refusal.explanation,
      );
      final int reasonsBeforeTyping = shownReason.evaluate().length;
      await enterFieldText(
        tester,
        label: pairingCodeLabel,
        text: randomValidPairingCode(random),
      );

      expect(tester.takeException(), isNull);
      expect(reasonsBeforeTyping, 1);
      expect(shownReason, findsNothing);
      expect(probe.navigation.routes, <AppRoute>[
        PairingCodeEntryRoute(probe.role),
      ]);
    }
  });

  testWidgets('test_run_busy_property_buttons_wait_while_pairing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(110905);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = await _pumpWithCode(
        tester,
        random,
        randomValidPairingCode(random),
      );
      final Completer<void> pending = Completer<void>();
      probe.repository.pendingJoin = pending;
      probe.repository.joinRefusal.problem = randomExplainedRefusal(random)
          .problem;

      await _tapPair(tester, probe);
      final VoidCallback? whilePairing = readButtonCallback(
        tester,
        probe.pairLabel,
      );
      final bool hostingWaits =
          !probe.offersHosting ||
          readButtonCallback(tester, makeThisComputerTheServerLabel) == null;
      pending.complete();
      await tester.pump();

      expect(whilePairing, isNull);
      expect(hostingWaits, isTrue);
      expect(readButtonCallback(tester, probe.pairLabel), isNotNull);
    }
  });

  testWidgets('test_run_busy_property_a_refusal_after_leaving_is_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(110906);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = await _pumpWithCode(
        tester,
        random,
        randomValidPairingCode(random),
      );
      final Completer<void> pending = Completer<void>();
      probe.repository.pendingJoin = pending;
      probe.repository.joinRefusal.problem = randomExplainedRefusal(random)
          .problem;
      await _tapPair(tester, probe);

      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(probe.navigation.routes, <AppRoute>[
        PairingCodeEntryRoute(probe.role),
      ]);
    }
  });

  testWidgets('test_run_busy_property_unexplained_problems_are_not_'
      'hidden', (WidgetTester tester) async {
    final Random random = seededRandom(110907);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = await _pumpWithCode(
        tester,
        random,
        randomValidPairingCode(random),
      );
      final FormatException problem = randomUnexplainedProblem(random);
      probe.repository.joinRefusal.problem = problem;
      final List<Object> escapedProblems = <Object>[];
      final VoidCallback pair = readButtonCallback(tester, probe.pairLabel)!;

      runZonedGuarded(
        pair,
        (Object escaped, StackTrace _) => escapedProblems.add(escaped),
      );
      await tester.pump();

      expect(escapedProblems, <Object>[same(problem)]);
      expect(find.text(problem.message), findsNothing);
      expect(readButtonCallback(tester, probe.pairLabel), isNotNull);
    }
  });
}
