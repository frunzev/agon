import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';

import '../support/random_inputs.dart';
import 'support/logged_computer.dart';

const List<PresenceChange> _loginChanges = <PresenceChange>[
  PresenceChange.startAtLogin,
  PresenceChange.stopStartingAtLogin,
];

LoggedComputer _buildAlignedComputer(Random random) {
  final bool isOn = random.nextBool();
  final LoggedComputer computer = LoggedComputer(isStartAtLoginChosen: isOn);
  computer.isRegistered = isOn;
  return computer;
}

String _saveEventOf(PresenceChange change) {
  if (change == PresenceChange.startAtLogin) {
    return saveOnEvent;
  }
  return saveOffEvent;
}

Future<Object?> _applyCatchingFailure(
  PresenceChange change,
  LoggedComputer computer,
) async {
  try {
    await applyPresenceChange(
      change: change,
      role: DeviceRole.runner,
      presence: computer.presence,
    );
  } on Object catch (failure) {
    return failure;
  }
  return null;
}

Future<void> _expectAnyOneFailureLeavesBothEqual(
  PresenceChange change, {
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final LoggedComputer computer = _buildAlignedComputer(random);
    computer.failingEvent = pickOne(random, presenceEvents);

    await _applyCatchingFailure(change, computer);

    final String reason = '${computer.failingEvent} ${computer.events}';
    expect(
      computer.isRegistered,
      computer.isStartAtLoginChosen,
      reason: reason,
    );
  }
}

Future<void> _expectFailedSaveKeepsEarlierChoice(
  PresenceChange change, {
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final LoggedComputer computer = _buildAlignedComputer(random);
    final bool wasOn = computer.isStartAtLoginChosen;
    final String saveEvent = _saveEventOf(change);
    computer.failingEvent = saveEvent;

    final Object? failure = await _applyCatchingFailure(change, computer);

    expect(failure, isA<StateError>());
    expect((failure! as StateError).message, saveEvent);
    expect(computer.isStartAtLoginChosen, wasOn);
    expect(computer.isRegistered, wasOn);
  }
}

Future<void> _expectSequenceStaysEqual(
  PresenceChange firstChange, {
  required int seed,
}) async {
  final Random random = seededRandom(seed);

  for (int i = 0; i < propertyIterations; i += 1) {
    final LoggedComputer computer = _buildAlignedComputer(random);
    final int changeCount = 1 + random.nextInt(largestHistoryLength);

    for (int step = 0; step < changeCount; step += 1) {
      final PresenceChange change = step == 0
          ? firstChange
          : pickOne(random, _loginChanges);
      final bool isSaveFailing = random.nextBool();
      computer.failingEvent = isSaveFailing ? _saveEventOf(change) : null;
      final bool wasOn = computer.isStartAtLoginChosen;

      final Object? failure = await _applyCatchingFailure(change, computer);

      final bool expectedOn = isSaveFailing
          ? wasOn
          : change == PresenceChange.startAtLogin;
      expect(failure == null, !isSaveFailing);
      expect(computer.isStartAtLoginChosen, expectedOn);
      expect(computer.isRegistered, expectedOn);
    }
  }
}

void main() {
  test(
    'test_start_at_login_property_any_one_failure_leaves_both_equal',
    () => _expectAnyOneFailureLeavesBothEqual(
      PresenceChange.startAtLogin,
      seed: 1120101,
    ),
  );

  test(
    'test_start_at_login_property_a_failed_save_keeps_the_earlier_state',
    () => _expectFailedSaveKeepsEarlierChoice(
      PresenceChange.startAtLogin,
      seed: 1120102,
    ),
  );

  test(
    'test_start_at_login_property_saves_failing_at_random_never_split',
    () =>
        _expectSequenceStaysEqual(PresenceChange.startAtLogin, seed: 1120103),
  );

  test(
    'test_stop_starting_at_login_property_any_one_failure_leaves_both_equal',
    () => _expectAnyOneFailureLeavesBothEqual(
      PresenceChange.stopStartingAtLogin,
      seed: 1120104,
    ),
  );

  test(
    'test_stop_starting_at_login_property_a_failed_save_keeps_the_earlier_'
    'state',
    () => _expectFailedSaveKeepsEarlierChoice(
      PresenceChange.stopStartingAtLogin,
      seed: 1120105,
    ),
  );

  test(
    'test_stop_starting_at_login_property_saves_failing_at_random_never_'
    'split',
    () => _expectSequenceStaysEqual(
      PresenceChange.stopStartingAtLogin,
      seed: 1120106,
    ),
  );
}
