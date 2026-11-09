import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/settings/audit_log_tab.dart';

import '../../support/random_inputs.dart';
import '../../support/runner_pages.dart';
import '../../support/widget_harness.dart';
import '../support/audit_log_tab_harness.dart';

const String _checkingTitle = 'Checking the log';
const String _intactTitle = 'The log is intact';

ScriptedAuditRepository _randomAudit(Random random) {
  return ScriptedAuditRepository(entries: randomNonEmptyAuditChain(random));
}

Future<void> _pumpTabs(WidgetTester tester, List<Widget> tabs) async {
  await pumpScrollableAtWidth(
    tester,
    width: desktopWidth,
    child: Column(children: tabs),
  );
  await tester.pump();
}

String _describeLatest(ScriptedAuditRepository audit) {
  return 'Latest ${shortenIdentifier(audit.listEntries().first.hash)}';
}

void main() {
  test('test_audit_log_tab_constructor_property_keeps_fields', () {
    final Random random = seededRandom(109401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      final Clock clock = FixedClock(galleryNow);

      final AuditLogTab tab = AuditLogTab(
        auditRepository: audit,
        deviceRepository: buildRunnerDevices(peerAddressProblem: null),
        clock: clock,
        key: ValueKey<int>(i),
      );

      expect(tab.auditRepository, same(audit));
      expect(tab.clock, same(clock));
      expect(tab.key, ValueKey<int>(i));
    }
  });

  test('test_audit_log_tab_constructor_property_does_not_listen_yet', () {
    final Random random = seededRandom(109402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);

      buildAuditLogTab(audit);

      expect(audit.isListenedTo, isFalse);
      expect(audit.verifyCount, 0);
    }
  });

  test('test_audit_log_tab_constructor_property_key_is_optional', () {
    final Random random = seededRandom(109403);

    for (int i = 0; i < propertyIterations; i += 1) {
      expect(buildAuditLogTab(_randomAudit(random)).key, isNull);
    }
  });

  testWidgets('test_audit_log_tab_create_state_property_each_tab_its_own', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository first = _randomAudit(random);
      final ScriptedAuditRepository second = _randomAudit(random);
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpTabs(tester, <Widget>[
        buildAuditLogTab(first),
        buildAuditLogTab(second),
      ]);

      expect(find.text(_describeLatest(first)), findsWidgets);
      expect(find.text(_describeLatest(second)), findsWidgets);
      expect(first.verifyCount, 1);
      expect(second.verifyCount, 1);
    }
  });

  testWidgets('test_audit_log_tab_create_state_property_rebuild_no_recheck', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109405);
    final ScriptedAuditRepository audit = _randomAudit(random);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpTabs(tester, <Widget>[buildAuditLogTab(audit)]);
    }

    expect(audit.verifyCount, 1);
  });

  testWidgets('test_audit_log_tab_create_state_property_new_key_rechecks', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109406);
    final ScriptedAuditRepository audit = _randomAudit(random);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpTabs(tester, <Widget>[
        KeyedSubtree(key: ValueKey<int>(i), child: buildAuditLogTab(audit)),
      ]);

      expect(audit.verifyCount, i + 1);
    }
  });

  testWidgets('test_audit_log_tab_init_state_property_one_check_on_open', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109407);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await tester.pumpWidget(const SizedBox.shrink());

      await pumpAuditLogTab(tester, random, audit);

      expect(audit.verifyCount, 1);
      expect(audit.isListenedTo, isTrue);
    }
  });

  testWidgets('test_audit_log_tab_init_state_property_checking_until_known', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109408);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      final Completer<ChainSummary> answer = Completer<ChainSummary>();
      audit.plannedAnswer = () => answer.future;
      await tester.pumpWidget(const SizedBox.shrink());

      await pumpAuditLogTab(tester, random, audit);
      expect(find.text(_checkingTitle), findsOneWidget);
      expect(find.text(_intactTitle), findsNothing);

      answer.complete(summarizeAuditChain(audit.listEntries()));
      await tester.pump();
      expect(find.text(_checkingTitle), findsNothing);
      expect(find.text(_intactTitle), findsOneWidget);
    }
  });

  testWidgets('test_audit_log_tab_init_state_property_empty_log_checks_too', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109409);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = ScriptedAuditRepository(
        entries: const <AuditEntry>[],
      );
      await tester.pumpWidget(const SizedBox.shrink());

      await pumpAuditLogTab(tester, random, audit);

      expect(audit.verifyCount, 1);
      expect(find.text(_checkingTitle), findsNothing);
    }
  });

  testWidgets('test_audit_log_tab_dispose_property_stops_listening', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109410);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);

      await tester.pumpWidget(const SizedBox.shrink());

      expect(audit.isListenedTo, isFalse);
    }
  });

  testWidgets('test_audit_log_tab_dispose_property_late_answers_are_quiet', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109411);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      final Completer<ChainSummary> answer = Completer<ChainSummary>();
      audit.plannedAnswer = () => answer.future;
      await pumpAuditLogTab(tester, random, audit);
      await tester.pumpWidget(const SizedBox.shrink());

      answer.complete(summarizeAuditChain(audit.listEntries()));
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_audit_log_tab_dispose_property_growth_after_is_ignored', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109412);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);
      await tester.pumpWidget(const SizedBox.shrink());

      audit.replaceEntries(<AuditEntry>[
        buildNextAuditEntry(random, audit.listEntries()),
        ...audit.listEntries(),
      ]);
      await tester.pump();

      expect(audit.verifyCount, 1);
      expect(tester.takeException(), isNull);
    }
  });
}
