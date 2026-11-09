import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';
import 'package:agent_orchestration/screens/approvals/approval_dialog.dart';

import '../../support/random_inputs.dart';
import 'support/approval_review_scene.dart';

const int _largestMinutesAgo = 60 * 24 * 10;
const int _largestDaysAhead = 300;
const Offset _outsideTheDialog = Offset(4, 4);

String _lowercaseFirstCharacter(String phrase) {
  final String firstCharacter = phrase.substring(0, 1);
  return '${firstCharacter.toLowerCase()}${phrase.substring(1)}';
}

void main() {
  testWidgets('test_ask_for_decision_property_names_the_asking_device_and_'
      'when', (WidgetTester tester) async {
    final Random random = seededRandom(96001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Device requester = pickOne(random, galleryDevices);
      final DateTime requestedAt = galleryNow.subtract(
        Duration(minutes: random.nextInt(_largestMinutesAgo)),
      );
      await openReview(
        tester,
        random,
        requester: requester,
        requestedAt: requestedAt,
      );

      final String when = describeTimeSince(requestedAt, galleryNow);
      final String askedBy =
          'Agent on ${requester.name}, ${_lowercaseFirstCharacter(when)}';
      expect(tester.takeException(), isNull);
      expect(find.text(askedBy), findsOneWidget);
    }
  });

  testWidgets('test_ask_for_decision_property_a_stamp_ahead_keeps_its_'
      'month_name', (WidgetTester tester) async {
    final Random random = seededRandom(96002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Device requester = pickOne(random, galleryDevices);
      final DateTime requestedAt = DateTime(
        galleryNow.year,
        galleryNow.month,
        galleryNow.day + 1 + random.nextInt(_largestDaysAhead),
        random.nextInt(Duration.hoursPerDay),
      );
      await openReview(
        tester,
        random,
        requester: requester,
        requestedAt: requestedAt,
      );

      final String date = formatCalendarDate(requestedAt);
      final String clock = formatClockTime(requestedAt);
      final String askedBy = 'Agent on ${requester.name}, $date $clock';
      expect(find.text(askedBy), findsOneWidget);
    }
  });

  testWidgets('test_ask_for_decision_property_dismissing_decides_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(96003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReviewScene scene = await openReview(
        tester,
        random,
        requester: pickOne(random, galleryDevices),
        requestedAt: galleryNow,
      );
      expect(find.byType(ApprovalDialog), findsOneWidget);

      await tester.tapAt(_outsideTheDialog);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(ApprovalDialog), findsNothing);
      expect(scene.refusal.attempts, 0);
      expect(scene.readStoredRequest().isPending, isTrue);
    }
  });
}
