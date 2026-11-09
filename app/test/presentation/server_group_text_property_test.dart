import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/presentation/server_group_text.dart';

import '../bridge/support/node_json_primitives.dart';
import '../support/random_inputs.dart';

const int _mostMembers = 7;
const String _thisDevicePrefix = 'This device · ';

AppServerMember _randomMember(Random random, ServerStanding standing) {
  return AppServerMember(
    deviceId: DeviceId(randomDeviceIdText(random)),
    standing: standing,
    copy: random.nextBool()
        ? null
        : BackupCopy(
            changesBehind: random.nextInt(1000),
            verifiedAt: randomUtcMoment(random),
          ),
  );
}

List<AppServerMember> _randomMembers(Random random) {
  final int memberCount = random.nextInt(_mostMembers + 1);
  return <AppServerMember>[
    for (int i = 0; i < memberCount; i += 1)
      _randomMember(random, pickOne(random, ServerStanding.values)),
  ];
}

void main() {
  test('test_order_app_server_members_property_ordering_is_idempotent', () {
    final Random random = seededRandom(94601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppServerMember> ordered = orderAppServerMembers(
        _randomMembers(random),
      );

      expect(orderAppServerMembers(ordered), orderedEquals(ordered));
    }
  });

  test('test_order_app_server_members_property_input_kept_result_fixed', () {
    final Random random = seededRandom(94602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppServerMember> members = _randomMembers(random);
      final List<AppServerMember> membersCopy = List<AppServerMember>.of(
        members,
      );

      final List<AppServerMember> ordered = orderAppServerMembers(members);

      expect(members, orderedEquals(membersCopy));
      final AppServerMember extra = _randomMember(
        random,
        ServerStanding.backup,
      );
      expect(() => ordered.add(extra), throwsUnsupportedError);
    }
  });

  test('test_order_app_server_members_property_new_member_lands_at_edge', () {
    final Random random = seededRandom(94603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<AppServerMember> members = _randomMembers(random);
      final AppServerMember newActive = _randomMember(
        random,
        ServerStanding.active,
      );
      final AppServerMember newBackup = _randomMember(
        random,
        ServerStanding.backup,
      );

      final List<AppServerMember> ordered = orderAppServerMembers(
        <AppServerMember>[newActive, ...members, newBackup],
      );

      expect(ordered.first, same(newActive));
      expect(ordered.last, same(newBackup));
    }
  });

  test('test_describe_app_server_member_property_never_shows_device_id', () {
    final Random random = seededRandom(94604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerMember member = _randomMember(
        random,
        pickOne(random, ServerStanding.values),
      );
      final DeviceId currentDeviceId = random.nextBool()
          ? member.deviceId
          : DeviceId(randomDeviceIdText(random));

      final String text = describeAppServerMember(
        member,
        currentDeviceId: currentDeviceId,
      );

      expect(text, isNot(contains(member.deviceId.value)));
      expect(text, isNot(contains(currentDeviceId.value)));
      expect(text, endsWith('.'));
    }
  });

  test('test_describe_app_server_member_property_standing_names_role', () {
    final Random random = seededRandom(94605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ServerStanding standing = pickOne(random, ServerStanding.values);
      final AppServerMember member = _randomMember(random, standing);

      final String text = describeAppServerMember(
        member,
        currentDeviceId: DeviceId(randomDeviceIdText(random)),
      );

      final bool isActive = standing == ServerStanding.active;
      expect(text.startsWith('Active server'), isActive);
      expect(text.startsWith('Backup'), !isActive);
    }
  });

  test('test_describe_app_server_member_property_prefix_only_adds_device', () {
    final Random random = seededRandom(94606);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppServerMember member = _randomMember(
        random,
        pickOne(random, ServerStanding.values),
      );
      final String otherDeviceText = describeAppServerMember(
        member,
        currentDeviceId: DeviceId(randomDeviceIdText(random)),
      );

      final String ownText = describeAppServerMember(
        member,
        currentDeviceId: member.deviceId,
      );

      expect(ownText, '$_thisDevicePrefix$otherDeviceText');
      expect(otherDeviceText, isNot(startsWith(_thisDevicePrefix)));
    }
  });

  test(
    'test_describe_server_backup_hint_property_every_standing_sentence',
    () {
      for (final ThisDeviceStanding standing in ThisDeviceStanding.values) {
        final String hint = describeServerBackupHint(standing);

        expect(hint, startsWith('This computer '));
        expect(hint, endsWith('.'));
        expect(hint, isNot(contains('Standing')));
        expect(hint, isNot(contains(ThisDeviceStanding.none.name)));
      }
    },
  );

  test('test_describe_server_backup_hint_property_only_active_differs', () {
    final String activeHint = describeServerBackupHint(
      ThisDeviceStanding.active,
    );
    final String backupHint = describeServerBackupHint(
      ThisDeviceStanding.backup,
    );

    expect(describeServerBackupHint(ThisDeviceStanding.none), backupHint);
    expect(activeHint, isNot(backupHint));
    expect(activeHint, contains('active server'));
    expect(backupHint, contains('live copy'));
  });

  test('test_describe_server_backup_hint_property_stable_across_calls', () {
    final Random random = seededRandom(94609);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ThisDeviceStanding standing = pickOne(
        random,
        ThisDeviceStanding.values,
      );

      expect(
        describeServerBackupHint(standing),
        describeServerBackupHint(standing),
      );
    }
  });
}
