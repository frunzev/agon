import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/device_data_text.dart';

import '../bridge/support/node_json_primitives.dart';
import '../support/random_inputs.dart';

const int _largestMemberCount = 6;
const int _largestDeviceIdCount = 4;
const List<String> _wireStandingNames = <String>['active', 'backup'];

BackupCopy? _randomOptionalCopy(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return BackupCopy(
    changesBehind: random.nextInt(5000),
    verifiedAt: galleryNow.subtract(Duration(seconds: random.nextInt(90000))),
  );
}

AppServerMember _randomMember(Random random, List<DeviceId> deviceIds) {
  return AppServerMember(
    deviceId: pickOne(random, deviceIds),
    standing: pickOne(random, ServerStanding.values),
    copy: _randomOptionalCopy(random),
  );
}

List<DeviceId> _randomDeviceIds(Random random) {
  final int count = 1 + random.nextInt(_largestDeviceIdCount);
  return <DeviceId>[
    for (int i = 0; i < count; i += 1) DeviceId(randomDeviceIdText(random)),
  ];
}

List<AppServerMember> _randomMembers(Random random, List<DeviceId> ids) {
  final int count = random.nextInt(_largestMemberCount + 1);
  return <AppServerMember>[
    for (int i = 0; i < count; i += 1) _randomMember(random, ids),
  ];
}

AppServerGroup _groupOf(List<AppServerMember> members) {
  return AppServerGroup(
    members: members,
    thisDeviceStanding: ThisDeviceStanding.none,
    canKeepBackup: false,
  );
}

AppServerMember? _randomOptionalMember(Random random) {
  if (random.nextBool()) {
    return null;
  }
  return _randomMember(random, _randomDeviceIds(random));
}

void _expectPlainText(String text) {
  expect(text.trim(), isNotEmpty);
  expect(text, isNot(contains('null')));
  expect(text[0], text[0].toUpperCase(), reason: text);
  for (final String wireName in _wireStandingNames) {
    expect(text, isNot(startsWith(wireName)), reason: text);
  }
}

void main() {
  test('test_find_app_server_member_property_returns_first_listed_match', () {
    final Random random = seededRandom(97221);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<DeviceId> deviceIds = _randomDeviceIds(random);
      final List<AppServerMember> members = _randomMembers(random, deviceIds);
      final DeviceId wanted = pickOne(random, deviceIds);

      final AppServerMember? found = findAppServerMember(
        group: _groupOf(members),
        deviceId: wanted,
      );

      AppServerMember? expected;
      for (final AppServerMember member in members) {
        if (expected == null && member.deviceId == wanted) {
          expected = member;
        }
      }
      expect(identical(found, expected), isTrue);
    }
  });

  test('test_find_app_server_member_property_empty_group_finds_nothing', () {
    final Random random = seededRandom(97222);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId wanted = DeviceId(randomDeviceIdText(random));

      final AppServerMember? found = findAppServerMember(
        group: _groupOf(const <AppServerMember>[]),
        deviceId: wanted,
      );

      expect(found, isNull);
    }
  });

  test('test_find_app_server_member_property_other_members_order_free', () {
    final Random random = seededRandom(97223);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<DeviceId> deviceIds = _randomDeviceIds(random);
      final DeviceId wanted = DeviceId('wanted-${randomDeviceIdText(random)}');
      final List<AppServerMember> members = _randomMembers(random, deviceIds);
      final AppServerMember target = AppServerMember(
        deviceId: wanted,
        standing: pickOne(random, ServerStanding.values),
        copy: _randomOptionalCopy(random),
      );
      final List<AppServerMember> withTarget = <AppServerMember>[
        ...members,
        target,
      ];
      final List<AppServerMember> shuffled = List<AppServerMember>.of(
        withTarget,
      )..shuffle(random);

      final AppServerMember? found = findAppServerMember(
        group: _groupOf(shuffled),
        deviceId: wanted,
      );

      expect(identical(found, target), isTrue);
    }
  });

  test('test_describe_device_role_property_plain_text_for_every_state', () {
    final Random random = seededRandom(97224);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceRole role = pickOne(random, DeviceRole.values);
      final AppServerMember? member = _randomOptionalMember(random);

      final String text = describeDeviceRole(role: role, serverMember: member);

      _expectPlainText(text);
      expect(text, isNot(contains(role.name)), reason: text);
    }
  });

  test('test_describe_device_role_property_only_standing_matters', () {
    final Random random = seededRandom(97225);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerMember member = _randomMember(
        random,
        _randomDeviceIds(random),
      );
      final AppServerMember sameStanding = AppServerMember(
        deviceId: DeviceId(randomDeviceIdText(random)),
        standing: member.standing,
        copy: _randomOptionalCopy(random),
      );

      final String text = describeDeviceRole(
        role: pickOne(random, DeviceRole.values),
        serverMember: member,
      );

      final String sameText = describeDeviceRole(
        role: pickOne(random, DeviceRole.values),
        serverMember: sameStanding,
      );
      expect(sameText, text);
    }
  });

  test('test_describe_device_role_property_server_roles_stand_apart', () {
    final Set<String> deviceRoleLabels = <String>{
      for (final DeviceRole role in DeviceRole.values) role.label,
    };
    final Set<String> serverRoles = <String>{};

    for (final ServerStanding standing in ServerStanding.values) {
      for (final DeviceRole role in DeviceRole.values) {
        final String text = describeDeviceRole(
          role: role,
          serverMember: AppServerMember(
            deviceId: const DeviceId('server'),
            standing: standing,
            copy: null,
          ),
        );
        expect(deviceRoleLabels.contains(text), isFalse, reason: text);
        serverRoles.add(text);
      }
    }

    expect(serverRoles.length, ServerStanding.values.length);
  });

  test('test_describe_device_data_property_plain_text_for_every_state', () {
    final Random random = seededRandom(97226);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = describeDeviceData(
        serverMember: _randomOptionalMember(random),
        serverState: pickOne(random, AppServerState.values),
        now: galleryNow,
      );

      _expectPlainText(text);
    }
  });

  test('test_describe_device_data_property_active_ignores_copy_and_state', () {
    final Random random = seededRandom(97227);
    final String reference = describeDeviceData(
      serverMember: const AppServerMember(
        deviceId: DeviceId('server'),
        standing: ServerStanding.active,
        copy: null,
      ),
      serverState: AppServerState.online,
      now: galleryNow,
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerMember active = AppServerMember(
        deviceId: DeviceId(randomDeviceIdText(random)),
        standing: ServerStanding.active,
        copy: _randomOptionalCopy(random),
      );

      final String text = describeDeviceData(
        serverMember: active,
        serverState: pickOne(random, AppServerState.values),
        now: galleryNow.add(Duration(minutes: random.nextInt(9000))),
      );

      expect(text, reference);
    }
  });

  test('test_describe_device_data_property_backup_names_copy_then_state', () {
    final Random random = seededRandom(97228);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerMember backup = AppServerMember(
        deviceId: DeviceId(randomDeviceIdText(random)),
        standing: ServerStanding.backup,
        copy: _randomOptionalCopy(random),
      );
      final AppServerState serverState = pickOne(
        random,
        AppServerState.values,
      );

      final String text = describeDeviceData(
        serverMember: backup,
        serverState: serverState,
        now: galleryNow,
      );

      final List<String> parts = text.split(' · ');
      expect(parts.length, 2, reason: text);
      expect(parts.first, 'Has a copy');
      final String copyState = describeBackupCopy(
        copy: backup.copy,
        serverState: serverState,
        now: galleryNow,
      );
      expect(parts.last, copyState);
    }
  });
}
