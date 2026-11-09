import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/pairing.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'pairing_approval_steps.dart';
import 'pairing_flow_harness.dart';
import 'scripted_pairing_repository.dart';

const String _noDeviceTitle = 'No device is waiting';

String _readFactText(WidgetTester tester, String term) {
  final FactRow row = tester.widget<FactRow>(find.byType(FactRow));
  final Fact fact = row.facts.singleWhere((Fact fact) => fact.term == term);
  final StringBuffer shown = StringBuffer();
  for (final TextSegment segment in fact.description) {
    shown.write(segment.text);
  }
  return shown.toString();
}

bool _isMonospace(TextSegment segment) => segment.face == TextFace.monospace;

void _expectRequestShown(PairingRequest request) {
  expect(find.text('Approve ${request.deviceName}?'), findsWidgets);
  expect(
    find.text('It wants to join as ${describeRoleWithArticle(request.role)}.'),
    findsOneWidget,
  );
  expect(find.text(_noDeviceTitle), findsNothing);
}

void main() {
  testWidgets('test_build_request_facts_property_role_key_and_code_read_'
      'from_the_request', (WidgetTester tester) async {
    final Random random = seededRandom(104810);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingRequest request = randomPairingRequest(random);

      await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: request,
        workspaces: randomWorkspaces(random),
      );

      expect(_readFactText(tester, 'Role'), request.role.label);
      expect(_readFactText(tester, 'Hardware key'), request.keyKind.label);
      expect(_readFactText(tester, 'Code used'), request.codeUsed);
    }
  });

  testWidgets('test_build_request_facts_property_terms_follow_the_design_'
      'order', (WidgetTester tester) async {
    final Random random = seededRandom(104811);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: randomPairingRequest(random),
        workspaces: randomWorkspaces(random),
      );

      final FactRow row = tester.widget<FactRow>(find.byType(FactRow));
      expect(
        <String>[for (final Fact fact in row.facts) fact.term],
        <String>['Role', 'Hardware key', 'Code used'],
      );
    }
  });

  testWidgets('test_build_request_facts_property_the_code_is_monospace', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(104812);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: randomPairingRequest(random),
        workspaces: randomWorkspaces(random),
      );

      final FactRow row = tester.widget<FactRow>(find.byType(FactRow));
      for (final Fact fact in row.facts) {
        final bool isCode = fact.term == 'Code used';
        expect(
          fact.description.every(_isMonospace),
          isCode,
          reason: fact.term,
        );
      }
    }
  });

  testWidgets('test_pairing_approval_screen_build_page_property_follows_the_'
      'pending_request', (WidgetTester tester) async {
    final Random random = seededRandom(104813);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingRequest request = randomPairingRequest(random);
      final PairingPage page = await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: null,
        workspaces: randomWorkspaces(random),
      );

      page.pairing.arrive(request);
      await pumpFrames(tester);
      _expectRequestShown(request);

      if (random.nextBool()) {
        page.pairing.passTime(pairingLifetime);
      } else {
        page.pairing.closeElsewhere();
      }
      await pumpFrames(tester);
      expect(find.text(_noDeviceTitle), findsWidgets);
      expect(find.text('Approve'), findsNothing);
    }
  });

  testWidgets('test_pairing_approval_screen_build_page_property_a_new_'
      'request_replaces_the_old', (WidgetTester tester) async {
    final Random random = seededRandom(104814);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingRequest first = randomPairingRequest(random);
      final PairingRequest second = randomPairingRequest(random);
      final PairingPage page = await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: first,
        workspaces: randomWorkspaces(random),
      );

      page.pairing.arrive(second);
      await pumpFrames(tester);

      _expectRequestShown(second);
      expect(_readFactText(tester, 'Role'), second.role.label);
      final FingerprintWords words = tester.widget(
        find.byType(FingerprintWords),
      );
      expect(words.words, second.fingerprintWords);
    }
  });

  testWidgets('test_pairing_approval_screen_build_page_property_keeps_the_'
      'chosen_workspaces_across_changes', (WidgetTester tester) async {
    final Random random = seededRandom(104815);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingRequest request = randomPairingRequest(random);
      final PairingPage page = await openApprovalPage(
        tester,
        size: randomPairingWindow(random),
        request: request,
        workspaces: randomWorkspaces(random),
      );
      final List<String> names = listWorkspaceNames(
        page.dependencies.workspaceRepository.listWorkspaces(),
      );
      final String added = pickOne(random, names);
      await addFieldTag(tester, label: workspacesLabel, tag: added);
      final List<String> chosen = readShownTags(tester);

      page.pairing.arrive(request);
      await pumpFrames(tester);

      expect(readShownTags(tester), chosen);
    }
  });
}
