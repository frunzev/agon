import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/recording_runner_presence.dart';
import 'support/start_at_login_harness.dart';

Future<HeldLoginItem> _pumpHeldSection(
  WidgetTester tester,
  Random random, {
  required CountingChoiceStore store,
}) async {
  final HeldLoginItem loginItem = HeldLoginItem();
  loginItem.isRegistered = store.isStartAtLoginChosen;
  await pumpStartAtLogin(
    tester,
    width: randomStartAtLoginWidth(random),
    presence: buildPresence(loginItem: loginItem, store: store),
  );
  return loginItem;
}

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
  testWidgets('test_choose_switch_handler_property_enabled_when_idle', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311001);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpRecordedSection(tester, random, isChosen: random.nextBool());

      expect(readStartAtLoginToggle(tester).onChanged, isNotNull);
    }
  });

  testWidgets('test_choose_switch_handler_property_disabled_while_changing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311002);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CountingChoiceStore store = CountingChoiceStore(
        isStartAtLoginChosen: random.nextBool(),
      );
      final HeldLoginItem loginItem = await _pumpHeldSection(
        tester,
        random,
        store: store,
      );

      await tapStartAtLoginToggle(tester);
      expect(readStartAtLoginToggle(tester).onChanged, isNull);

      await _finishHeldChange(tester, loginItem);
      expect(readStartAtLoginToggle(tester).onChanged, isNotNull);
    }
  });

  testWidgets(
    'test_choose_switch_handler_property_taps_while_busy_do_nothing',
    (WidgetTester tester) async {
      final Random random = seededRandom(311003);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final CountingChoiceStore store = CountingChoiceStore(
          isStartAtLoginChosen: random.nextBool(),
        );
        final bool wanted = !store.isStartAtLoginChosen;
        final HeldLoginItem loginItem = await _pumpHeldSection(
          tester,
          random,
          store: store,
        );

        await tapStartAtLoginToggle(tester);
        final int extraTapCount = 1 + random.nextInt(3);
        for (int tap = 0; tap < extraTapCount; tap += 1) {
          await tapStartAtLoginToggle(tester);
        }
        await _finishHeldChange(tester, loginItem);

        expect(loginItem.callCount, 1);
        expect(store.isStartAtLoginChosen, wanted);
        expect(readStartAtLoginToggle(tester).value, wanted);
      }
    },
  );

  testWidgets('test_turn_start_at_login_on_property_registers_and_saves', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311004);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedRunnerPresence recorded = await _pumpRecordedSection(
        tester,
        random,
        isChosen: false,
      );

      await tapStartAtLoginToggle(tester);

      expect(recorded.loginItem.isRegistered, isTrue);
      expect(recorded.choiceStore.isStartAtLoginChosen, isTrue);
      expect(readStartAtLoginToggle(tester).value, isTrue);
    }
  });

  testWidgets('test_turn_start_at_login_on_property_calls_only_register', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311005);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedRunnerPresence recorded = await _pumpRecordedSection(
        tester,
        random,
        isChosen: false,
      );

      await tapStartAtLoginToggle(tester);

      expect(recorded.loginItem.calls, <String>[registerCall]);
      expect(recorded.trayPresence.calls, isEmpty);
    }
  });

  testWidgets('test_turn_start_at_login_on_property_refusal_saves_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311006);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CountingChoiceStore store = CountingChoiceStore(
        isStartAtLoginChosen: false,
      );
      await pumpStartAtLogin(
        tester,
        width: randomStartAtLoginWidth(random),
        presence: buildPresence(loginItem: RefusingLoginItem(), store: store),
      );

      await tapStartAtLoginToggle(tester);

      expect(store.isStartAtLoginChosen, isFalse);
      expect(readStartAtLoginToggle(tester).value, isFalse);
      expect(find.text(refusedLoginItemMessage), findsOneWidget);
    }
  });

  testWidgets('test_turn_start_at_login_off_property_unregisters_and_saves', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311007);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedRunnerPresence recorded = await _pumpRecordedSection(
        tester,
        random,
        isChosen: true,
      );

      await tapStartAtLoginToggle(tester);

      expect(recorded.loginItem.isRegistered, isFalse);
      expect(recorded.choiceStore.isStartAtLoginChosen, isFalse);
      expect(readStartAtLoginToggle(tester).value, isFalse);
    }
  });

  testWidgets('test_turn_start_at_login_off_property_calls_only_unregister', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311008);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordedRunnerPresence recorded = await _pumpRecordedSection(
        tester,
        random,
        isChosen: true,
      );

      await tapStartAtLoginToggle(tester);

      expect(recorded.loginItem.calls, <String>[unregisterCall]);
      expect(recorded.trayPresence.calls, isEmpty);
    }
  });

  testWidgets('test_turn_start_at_login_off_property_refusal_keeps_choice', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311009);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final CountingChoiceStore store = CountingChoiceStore(
        isStartAtLoginChosen: true,
      );
      await pumpStartAtLogin(
        tester,
        width: randomStartAtLoginWidth(random),
        presence: buildPresence(loginItem: RefusingLoginItem(), store: store),
      );

      await tapStartAtLoginToggle(tester);

      expect(store.isStartAtLoginChosen, isTrue);
      expect(readStartAtLoginToggle(tester).value, isTrue);
      expect(readStartAtLoginToggle(tester).onChanged, isNotNull);
    }
  });
}
