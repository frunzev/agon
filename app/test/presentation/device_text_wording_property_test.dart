import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/device_text.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

import '../bridge/support/hostile_texts.dart';
import '../bridge/support/node_json_primitives.dart';
import '../support/random_device_records.dart';
import '../support/random_inputs.dart';

const String _vowels = 'aeiou';
const String _workspaceSeparator = ', ';
const List<TargetPlatform> _desktopPlatforms = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.windows,
  TargetPlatform.linux,
];

List<Workspace> _randomWorkspaces(Random random) {
  final int count = random.nextInt(6);
  return <Workspace>[
    for (int i = 0; i < count; i += 1)
      Workspace(
        id: WorkspaceId('workspace-$i-${randomDeviceIdText(random)}'),
        name: 'name$i${randomHostileText(random).replaceAll(',', '')}',
        appServerAddress: 'peer link',
        protectedFiles: const <String>[],
        approvalPolicy: ApprovalPolicy.neverAsk,
      ),
  ];
}

ScopeCatalog _catalogOf(List<Workspace> workspaces) {
  return ScopeCatalog(workspaces: workspaces, projects: const <Project>[]);
}

List<WorkspaceId> _randomPicks(Random random, List<Workspace> workspaces) {
  if (workspaces.isEmpty) {
    return const <WorkspaceId>[];
  }
  final int count = random.nextInt(workspaces.length + 1);
  return <WorkspaceId>[
    for (int i = 0; i < count; i += 1) pickOne(random, workspaces).id,
  ];
}

void main() {
  test('test_describe_role_with_article_property_article_fits_the_sound', () {
    for (final DeviceRole role in DeviceRole.values) {
      final List<String> words = describeRoleWithArticle(role).split(' ');

      final bool startsWithVowel = _vowels.contains(words[1][0]);
      expect(words.first, startsWithVowel ? 'an' : 'a');
    }
  });

  test('test_describe_role_with_article_property_lowercase_plain_words', () {
    for (final DeviceRole role in DeviceRole.values) {
      final String phrase = describeRoleWithArticle(role);

      expect(phrase, phrase.toLowerCase());
      expect(phrase, isNot(contains('  ')), reason: phrase);
      expect(phrase.trim(), phrase);
    }
  });

  test('test_describe_this_device_kind_property_fits_after_this', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final String kind = describeThisDeviceKind(platform);

      expect(kind.trim(), kind);
      expect(kind, isNotEmpty);
      expect(kind, isNot(contains(platform.name)));
      expect(describeThisDeviceKind(platform), kind);
    }
  });

  test('test_describe_this_device_kind_property_desktops_named_apart', () {
    final Set<String> desktopKinds = <String>{
      for (final TargetPlatform platform in _desktopPlatforms)
        describeThisDeviceKind(platform),
    };

    expect(desktopKinds.length, _desktopPlatforms.length);
  });

  test('test_describe_tray_name_property_lowercase_noun_for_sentence', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      final String trayName = describeTrayName(platform);

      expect(trayName, trayName.toLowerCase());
      expect(trayName.trim(), trayName);
      expect(trayName, isNotEmpty);
    }
  });

  test('test_describe_tray_name_property_only_two_names_exist', () {
    final Set<String> trayNames = <String>{
      for (final TargetPlatform platform in TargetPlatform.values)
        describeTrayName(platform),
    };

    expect(trayNames, <String>{'menu bar', 'tray'});
  });

  test('test_describe_device_pairing_property_unknown_approver_short_id', () {
    final Random random = seededRandom(97281);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DeviceId stranger = DeviceId(randomDeviceIdText(random));
      final Device device = randomDeviceRecord(random, approvedBy: stranger);
      final DeviceNames names = DeviceNames(randomDeviceRecords(random));

      final String pairing = describeDevicePairing(device, names);

      final String pairedOn = formatCalendarDate(device.pairedAt);
      final String approverText = names.describeDevice(stranger);
      expect(pairing, '$pairedOn, approved by $approverText');
    }
  });

  test('test_describe_device_pairing_property_approver_name_kept_as_is', () {
    final Random random = seededRandom(97282);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device approver = randomDeviceRecord(random, approvedBy: null);
      final Device device = randomDeviceRecord(
        random,
        approvedBy: approver.id,
      );
      final DeviceNames names = DeviceNames(<Device>[approver, device]);

      final String pairing = describeDevicePairing(device, names);

      final String pairedOn = formatCalendarDate(device.pairedAt);
      expect(pairing, '$pairedOn, approved by ${approver.name}');
    }
  });

  test('test_describe_device_pairing_property_no_approver_only_the_date', () {
    final Random random = seededRandom(97283);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Device device = randomDeviceRecord(random, approvedBy: null);
      final DeviceNames names = DeviceNames(randomDeviceRecords(random));

      final String pairing = describeDevicePairing(device, names);

      expect(pairing, formatCalendarDate(device.pairedAt));
      expect(pairing, isNot(contains('approved')));
    }
  });

  test('test_describe_workspace_names_property_matches_the_node_rule', () {
    final Random random = seededRandom(97284);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> workspaces = _randomWorkspaces(random);
      final List<WorkspaceId> picked = _randomPicks(random, workspaces);

      final String text = describeWorkspaceNames(
        picked,
        _catalogOf(workspaces),
      );

      final List<String> memberNames = <String>[
        for (final Workspace workspace in workspaces)
          if (picked.contains(workspace.id)) workspace.name,
      ];
      expect(text, memberNames.join(_workspaceSeparator));
    }
  });

  test('test_describe_workspace_names_property_unknown_ids_are_skipped', () {
    final Random random = seededRandom(97285);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> workspaces = _randomWorkspaces(random);
      final ScopeCatalog catalog = _catalogOf(workspaces);
      final List<WorkspaceId> picked = _randomPicks(random, workspaces);
      final WorkspaceId unknown = WorkspaceId(
        'unknown-${randomDeviceIdText(random)}',
      );
      final List<WorkspaceId> withUnknown = <WorkspaceId>[...picked, unknown]
        ..shuffle(random);

      final String text = describeWorkspaceNames(withUnknown, catalog);

      expect(text, describeWorkspaceNames(picked, catalog));
      expect(text, isNot(contains(unknown.value)));
    }
  });

  test('test_describe_workspace_names_property_order_and_repeats_ignored', () {
    final Random random = seededRandom(97286);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Workspace> workspaces = _randomWorkspaces(random);
      final ScopeCatalog catalog = _catalogOf(workspaces);
      final List<WorkspaceId> picked = _randomPicks(random, workspaces);
      final List<WorkspaceId> repeated = <WorkspaceId>[...picked, ...picked]
        ..shuffle(random);

      final String text = describeWorkspaceNames(picked, catalog);

      expect(describeWorkspaceNames(repeated, catalog), text);
    }
  });
}
