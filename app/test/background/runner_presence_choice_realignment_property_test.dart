import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/background/start_at_login_choice_store.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

import '../support/random_inputs.dart';
import '../support/recording_runner_presence.dart';
import 'support/logged_computer.dart';

final class _WriteThenFailChoiceStore implements StartAtLoginChoiceStore {
  _WriteThenFailChoiceStore({
    required this.isStartAtLoginChosen,
    required this.failure,
  });

  bool isStartAtLoginChosen;
  final StateError failure;

  @override
  Future<bool> readIsStartAtLoginChosen() async => isStartAtLoginChosen;

  @override
  Future<void> saveIsStartAtLoginChosen({required bool isChosen}) async {
    isStartAtLoginChosen = isChosen;
    throw failure;
  }
}

final class _RefusingChoiceStore implements StartAtLoginChoiceStore {
  _RefusingChoiceStore({
    required this.isStartAtLoginChosen,
    required this.failure,
  });

  final bool isStartAtLoginChosen;
  final Object failure;

  @override
  Future<bool> readIsStartAtLoginChosen() async => isStartAtLoginChosen;

  @override
  Future<void> saveIsStartAtLoginChosen({required bool isChosen}) {
    return Future<void>.error(failure);
  }
}

Future<void> _switch(RunnerPresence presence, {required bool isTurningOn}) {
  if (isTurningOn) {
    return presence.startAtLogin();
  }
  return presence.stopStartingAtLogin();
}

RunnerPresence _buildPresence(
  RecordingLoginItem loginItem,
  StartAtLoginChoiceStore store,
) {
  return RunnerPresence(
    loginItem: loginItem,
    trayPresence: RecordingTrayPresence(),
    startAtLoginChoiceStore: store,
  );
}

void main() {
  test('test_save_choice_keeping_login_item_in_line_property_a_save_that_'
      'wrote_then_failed_keeps_the_login_item_with_it', () async {
    final Random random = seededRandom(1120201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isTurningOn = random.nextBool();
      final RecordingLoginItem loginItem = RecordingLoginItem();
      loginItem.isRegistered = !isTurningOn;
      final _WriteThenFailChoiceStore store = _WriteThenFailChoiceStore(
        isStartAtLoginChosen: !isTurningOn,
        failure: StateError(randomText(random)),
      );
      final RunnerPresence presence = _buildPresence(loginItem, store);

      await expectLater(
        _switch(presence, isTurningOn: isTurningOn),
        throwsStateError,
      );

      expect(store.isStartAtLoginChosen, isTurningOn);
      expect(loginItem.isRegistered, isTurningOn);
    }
  });

  test('test_save_choice_keeping_login_item_in_line_property_rethrows_the_'
      'very_save_failure', () async {
    final Random random = seededRandom(1120202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isTurningOn = random.nextBool();
      final bool wasOn = random.nextBool();
      final Object failure = random.nextBool()
          ? PeopleFacingRefusal(randomText(random))
          : StateError(randomText(random));
      final RecordingLoginItem loginItem = RecordingLoginItem();
      loginItem.isRegistered = wasOn;
      final RunnerPresence presence = _buildPresence(
        loginItem,
        _RefusingChoiceStore(isStartAtLoginChosen: wasOn, failure: failure),
      );

      Object? caught;
      try {
        await _switch(presence, isTurningOn: isTurningOn);
      } on Object catch (problem) {
        caught = problem;
      }

      expect(caught, same(failure));
      expect(loginItem.isRegistered, wasOn);
    }
  });

  test('test_save_choice_keeping_login_item_in_line_property_a_working_save_'
      'touches_nothing_more', () async {
    final Random random = seededRandom(1120203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool isTurningOn = random.nextBool();
      final LoggedComputer computer = LoggedComputer(
        isStartAtLoginChosen: random.nextBool(),
      );
      computer.isRegistered = random.nextBool();

      await _switch(computer.presence, isTurningOn: isTurningOn);

      final List<String> expectedEvents = isTurningOn
          ? <String>[registerEvent, saveOnEvent]
          : <String>[unregisterEvent, saveOffEvent];
      expect(computer.events, expectedEvents);
      expect(computer.isRegistered, isTurningOn);
      expect(computer.isStartAtLoginChosen, isTurningOn);
    }
  });
}
