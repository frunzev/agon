import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/setup/pairing_code_entry_screen.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'pairing_code_entry_probe.dart';

const String _designedStep = 'Step 2 of 2';
const String _designedTitle = 'Enter the pairing code';
const String _designedLead =
    'On a device you already use, open Devices, then Pair a device. It '
    'shows a code that works for 5 minutes.';
const String _designedCodeHint = 'Dashes and spaces are optional.';
const String _designedServerLabel = 'Make this computer the server';
const String _designedServerNote =
    'No other devices yet? Make this computer the server, then pair your '
    'other devices with it.';

void main() {
  testWidgets('test_build_panel_property_matches_the_design_wording', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(112101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
      await pumpPairingCodeEntry(tester, random, probe);

      expect(tester.takeException(), isNull);
      expect(find.text(_designedStep), findsOneWidget);
      expect(find.text(_designedTitle), findsOneWidget);
      expect(find.text(_designedLead), findsOneWidget);
      expect(
        findFieldText(pairingCodeLabel, _designedCodeHint),
        findsOneWidget,
      );
      expect(makeThisComputerTheServerLabel, _designedServerLabel);
      expect(noOtherDevicesText, _designedServerNote);
    }
  });

  testWidgets('test_build_panel_property_hosting_problem_only_after_a_'
      'refusal', (WidgetTester tester) async {
    final Random random = seededRandom(112102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = PairingCodeEntryProbe(
        random,
        offersScanning: random.nextBool(),
        offersHosting: true,
      );
      await pumpPairingCodeEntry(tester, random, probe);
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      final int shownBefore = find.text(refusal.explanation).evaluate().length;
      probe.hostingRefusal.problem = refusal.problem;

      await tapVisible(
        tester,
        findPairingButton(makeThisComputerTheServerLabel),
      );
      await tester.pump();

      expect(shownBefore, 0);
      expect(find.text(refusal.explanation), findsOneWidget);
      expect(
        findFieldText(pairingCodeLabel, refusal.explanation),
        findsNothing,
      );
    }
  });

  testWidgets('test_build_panel_property_code_problem_stays_with_the_'
      'code_field', (WidgetTester tester) async {
    final Random random = seededRandom(112103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingCodeEntryProbe probe = randomPairingCodeEntryProbe(random);
      await pumpPairingCodeEntry(tester, random, probe);
      final ExplainedRefusal refusal = randomExplainedRefusal(random);
      probe.repository.joinRefusal.problem = refusal.problem;
      await enterFieldText(
        tester,
        label: pairingCodeLabel,
        text: randomValidPairingCode(random),
      );

      await tapVisible(tester, findPairingButton(probe.pairLabel));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        findFieldText(pairingCodeLabel, refusal.explanation),
        findsOneWidget,
      );
      expect(find.text(refusal.explanation), findsOneWidget);
    }
  });
}
