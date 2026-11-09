import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/presentation/server_group_text.dart';

import '../../support/random_inputs.dart';
import '../../support/server_group_repositories.dart';
import '../support/app_server_section_harness.dart';

const String _thisBackupText =
    'This device · Backup · keeps a live copy and takes over when the '
    'active server is off.';

AppServerGroup _withStanding(ThisDeviceStanding standing) {
  final List<AppServerMember> members = <AppServerMember>[
    ...galleryAppServerGroup.members,
    if (standing == ThisDeviceStanding.backup)
      const AppServerMember(
        deviceId: thisServerDeviceId,
        standing: ServerStanding.backup,
        copy: null,
      ),
  ];
  return AppServerGroup(
    members: members,
    thisDeviceStanding: standing,
    canKeepBackup: true,
  );
}

Future<FakeWorkspaceRepository> _pumpStanding(
  WidgetTester tester,
  Random random,
  ThisDeviceStanding standing,
) async {
  final FakeWorkspaceRepository workspaces = buildServerWorkspaces(
    group: _withStanding(standing),
    status: randomAppServerStatus(random),
  );
  await pumpAppServerSection(tester, random, workspaces);
  return workspaces;
}

void main() {
  testWidgets('test_choose_backup_switch_handler_property_active_is_locked', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpAppServerSection(
        tester,
        random,
        buildServerWorkspaces(
          group: AppServerGroup(
            members: const <AppServerMember>[
              AppServerMember(
                deviceId: thisServerDeviceId,
                standing: ServerStanding.active,
                copy: null,
              ),
            ],
            thisDeviceStanding: ThisDeviceStanding.active,
            canKeepBackup: true,
          ),
          status: randomAppServerStatus(random),
        ),
      );

      expect(readServerBackupToggle(tester).value, isTrue);
      expect(readServerBackupToggle(tester).onChanged, isNull);
    }
  });

  testWidgets('test_choose_backup_switch_handler_property_others_can_flip', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ThisDeviceStanding standing = pickOne(
        random,
        const <ThisDeviceStanding>[
          ThisDeviceStanding.backup,
          ThisDeviceStanding.none,
        ],
      );
      await _pumpStanding(tester, random, standing);

      expect(readServerBackupToggle(tester).onChanged, isNotNull);
    }
  });

  testWidgets('test_choose_backup_switch_handler_property_locked_while_busy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Completer<AppServerGroup> answer = Completer<AppServerGroup>();
      final FakeWorkspaceRepository inner = buildServerGroupRepository(
        galleryAppServerGroup,
      );
      final ScriptedServerBackupRepository backups =
          ScriptedServerBackupRepository(
            inner: inner,
            startBackup: () => answer.future,
          );
      await pumpAppServerSection(tester, random, backups);

      await tapServerBackupToggle(tester, findServerBackupToggle());
      expect(readServerBackupToggle(tester).onChanged, isNull);

      answer.complete(inner.startServerBackup());
      await tester.pump();
      await tester.pump();
      expect(readServerBackupToggle(tester).onChanged, isNotNull);
      expect(backups.startCount, 1);
    }
  });

  testWidgets('test_turn_server_backup_on_property_adds_this_device_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109304);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository workspaces = await _pumpStanding(
        tester,
        random,
        ThisDeviceStanding.none,
      );

      await tapServerBackupToggle(tester, findServerBackupToggle());

      expect(find.text(_thisBackupText), findsOneWidget);
      expect(readServerBackupToggle(tester).value, isTrue);
      expect(
        workspaces.findAppServerGroup().thisDeviceStanding,
        ThisDeviceStanding.backup,
      );
    }
  });

  testWidgets('test_turn_server_backup_on_property_refusal_keeps_it_off', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String refusal = 'refused ${randomWordPhrase(random)} $i';
      await pumpAppServerSection(
        tester,
        random,
        ScriptedServerBackupRepository(
          inner: buildServerGroupRepository(galleryAppServerGroup),
          startBackup: () async => throw PeopleFacingRefusal(refusal),
        ),
      );

      await tapServerBackupToggle(tester, findServerBackupToggle());

      expect(find.text(refusal), findsOneWidget);
      expect(readServerBackupToggle(tester).value, isFalse);
      expect(find.text(_thisBackupText), findsNothing);
    }
  });

  testWidgets('test_turn_server_backup_on_property_one_tap_one_start', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository inner = buildServerGroupRepository(
        galleryAppServerGroup,
      );
      final ScriptedServerBackupRepository backups =
          ScriptedServerBackupRepository(
            inner: inner,
            startBackup: inner.startServerBackup,
          );
      await pumpAppServerSection(tester, random, backups);

      await tapServerBackupToggle(tester, findServerBackupToggle());

      expect(backups.startCount, 1);
    }
  });

  testWidgets('test_turn_server_backup_off_property_removes_this_device', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109307);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository workspaces = await _pumpStanding(
        tester,
        random,
        ThisDeviceStanding.backup,
      );
      expect(find.text(_thisBackupText), findsOneWidget);

      await tapServerBackupToggle(tester, findServerBackupToggle());

      expect(find.text(_thisBackupText), findsNothing);
      expect(readServerBackupToggle(tester).value, isFalse);
      expect(
        workspaces.findAppServerGroup().members,
        hasLength(galleryAppServerGroup.members.length),
      );
    }
  });

  testWidgets('test_turn_server_backup_off_property_round_trip_restores', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109308);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository workspaces = await _pumpStanding(
        tester,
        random,
        ThisDeviceStanding.none,
      );
      final List<String> before = readAppServerTexts(tester);

      await tapServerBackupToggle(tester, findServerBackupToggle());
      await tapServerBackupToggle(tester, findServerBackupToggle());

      expect(readAppServerTexts(tester), before);
      expect(
        workspaces.findAppServerGroup().thisDeviceStanding,
        ThisDeviceStanding.none,
      );
    }
  });

  testWidgets('test_turn_server_backup_off_property_hint_returns', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109309);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpStanding(tester, random, ThisDeviceStanding.backup);

      await tapServerBackupToggle(tester, findServerBackupToggle());

      final String hint = describeServerBackupHint(ThisDeviceStanding.none);
      expect(find.text(hint), findsOneWidget);
    }
  });
}
