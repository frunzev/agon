import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/screens/shared/deletion_refusal_dialog.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import '../support/planned_refusal.dart';
import 'support/deletion_review_harness.dart';

final class _RefusedDeletion {
  _RefusedDeletion(Random random) : refusal = randomExplainedRefusal(random);

  final ExplainedRefusal refusal;
  final Completer<void> pendingAnswer = Completer<void>();

  Future<void> deleteRecord() async {
    await pendingAnswer.future;
    await Future<void>.error(refusal.problem);
  }
}

Future<(DeletionReviewRig, _RefusedDeletion)> _confirmRefusedDeletion(
  WidgetTester tester,
  Random random,
) async {
  final _RefusedDeletion deletion = _RefusedDeletion(random);
  final DeletionReviewRig rig = DeletionReviewRig(
    startingRoutes: randomRoutesUnderTheRecord(random),
    prompt: randomDeletionPrompt(random),
    deleteRecord: deletion.deleteRecord,
  );
  await pumpDeletionReview(
    tester,
    rig: rig,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
  );
  await confirmDeletion(tester, rig: rig);
  return (rig, deletion);
}

void main() {
  testWidgets('test_show_refusal_property_names_the_prompt_and_the_'
      'reason', (WidgetTester tester) async {
    final Random random = seededRandom(111701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (DeletionReviewRig rig, _RefusedDeletion deletion) =
          await _confirmRefusedDeletion(tester, random);

      deletion.pendingAnswer.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.byType(DeletionRefusalDialog), findsOneWidget);
      expect(find.text(rig.prompt.title), findsOneWidget);
      expect(find.text(describeRefusalTitle(rig.prompt)), findsOneWidget);
      expect(find.text(deletion.refusal.explanation), findsOneWidget);
    }
  });

  testWidgets('test_show_refusal_property_keep_closes_it_and_ends_the_'
      'review', (WidgetTester tester) async {
    final Random random = seededRandom(111702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (DeletionReviewRig rig, _RefusedDeletion deletion) =
          await _confirmRefusedDeletion(tester, random);
      deletion.pendingAnswer.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tapAppButton(tester, rig.prompt.keepLabel);

      expect(find.byType(DeletionRefusalDialog), findsNothing);
      expect(await rig.reviewOutcomes.single, isNull);
      expect(rig.navigation.currentRoute, reviewedRecordRoute);
    }
  });

  testWidgets('test_show_refusal_property_quiet_once_the_window_is_'
      'gone', (WidgetTester tester) async {
    final Random random = seededRandom(111703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final (DeletionReviewRig rig, _RefusedDeletion deletion) =
          await _confirmRefusedDeletion(tester, random);

      await tester.pumpWidget(const SizedBox.shrink());
      deletion.pendingAnswer.complete();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(await rig.reviewOutcomes.single, isNull);
      expect(find.byType(DeletionRefusalDialog), findsNothing);
    }
  });
}
