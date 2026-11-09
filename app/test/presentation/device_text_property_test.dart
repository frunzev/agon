import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/presentation/device_text.dart';

import '../bridge/support/random_moments.dart';
import '../support/random_device_records.dart';
import '../support/random_inputs.dart';

const int _secondsInFiveDays = 5 * Duration.secondsPerDay;
const int _countdownMicrosecondSpan = 20 * Duration.microsecondsPerMinute;
final RegExp _countdownPattern = RegExp(r'^Expires in (\d+):(\d\d)$');

Duration _randomSpanUpToFiveDays(Random random) {
  return Duration(
    seconds: random.nextInt(_secondsInFiveDays),
    microseconds: random.nextInt(Duration.microsecondsPerSecond),
  );
}

Duration _randomAge(Random random) {
  return _randomSpanUpToFiveDays(random) - const Duration(minutes: 1);
}

Duration _ageNearOneMinute(Random random) {
  const int spread = 2 * Duration.microsecondsPerSecond;
  final int microseconds =
      Duration.microsecondsPerMinute - spread ~/ 2 + random.nextInt(spread);
  return Duration(microseconds: microseconds);
}

int? _shownCountdownSeconds(String text) {
  final RegExpMatch? match = _countdownPattern.firstMatch(text);
  if (match == null) {
    return null;
  }
  final int minutes = int.parse(match.group(1)!);
  final int seconds = int.parse(match.group(2)!);
  return minutes * Duration.secondsPerMinute + seconds;
}

void main() {
  test('test_describe_last_seen_property_never_empty_never_just_now', () {
    final Random random = seededRandom(97261);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPreciseMoment(random);
      final DateTime lastSeen = now.subtract(_randomAge(random));

      final String text = describeLastSeen(lastSeen, now);

      expect(text.trim(), isNotEmpty);
      expect(text, isNot('Just now'));
      expect(describeLastSeen(lastSeen, now), text);
    }
  });

  test('test_describe_last_seen_property_now_ends_at_exactly_a_minute', () {
    final Random random = seededRandom(97262);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPreciseMoment(random);
      final Duration age = _ageNearOneMinute(random);

      final String text = describeLastSeen(now.subtract(age), now);

      final bool isPresent = age < const Duration(minutes: 1);
      expect(text, isPresent ? 'Now' : '1 min ago');
    }
  });

  test('test_describe_last_seen_property_future_sightings_read_now', () {
    final Random random = seededRandom(97263);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPreciseMoment(random);
      final Duration ahead = _randomSpanUpToFiveDays(random);

      expect(describeLastSeen(now.add(ahead), now), 'Now');
    }
  });

  test('test_describe_device_presence_property_this_device_always_online', () {
    final Random random = seededRandom(97264);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDeviceRecord(random, approvedBy: null);
      final DateTime now = device.lastSeen.add(_randomAge(random));

      final String presence = describeDevicePresence(
        device: device,
        thisDeviceId: device.id,
        now: now,
      );

      expect(presence, 'Online');
    }
  });

  test('test_describe_device_presence_property_offline_stays_offline', () {
    final Random random = seededRandom(97265);
    const DeviceId elsewhere = DeviceId('elsewhere');

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDeviceRecord(random, approvedBy: null);
      final DateTime now = device.lastSeen.add(_randomAge(random));
      final DateTime later = now.add(_randomAge(random).abs());

      final String presence = describeDevicePresence(
        device: device,
        thisDeviceId: elsewhere,
        now: now,
      );
      final String laterPresence = describeDevicePresence(
        device: device,
        thisDeviceId: elsewhere,
        now: later,
      );

      if (presence != 'Online') {
        expect(laterPresence, isNot('Online'));
        expect(presence.startsWith('Last seen '), isTrue, reason: presence);
      }
    }
  });

  test('test_describe_device_presence_property_never_empty_never_now', () {
    final Random random = seededRandom(97266);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDeviceRecord(random, approvedBy: null);
      final DeviceId thisDeviceId = random.nextBool()
          ? device.id
          : const DeviceId('elsewhere');

      final String presence = describeDevicePresence(
        device: device,
        thisDeviceId: thisDeviceId,
        now: device.lastSeen.add(_randomAge(random)),
      );

      expect(presence.trim(), isNotEmpty);
      expect(presence.toLowerCase(), isNot(contains('now')));
    }
  });

  test('test_describe_device_kind_line_property_ends_with_kind_label', () {
    final Random random = seededRandom(97267);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDeviceRecord(random, approvedBy: null);
      final DeviceId thisDeviceId = random.nextBool()
          ? device.id
          : const DeviceId('elsewhere');

      final String line = describeDeviceKindLine(
        device: device,
        thisDeviceId: thisDeviceId,
      );

      expect(line.endsWith(device.kind.label), isTrue, reason: line);
      expect(line, isNot(contains(device.kind.name)));
    }
  });

  test('test_describe_device_kind_line_property_own_line_adds_prefix', () {
    final Random random = seededRandom(97268);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDeviceRecord(random, approvedBy: null);

      final String ownLine = describeDeviceKindLine(
        device: device,
        thisDeviceId: device.id,
      );
      final String otherLine = describeDeviceKindLine(
        device: device,
        thisDeviceId: const DeviceId('elsewhere'),
      );

      expect(ownLine, 'This device · $otherLine');
      expect(otherLine, device.kind.label);
    }
  });

  test('test_describe_time_left_property_never_zero_while_active', () {
    final Random random = seededRandom(97269);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPreciseMoment(random);
      final Duration left = Duration(
        microseconds: 1 + random.nextInt(Duration.microsecondsPerSecond),
      );

      final String text = describeTimeLeft(expiresAt: now.add(left), now: now);

      expect(text, isNot('Expires in 0:00'));
      expect(text, isNot('Expired'));
    }
  });

  test('test_describe_time_left_property_rounds_up_to_whole_seconds', () {
    final Random random = seededRandom(97270);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPreciseMoment(random);
      final Duration left = Duration(
        microseconds: 1 + random.nextInt(_countdownMicrosecondSpan),
      );

      final String text = describeTimeLeft(expiresAt: now.add(left), now: now);
      final int? shownSeconds = _shownCountdownSeconds(text);

      expect(shownSeconds, isNotNull, reason: text);
      expect(Duration(seconds: shownSeconds!) >= left, isTrue, reason: text);
      expect(Duration(seconds: shownSeconds - 1) < left, isTrue, reason: text);
    }
  });

  test('test_describe_time_left_property_countdown_never_goes_up', () {
    final Random random = seededRandom(97271);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DateTime now = randomPreciseMoment(random);
      final DateTime expiresAt = now.add(
        Duration(microseconds: random.nextInt(_countdownMicrosecondSpan)),
      );
      final DateTime later = now.add(
        Duration(microseconds: random.nextInt(_countdownMicrosecondSpan)),
      );

      final String text = describeTimeLeft(expiresAt: expiresAt, now: now);
      final String laterText = describeTimeLeft(
        expiresAt: expiresAt,
        now: later,
      );

      final int? shown = _shownCountdownSeconds(text);
      final int? laterShown = _shownCountdownSeconds(laterText);
      if (shown == null) {
        expect(laterText, 'Expired');
        continue;
      }
      if (laterShown != null) {
        expect(laterShown, lessThanOrEqualTo(shown));
      }
    }
  });
}
