import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';

import '../../support/random_device_records.dart';
import '../../support/random_inputs.dart';
import 'support/approval_review_scene.dart';

const int _largestMinutesAgo = 600;

DateTime _randomAskedAt(Random random) {
  return galleryNow.subtract(
    Duration(minutes: random.nextInt(_largestMinutesAgo)),
  );
}

void main() {
  testWidgets('test_ask_for_decision_property_an_unknown_requester_never_'
      'crashes', (WidgetTester tester) async {
    final Random random = seededRandom(5312101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Device stranger = randomDeviceRecord(random, approvedBy: null);

      await openReview(
        tester,
        random,
        requester: stranger,
        requestedAt: _randomAskedAt(random),
      );

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_ask_for_decision_property_an_unknown_requester_reads_as_'
      'its_short_identifier', (WidgetTester tester) async {
    final Random random = seededRandom(5312102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Device stranger = randomDeviceRecord(random, approvedBy: null);

      await openReview(
        tester,
        random,
        requester: stranger,
        requestedAt: _randomAskedAt(random),
      );

      final String shortName = shortenIdentifier(stranger.id.value);
      expect(find.textContaining('Agent on $shortName, '), findsOneWidget);
    }
  });

  testWidgets('test_ask_for_decision_property_a_known_requester_is_named', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(5312103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Device requester = pickOne(random, galleryDevices);

      await openReview(
        tester,
        random,
        requester: requester,
        requestedAt: _randomAskedAt(random),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Agent on ${requester.name}, '),
        findsOneWidget,
      );
    }
  });
}
