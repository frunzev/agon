import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/no_runner_text.dart';
import 'package:agent_orchestration/screens/files/no_runner_view.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const String _designTitle = 'No runner with acme/api is online';
const String _designExplanation =
    "Files come from a runner's copy of the repository, so the app server "
    'never sees your code. Only old-macbook has a copy of acme/api, and it '
    'was last seen 3 days ago.';
const String _designAdvice =
    'Turn it on, or start a task on acme/api so another runner makes a '
    'copy. The files open here as soon as one is online.';
const int _largestMinuteOffset = 20000;

final class _TapCounts {
  int tryAgain = 0;
  int seeRunners = 0;
}

NoRunnerView _randomView(Random random, _TapCounts counts) {
  final DateTime now = randomLocalMoment(random);
  return NoRunnerView(
    holders: <RepositoryHolder>[
      for (int index = 0; index < random.nextInt(5); index += 1)
        RepositoryHolder(
          deviceId: DeviceId('device-$index'),
          name: randomHostileText(random) * (1 + random.nextInt(8)),
          lastSeen: now.subtract(
            Duration(minutes: random.nextInt(_largestMinuteOffset)),
          ),
        ),
    ],
    repositoryPath: randomHostileText(random) * (1 + random.nextInt(8)),
    now: now,
    onTryAgain: () => counts.tryAgain += 1,
    onSeeRunners: () => counts.seeRunners += 1,
  );
}

String _joinSegments(List<TextSegment> segments) {
  final StringBuffer joined = StringBuffer();
  for (final TextSegment segment in segments) {
    joined.write(segment.text);
  }
  return joined.toString();
}

void main() {
  testWidgets('test_no_runner_view_build_property_shows_every_text_at_'
      'every_width', (WidgetTester tester) async {
    final Random random = seededRandom(100421);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NoRunnerView view = _randomView(random, _TapCounts());
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );

      await pumpScrollableAtWidth(tester, width: width, child: view);

      expect(tester.takeException(), isNull, reason: 'width $width');
      final String explanation = _joinSegments(
        describeNoRunnerExplanation(
          holders: view.holders,
          repositoryPath: view.repositoryPath,
          now: view.now,
        ),
      );
      final String advice = describeNoRunnerAdvice(
        holderCount: view.holders.length,
        repositoryPath: view.repositoryPath,
      );
      expect(find.text(describeNoRunnerTitle(view.repositoryPath)), findsOne);
      expect(find.text(explanation, findRichText: true), findsOneWidget);
      expect(find.text(advice), findsOneWidget);
    }
  });

  testWidgets('test_no_runner_view_build_property_each_button_calls_only_'
      'its_own_action', (WidgetTester tester) async {
    final Random random = seededRandom(100422);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _TapCounts counts = _TapCounts();
      final NoRunnerView view = _randomView(random, counts);
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: view,
      );
      final int tryAgainTaps = 1 + random.nextInt(3);
      final int seeRunnersTaps = random.nextInt(3);

      await tester.ensureVisible(find.text(tryAgainLabel));
      await tester.pump();
      for (int tap = 0; tap < tryAgainTaps; tap += 1) {
        await tester.tap(find.text(tryAgainLabel));
      }
      for (int tap = 0; tap < seeRunnersTaps; tap += 1) {
        await tester.tap(find.text(seeRunnersLabel));
      }
      await tester.pump();

      expect(counts.tryAgain, tryAgainTaps);
      expect(counts.seeRunners, seeRunnersTaps);
    }
  });

  testWidgets('test_no_runner_view_build_property_reads_like_the_design', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100423);
    final DateTime now = DateTime(2026, 11, 8, 14, 9, 40);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Duration age = Duration(days: 3, minutes: random.nextInt(60));
      await pumpScrollableAtWidth(
        tester,
        width: randomWidth(random, least: narrowestWidth, most: widestWidth),
        child: NoRunnerView(
          holders: <RepositoryHolder>[
            RepositoryHolder(
              deviceId: const DeviceId('old'),
              name: 'old-macbook',
              lastSeen: now.subtract(age),
            ),
          ],
          repositoryPath: 'acme/api',
          now: now,
          onTryAgain: () {},
          onSeeRunners: () {},
        ),
      );

      expect(find.text(_designTitle), findsOneWidget);
      expect(find.text(_designExplanation, findRichText: true), findsOne);
      expect(find.text(_designAdvice), findsOneWidget);
      final Offset title = tester.getTopLeft(find.text(_designTitle));
      final Offset tryAgain = tester.getTopLeft(find.text(tryAgainLabel));
      final Offset seeRunners = tester.getTopLeft(find.text(seeRunnersLabel));
      expect(title.dy, lessThan(tryAgain.dy));
      final bool isTryAgainFirst =
          tryAgain.dy < seeRunners.dy ||
          (tryAgain.dy == seeRunners.dy && tryAgain.dx < seeRunners.dx);
      expect(isTryAgainFirst, isTrue);
    }
  });
}
