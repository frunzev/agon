import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/setup_input_rules.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/server_group_text.dart';
import 'package:agent_orchestration/screens/settings/app_server_section.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import '../../support/runner_pages.dart';
import '../../support/server_group_repositories.dart';
import '../support/app_server_section_harness.dart';

const String _standaloneText =
    'Relays messages and keeps the run queue. It sees only encrypted data.';
const String _hiddenPassword = 'hunter2';

final DeviceNames _deviceNames = DeviceNames(
  buildRunnerDevices(peerAddressProblem: null).listDevices(),
);

Future<AppServerGroup> _pumpGroupWithMembers(
  WidgetTester tester,
  Random random,
) async {
  AppServerGroup group = randomAppServerGroup(random);
  while (group.members.isEmpty) {
    group = randomAppServerGroup(random);
  }
  await pumpAppServerSection(
    tester,
    random,
    buildServerWorkspaces(group: group, status: randomAppServerStatus(random)),
  );
  return group;
}

Future<AppServerStatus> _pumpStandalone(
  WidgetTester tester,
  Random random,
) async {
  final AppServerStatus status = randomAppServerStatus(random);
  await pumpAppServerSection(
    tester,
    random,
    buildServerWorkspaces(
      group: AppServerGroup(
        members: const <AppServerMember>[],
        thisDeviceStanding: ThisDeviceStanding.none,
        canKeepBackup: random.nextBool(),
      ),
      status: status,
    ),
  );
  return status;
}

List<String> _readRowTitles(WidgetTester tester) {
  return <String>[
    for (final ListRowMain row in tester.widgetList<ListRowMain>(
      find.byType(ListRowMain),
    ))
      row.title,
  ];
}

String _describeMember(AppServerMember member) {
  return _deviceNames.describeDevice(member.deviceId);
}

void main() {
  testWidgets('test_build_rows_property_active_members_come_first', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerGroup group = await _pumpGroupWithMembers(tester, random);

      final List<String> expected = <String>[
        for (final AppServerMember member in group.members)
          if (member.standing == ServerStanding.active)
            _describeMember(member),
        for (final AppServerMember member in group.members)
          if (member.standing == ServerStanding.backup)
            _describeMember(member),
      ];
      final List<String> titles = _readRowTitles(tester);
      expect(titles.sublist(0, group.members.length), expected);
    }
  });

  testWidgets('test_build_rows_property_toggle_only_when_backups_allowed', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository workspaces =
          await pumpRandomAppServerSection(tester, random);
      final AppServerGroup group = workspaces.findAppServerGroup();

      final bool hasToggle = group.members.isNotEmpty && group.canKeepBackup;
      expect(findServerBackupToggle(), hasToggle ? findsOne : findsNothing);
    }
  });

  testWidgets('test_build_rows_property_each_member_has_one_described_row', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerGroup group = await _pumpGroupWithMembers(tester, random);

      final List<String> texts = readAppServerTexts(tester);
      for (final AppServerMember member in orderAppServerMembers(
        group.members,
      )) {
        final String description = describeAppServerMember(
          member,
          currentDeviceId: thisServerDeviceId,
        );
        final int titleIndex = texts.indexOf(_describeMember(member));
        expect(texts, contains(description));
        expect(titleIndex, greaterThanOrEqualTo(0));
      }
    }
  });

  testWidgets('test_build_standalone_row_property_names_the_server_host', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerStatus status = await _pumpStandalone(tester, random);

      expect(_readRowTitles(tester), <String>[
        describeServerHost(status.address),
      ]);
      expect(find.text(_standaloneText), findsOneWidget);
      expect(findServerBackupToggle(), findsNothing);
    }
  });

  testWidgets('test_build_standalone_row_property_hides_address_passwords', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpStandalone(tester, random);

      for (final String text in readAppServerTexts(tester)) {
        expect(text, isNot(contains(_hiddenPassword)));
      }
    }
  });

  testWidgets('test_build_standalone_row_property_status_follows_server', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerStatus status = await _pumpStandalone(tester, random);

      final StatusLabel label = tester.widget(find.byType(StatusLabel));
      expect(label.text, buildAppServerStatusLabel(status.state).text);
    }
  });

  testWidgets('test_build_member_row_property_only_active_rows_show_state', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerGroup group = await _pumpGroupWithMembers(tester, random);

      final int activeCount = group.members.where((AppServerMember member) {
        return member.standing == ServerStanding.active;
      }).length;
      expect(find.byType(StatusLabel), findsNWidgets(activeCount));
    }
  });

  testWidgets('test_build_member_row_property_this_device_is_marked', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerGroup group = await _pumpGroupWithMembers(tester, random);

      final int markedCount = readAppServerTexts(tester)
          .where((String text) => text.startsWith('This device · '))
          .length;
      final bool isMember =
          group.thisDeviceStanding != ThisDeviceStanding.none;
      expect(markedCount, isMember ? 1 : 0);
    }
  });

  testWidgets('test_build_member_row_property_titles_are_monospace', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109209);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerGroup group = await _pumpGroupWithMembers(tester, random);

      final List<ListRowMain> rows = tester
          .widgetList<ListRowMain>(find.byType(ListRowMain))
          .toList();
      for (int index = 0; index < group.members.length; index += 1) {
        final Text title = tester.widget<Text>(
          find.text(rows[index].title).first,
        );
        expect(title.style!.fontFamily, AppTextStyles.monospace.fontFamily);
      }
    }
  });

  testWidgets('test_build_backup_toggle_row_property_on_while_keeping', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109210);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerGroup group = await _pumpGroupWithMembers(tester, random);
      if (!group.canKeepBackup) {
        continue;
      }

      final SwitchToggle toggle = tester.widget(findServerBackupToggle());
      expect(
        toggle.value,
        group.thisDeviceStanding != ThisDeviceStanding.none,
      );
    }
  });

  testWidgets('test_build_backup_toggle_row_property_hint_follows_standing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109211);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerGroup group = await _pumpGroupWithMembers(tester, random);
      if (!group.canKeepBackup) {
        continue;
      }

      final String hint = describeServerBackupHint(group.thisDeviceStanding);
      expect(find.text(hint), findsOneWidget);
    }
  });

  testWidgets('test_build_backup_toggle_row_property_named_for_everyone', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109212);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerGroup group = await _pumpGroupWithMembers(tester, random);
      if (!group.canKeepBackup) {
        continue;
      }

      expect(_readRowTitles(tester).last, keepBackupLabel);
      final SwitchToggle toggle = tester.widget(findServerBackupToggle());
      expect(toggle.semanticLabel, keepBackupLabel);
    }
  });
}
