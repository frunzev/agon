import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/settings.dart';

import '../../support/random_inputs.dart';
import '../../support/recording_runner_presence.dart';
import 'support/start_at_login_harness.dart';

void main() {
  testWidgets('test_start_at_login_section_build_property_no_overflow', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310988);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomStartAtLoginWidth(random);

      await pumpStartAtLogin(
        tester,
        width: width,
        presence: RecordedRunnerPresence(
          isStartAtLoginChosen: random.nextBool(),
        ).presence,
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
      expect(find.text(thisComputerTitle), findsOneWidget);
      expect(find.text(startAtLoginLabel), findsOneWidget);
      expect(find.text(startAtLoginHint), findsOneWidget);
    }
  });

  testWidgets(
    'test_start_at_login_section_build_property_problem_takes_hint',
    (WidgetTester tester) async {
      final Random random = seededRandom(310989);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final String refusal =
            'login item refused $i ${randomWordPhrase(random)}';
        await pumpStartAtLogin(
          tester,
          width: randomStartAtLoginWidth(random),
          presence: buildPresence(
            loginItem: FailingLoginItem(failure: PeopleFacingRefusal(refusal)),
            store: CountingChoiceStore(
              isStartAtLoginChosen: random.nextBool(),
            ),
          ),
        );

        await tapStartAtLoginToggle(tester);

        expect(find.text(refusal), findsOneWidget);
        expect(find.text(startAtLoginHint), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'test_start_at_login_section_build_property_hint_after_success',
    (WidgetTester tester) async {
      final Random random = seededRandom(310990);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final RecordedRunnerPresence recorded = RecordedRunnerPresence(
          isStartAtLoginChosen: random.nextBool(),
        );
        await pumpStartAtLogin(
          tester,
          width: randomStartAtLoginWidth(random),
          presence: recorded.presence,
        );

        await tapStartAtLoginToggle(tester);

        expect(find.text(startAtLoginHint), findsOneWidget);
        expect(find.text(refusedLoginItemMessage), findsNothing);
      }
    },
  );

  testWidgets('test_read_saved_choice_property_switch_shows_store_not_wish', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310991);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool storedChoice = random.nextBool();
      await pumpStartAtLogin(
        tester,
        width: randomStartAtLoginWidth(random),
        presence: buildPresence(
          loginItem: RecordingLoginItem(),
          store: StubbornChoiceStore(isStartAtLoginChosen: storedChoice),
        ),
      );

      await tapStartAtLoginToggle(tester);

      expect(readStartAtLoginToggle(tester).value, storedChoice);
    }
  });

  testWidgets(
    'test_read_saved_choice_property_reads_again_after_each_change',
    (WidgetTester tester) async {
      final Random random = seededRandom(310992);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final CountingChoiceStore store = CountingChoiceStore(
          isStartAtLoginChosen: random.nextBool(),
        );
        await pumpStartAtLogin(
          tester,
          width: randomStartAtLoginWidth(random),
          presence: buildPresence(
            loginItem: RecordingLoginItem(),
            store: store,
          ),
        );
        final int tapCount = 1 + random.nextInt(4);

        for (int tap = 0; tap < tapCount; tap += 1) {
          await tapStartAtLoginToggle(tester);
        }

        expect(store.readCount, 1 + tapCount);
      }
    },
  );

  testWidgets('test_read_saved_choice_property_refusal_shows_stored_value', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(310993);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CountingChoiceStore store = CountingChoiceStore(
        isStartAtLoginChosen: random.nextBool(),
      );
      final bool storedBefore = store.isStartAtLoginChosen;
      await pumpStartAtLogin(
        tester,
        width: randomStartAtLoginWidth(random),
        presence: buildPresence(loginItem: RefusingLoginItem(), store: store),
      );

      await tapStartAtLoginToggle(tester);

      expect(store.isStartAtLoginChosen, storedBefore);
      expect(readStartAtLoginToggle(tester).value, storedBefore);
      expect(store.readCount, 2);
    }
  });
}
