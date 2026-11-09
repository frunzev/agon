import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/repository/app_server_refusal.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/presentation/audit_text.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/widgets/notice_banner.dart';

import '../../support/random_display_counts.dart';
import '../../support/random_inputs.dart';
import '../support/audit_log_tab_harness.dart';

const String _intactTitle = 'The log is intact';
const String _brokenTitle = 'The log is broken';
const String _emptyTitle = 'Nothing logged yet';

String _describeIntact(int entryCount) {
  return '${describeEntryCount(entryCount)}. Each one is signed by the '
      'device that made it, and every device keeps the latest hash.';
}

ScriptedAuditRepository _randomAudit(Random random) {
  return ScriptedAuditRepository(entries: randomNonEmptyAuditChain(random));
}

Future<void> _growLog(WidgetTester tester, ScriptedAuditRepository audit) {
  final Random random = seededRandom(audit.listEntries().length);
  audit.replaceEntries(<AuditEntry>[
    buildNextAuditEntry(random, audit.listEntries()),
    ...audit.listEntries(),
  ]);
  return tester.pump();
}

PeopleFacingRefusal _randomRefusal(Random random, String reason) {
  if (random.nextBool()) {
    return PeopleFacingRefusal(reason);
  }
  return AppServerRefusal(status: 500 + random.nextInt(99), reason: reason);
}

void main() {
  testWidgets('test_start_chain_check_property_stale_answers_lose', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      final List<Completer<ChainSummary>> answers =
          <Completer<ChainSummary>>[];
      audit.plannedAnswer = () {
        final Completer<ChainSummary> answer = Completer<ChainSummary>();
        answers.add(answer);
        return answer.future;
      };
      final ChainSummary older = summarizeAuditChain(audit.listEntries());
      await pumpAuditLogTab(tester, random, audit);
      await _growLog(tester, audit);
      final ChainSummary newer = summarizeAuditChain(audit.listEntries());

      answers.last.complete(newer);
      await tester.pump();
      answers.first.complete(older);
      await tester.pump();

      expect(find.text(_describeIntact(newer.entryCount)), findsOneWidget);
      expect(find.text(_describeIntact(older.entryCount)), findsNothing);
    }
  });

  testWidgets('test_start_chain_check_property_one_check_per_growth', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);
      final int growthCount = random.nextInt(4);

      for (int step = 0; step < growthCount; step += 1) {
        await _growLog(tester, audit);
      }

      expect(audit.verifyCount, 1 + growthCount);
    }
  });

  testWidgets('test_start_chain_check_property_banner_counts_the_latest', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);

      await _growLog(tester, audit);
      await tester.pump();

      final int entryCount = audit.listEntries().first.index + 1;
      expect(find.text(_describeIntact(entryCount)), findsOneWidget);
    }
  });

  testWidgets('test_recheck_grown_log_property_plain_notices_do_not_check', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);

      for (int step = 0; step < 1 + random.nextInt(4); step += 1) {
        audit.announceWithoutChange();
        await tester.pump();
      }

      expect(audit.verifyCount, 1);
    }
  });

  testWidgets('test_recheck_grown_log_property_older_changes_do_not_check', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);
      final List<AuditEntry> entries = audit.listEntries();

      audit.replaceEntries(<AuditEntry>[entries.first]);
      await tester.pump();

      expect(audit.verifyCount, 1);
    }
  });

  testWidgets('test_recheck_grown_log_property_unchecked_growth_not_vouched', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);
      final Completer<ChainSummary> answer = Completer<ChainSummary>();
      audit.plannedAnswer = () => answer.future;

      await _growLog(tester, audit);
      final ChainSummary grown = summarizeAuditChain(audit.listEntries());

      expect(find.text(_describeIntact(grown.entryCount)), findsNothing);
      answer.complete(grown);
      await tester.pump();
      expect(find.text(_describeIntact(grown.entryCount)), findsOneWidget);
    }
  });

  testWidgets('test_find_newest_hash_property_first_entry_starts_a_check', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = ScriptedAuditRepository(
        entries: const <AuditEntry>[],
      );
      await pumpAuditLogTab(tester, random, audit);
      expect(find.text(_emptyTitle), findsOneWidget);

      await _growLog(tester, audit);
      await tester.pump();

      expect(audit.verifyCount, 2);
      expect(find.text(_describeIntact(1)), findsOneWidget);
    }
  });

  testWidgets('test_find_newest_hash_property_emptied_log_shows_empty', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109508);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);

      audit.replaceEntries(const <AuditEntry>[]);
      await tester.pump();

      expect(find.text(_emptyTitle), findsOneWidget);
      expect(find.byType(NoticeBanner), findsNothing);
    }
  });

  testWidgets('test_find_newest_hash_property_only_the_front_counts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109509);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      await pumpAuditLogTab(tester, random, audit);
      final List<AuditEntry> entries = audit.listEntries();
      final AuditEntry newest = buildNextAuditEntry(random, entries);

      audit.replaceEntries(<AuditEntry>[...entries, newest]);
      await tester.pump();
      expect(audit.verifyCount, 1);

      audit.replaceEntries(<AuditEntry>[newest, ...entries]);
      await tester.pump();
      expect(audit.verifyCount, 2);
    }
  });

  testWidgets('test_build_chain_banner_property_intact_counts_are_grouped', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109510);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      final int entryCount = randomCountOfAnySize(random);
      final String headHash = randomAuditHash(random);
      audit.plannedAnswer = () async {
        return ChainSummary(entryCount: entryCount, headHash: headHash);
      };

      await pumpAuditLogTab(tester, random, audit);

      expect(find.text(_describeIntact(entryCount)), findsOneWidget);
      expect(find.text('Latest ${shortenIdentifier(headHash)}'), findsOne);
      expect(describeEntryCount(entryCount), isNot(matches(r'\d{4}')));
    }
  });

  testWidgets('test_build_chain_banner_property_broken_chain_is_a_danger', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109511);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      audit.plannedAnswer = () async {
        throw StateError('Audit entry $i breaks the chain');
      };

      await pumpAuditLogTab(tester, random, audit);

      final NoticeBanner banner = tester.widget(find.byType(NoticeBanner));
      expect(banner.title, _brokenTitle);
      expect(banner.tone, BannerTone.danger);
      expect(find.text(_intactTitle), findsNothing);
    }
  });

  testWidgets('test_build_chain_banner_property_refusal_is_not_tampering', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ScriptedAuditRepository audit = _randomAudit(random);
      final String reason = 'could not reach the app server $i';
      final PeopleFacingRefusal refusal = _randomRefusal(random, reason);
      audit.plannedAnswer = () async => throw refusal;

      await pumpAuditLogTab(tester, random, audit);

      expect(find.text(_brokenTitle), findsNothing);
      expect(find.text(_intactTitle), findsNothing);
      expect(find.text(reason), findsOneWidget);
    }
  });
}
