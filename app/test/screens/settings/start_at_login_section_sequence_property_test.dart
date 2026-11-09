import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/recording_runner_presence.dart';
import 'support/start_at_login_harness.dart';

const int _largestTapCount = 6;

Future<void> _finishHeldChange(
  WidgetTester tester,
  HeldLoginItem loginItem,
) async {
  loginItem.releaseCalls();
  await pumpFrames(tester);
}

Future<RecordedRunnerPresence> _pumpRecordedSection(
  WidgetTester tester,
  Random random, {
  required bool isChosen,
}) async {
  final RecordedRunnerPresence recorded = RecordedRunnerPresence(
    isStartAtLoginChosen: isChosen,
  );
  recorded.loginItem.isRegistered = isChosen;
  await pumpStartAtLogin(
    tester,
    width: randomStartAtLoginWidth(random),
    presence: recorded.presence,
  );
  return recorded;
}

void main() {
  testWidgets('test_change_start_at_login_property_item_choice_switch_agree', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311010);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedRunnerPresence recorded = await _pumpRecordedSection(
        tester,
        random,
        isChosen: random.nextBool(),
      );
      final int tapCount = 1 + random.nextInt(_largestTapCount);

      for (int tap = 0; tap < tapCount; tap += 1) {
        await tapStartAtLoginToggle(tester);
        final bool shown = readStartAtLoginToggle(tester).value;
        expect(recorded.choiceStore.isStartAtLoginChosen, shown);
        expect(recorded.loginItem.isRegistered, shown);
      }
    }
  });

  testWidgets(
    'test_change_start_at_login_property_agrees_beside_keep_for_role',
    (WidgetTester tester) async {
      final Random random = seededRandom(311011);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final CountingChoiceStore store = CountingChoiceStore(
          isStartAtLoginChosen: random.nextBool(),
        );
        final HeldLoginItem loginItem = HeldLoginItem()
          ..isRegistered = store.isStartAtLoginChosen;
        final RunnerPresence presence = buildPresence(
          loginItem: loginItem,
          store: store,
        );
        await pumpStartAtLogin(
          tester,
          width: randomStartAtLoginWidth(random),
          presence: presence,
        );

        await tapStartAtLoginToggle(tester);
        final Future<void> kept = presence.keepForRole(DeviceRole.runner);
        while (loginItem.heldCalls.isNotEmpty) {
          await _finishHeldChange(tester, loginItem);
        }
        await kept;
        await pumpFrames(tester);

        final bool shown = readStartAtLoginToggle(tester).value;
        expect(store.isStartAtLoginChosen, shown);
        expect(loginItem.isRegistered, shown);
      }
    },
  );

  testWidgets(
    'test_change_start_at_login_property_unexplained_problem_escapes',
    (WidgetTester tester) async {
      final Random random = seededRandom(311012);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final bool isChosen = random.nextBool();
        await pumpStartAtLogin(
          tester,
          width: randomStartAtLoginWidth(random),
          presence: buildPresence(
            loginItem: FailingLoginItem(failure: StateError('broken $i')),
            store: CountingChoiceStore(isStartAtLoginChosen: isChosen),
          ),
        );
        final List<Object> escaped = <Object>[];

        await runZonedGuarded<Future<void>>(
          () => tapStartAtLoginToggle(tester),
          (Object problem, StackTrace _) => escaped.add(problem),
        );
        await pumpFrames(tester);

        expect(escaped, <Matcher>[isA<StateError>()]);
        expect(readStartAtLoginToggle(tester).value, isChosen);
        expect(readStartAtLoginToggle(tester).onChanged, isNotNull);
        expect(find.text(startAtLoginHint), findsOneWidget);
      }
    },
  );

  testWidgets('test_change_start_at_login_property_blank_refusal_escapes', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311013);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpStartAtLogin(
        tester,
        width: randomStartAtLoginWidth(random),
        presence: buildPresence(
          loginItem: FailingLoginItem(failure: PeopleFacingRefusal('  ')),
          store: CountingChoiceStore(isStartAtLoginChosen: random.nextBool()),
        ),
      );
      final List<Object> escaped = <Object>[];

      await runZonedGuarded<Future<void>>(
        () => tapStartAtLoginToggle(tester),
        (Object problem, StackTrace _) => escaped.add(problem),
      );
      await pumpFrames(tester);

      expect(escaped, <Matcher>[isA<PeopleFacingRefusal>()]);
      expect(find.text(startAtLoginHint), findsOneWidget);
    }
  });
}
