import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'pairing_flow_harness.dart';

const String _approveLabel = 'Approve';
const String _rejectLabel = 'Reject';
const String _devicesLabel = 'Devices';
const Map<String, String> _callOfButton = <String, String>{
  _approveLabel: 'approve',
  _rejectLabel: 'reject',
};

Future<PairingPage> _openRandomApproval(WidgetTester tester, Random random) {
  return openApprovalPage(
    tester,
    size: randomPairingWindow(random),
    request: randomPairingRequest(random),
    workspaces: randomWorkspaces(random),
  );
}

Future<void> _tapBackLink(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BackLinkButton),
      matching: find.text(_devicesLabel),
    ),
  );
  await pumpFrames(tester);
}

Future<void> _release(WidgetTester tester, PairingPage page) async {
  final Completer<void>? hold = page.pairing.heldAction;
  page.pairing.heldAction = null;
  hold?.complete();
  await pumpFrames(tester);
}

void _expectDecisionButtons(WidgetTester tester, {required bool isEnabled}) {
  for (final String label in _callOfButton.keys) {
    expect(isButtonEnabled(tester, label), isEnabled, reason: label);
  }
}

void main() {
  testWidgets('test_return_to_devices_property_the_back_link_opens_devices', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: random.nextBool() ? randomPairingRequest(random) : null,
        workspaces: randomWorkspaces(random),
      );

      await _tapBackLink(tester);

      expect(page.navigation.routes, <AppRoute>[devicesRoute]);
      expect(page.pairing.calls, isEmpty);
    }
  });

  testWidgets('test_return_to_devices_property_a_finished_decision_opens_'
      'devices', (WidgetTester tester) async {
    final Random random = seededRandom(105002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openRandomApproval(tester, random);
      final String button = pickOne(random, _callOfButton.keys.toList());

      await tapButtonLabelled(tester, button);

      expect(page.navigation.routes, <AppRoute>[devicesRoute]);
      expect(page.pairing.findPendingRequest(), isNull);
      expect(find.byType(PairingApprovalScreen), findsNothing);
    }
  });

  testWidgets('test_return_to_devices_property_a_refused_decision_stays_'
      'on_the_page', (WidgetTester tester) async {
    final Random random = seededRandom(105003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openRandomApproval(tester, random);
      page.pairing.plannedRefusal = 'refused ${randomWordPhrase(random)}';
      final String button = pickOne(random, _callOfButton.keys.toList());

      await tapButtonLabelled(tester, button);
      await tapButtonLabelled(tester, refusalCloseLabel);

      expect(page.navigation.routes.last, const PairingApprovalRoute());
      expect(find.byType(PairingApprovalScreen), findsOneWidget);
    }
  });

  testWidgets('test_decide_property_sends_the_tapped_decision_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openRandomApproval(tester, random);
      page.pairing.heldAction = Completer<void>();
      final String button = pickOne(random, _callOfButton.keys.toList());

      await tapButtonLabelled(tester, button);
      final int extraTaps = random.nextInt(3);
      for (int tap = 0; tap < extraTaps; tap += 1) {
        await tapButtonLabelled(
          tester,
          pickOne(random, _callOfButton.keys.toList()),
        );
      }
      await _release(tester, page);

      expect(page.pairing.calls, <String>[_callOfButton[button]!]);
    }
  });

  testWidgets('test_decide_property_both_buttons_wait_while_the_node_'
      'answers', (WidgetTester tester) async {
    final Random random = seededRandom(105005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openRandomApproval(tester, random);
      page.pairing.heldAction = Completer<void>();

      await tapButtonLabelled(
        tester,
        pickOne(random, _callOfButton.keys.toList()),
      );

      _expectDecisionButtons(tester, isEnabled: false);
      await _release(tester, page);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_decide_property_a_refusal_names_the_tapped_action', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openRandomApproval(tester, random);
      final String problem = 'refused ${randomWordPhrase(random)}'.trim();
      page.pairing.plannedRefusal = problem;
      final String button = pickOne(random, _callOfButton.keys.toList());

      await tapButtonLabelled(tester, button);

      expect(find.text(describeRefusalTitle(button)), findsOneWidget);
      expect(find.text(problem), findsOneWidget);
      await tapButtonLabelled(tester, refusalCloseLabel);
    }
  });

  testWidgets('test_stop_deciding_property_a_refused_decision_can_be_'
      'tried_again', (WidgetTester tester) async {
    final Random random = seededRandom(105007);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openRandomApproval(tester, random);
      page.pairing.plannedRefusal = 'refused';
      final String button = pickOne(random, _callOfButton.keys.toList());

      await tapButtonLabelled(tester, button);
      await tapButtonLabelled(tester, refusalCloseLabel);
      _expectDecisionButtons(tester, isEnabled: true);
      page.pairing.plannedRefusal = null;
      await tapButtonLabelled(tester, button);

      expect(page.pairing.calls, hasLength(2));
      expect(page.navigation.routes, <AppRoute>[devicesRoute]);
    }
  });

  testWidgets('test_stop_deciding_property_leaving_before_the_answer_'
      'raises_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(105008);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openRandomApproval(tester, random);
      page.pairing.heldAction = Completer<void>();
      if (random.nextBool()) {
        page.pairing.plannedRefusal = 'refused';
      }

      await tapButtonLabelled(
        tester,
        pickOne(random, _callOfButton.keys.toList()),
      );
      await _tapBackLink(tester);
      await _release(tester, page);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, <AppRoute>[devicesRoute]);
    }
  });

  testWidgets('test_stop_deciding_property_buttons_return_once_the_node_'
      'refuses', (WidgetTester tester) async {
    final Random random = seededRandom(105009);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openRandomApproval(tester, random);
      page.pairing.heldAction = Completer<void>();
      page.pairing.plannedRefusal = 'refused';

      await tapButtonLabelled(
        tester,
        pickOne(random, _callOfButton.keys.toList()),
      );
      _expectDecisionButtons(tester, isEnabled: false);
      await _release(tester, page);
      await tapButtonLabelled(tester, refusalCloseLabel);

      _expectDecisionButtons(tester, isEnabled: true);
    }
  });
}
