import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/app_server_group.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/screens/settings/app_server_section.dart';
import 'package:agent_orchestration/widgets/lists/responsive_list.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import '../../support/runner_pages.dart';
import '../../support/server_group_repositories.dart';
import '../../support/widget_harness.dart';
import '../support/app_server_section_harness.dart';

const String _sectionTitle = 'App server';

ScriptedServerBackupRepository _buildRefusingBackups(String refusal) {
  return ScriptedServerBackupRepository(
    inner: buildServerGroupRepository(galleryAppServerGroup),
    startBackup: () async => throw PeopleFacingRefusal(refusal),
  );
}

Future<void> _pumpSections(WidgetTester tester, List<Widget> sections) {
  return pumpScrollableAtWidth(
    tester,
    width: desktopWidth,
    child: Column(children: sections),
  );
}

void main() {
  test('test_build_app_server_status_label_property_total_and_distinct', () {
    final Set<String> texts = <String>{};

    for (final AppServerState state in AppServerState.values) {
      final StatusLabel label = buildAppServerStatusLabel(state);
      expect(label.text.trim(), isNotEmpty);
      expect(label.icon, isNotNull);
      texts.add(label.text);
    }

    expect(texts, <String>{'Online', 'Unreachable'});
  });

  test('test_build_app_server_status_label_property_only_online_is_calm', () {
    for (final AppServerState state in AppServerState.values) {
      final StatusLabel label = buildAppServerStatusLabel(state);
      final bool isOnline = state == AppServerState.online;

      expect(label.tone == StatusTone.normal, isOnline);
      expect(label.icon == AppIconKind.online, isOnline);
      expect(label.tone == StatusTone.attention, !isOnline);
    }
  });

  test(
    'test_build_app_server_status_label_property_same_state_same_label',
    () {
      final Random random = seededRandom(109101);

      for (int i = 0; i < propertyIterations; i += 1) {
        final AppServerState state = pickOne(random, AppServerState.values);
        final StatusLabel first = buildAppServerStatusLabel(state);
        final StatusLabel second = buildAppServerStatusLabel(state);

        expect(second.text, first.text);
        expect(second.tone, first.tone);
        expect(second.icon, first.icon);
      }
    },
  );

  test('test_app_server_section_constructor_property_keeps_repositories', () {
    final Random random = seededRandom(109102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FakeWorkspaceRepository workspaces = buildServerWorkspaces(
        group: randomAppServerGroup(random),
        status: randomAppServerStatus(random),
      );

      final AppServerSection section = buildAppServerSection(workspaces);

      expect(section.workspaceRepository, same(workspaces));
      expect(section.deviceRepository, isA<FakeDeviceRepository>());
      expect(section.key, isNull);
    }
  });

  test('test_app_server_section_constructor_property_reads_nothing_yet', () {
    for (int i = 0; i < propertyIterations; i += 1) {
      final ScriptedServerBackupRepository backups = _buildRefusingBackups(
        'refused $i',
      );

      buildAppServerSection(backups);

      expect(backups.startCount, 0);
    }
  });

  test('test_app_server_section_constructor_property_keeps_the_key', () {
    final Random random = seededRandom(109104);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 30));
      final AppServerSection section = AppServerSection(
        workspaceRepository: _buildRefusingBackups('refused'),
        deviceRepository: buildRunnerDevices(peerAddressProblem: null),
        key: key,
      );

      expect(section.key, key);
    }
  });

  testWidgets('test_app_server_section_create_state_property_own_problem', (
    WidgetTester tester,
  ) async {
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String refusal = 'no backups here $i';
      await _pumpSections(tester, <Widget>[
        buildAppServerSection(_buildRefusingBackups(refusal)),
        buildAppServerSection(_buildRefusingBackups(refusal)),
      ]);

      await tapServerBackupToggle(tester, findServerBackupToggle().first);

      expect(find.text(refusal), findsOneWidget);
    }
  });

  testWidgets('test_app_server_section_create_state_property_rebuild_keeps', (
    WidgetTester tester,
  ) async {
    final ScriptedServerBackupRepository backups = _buildRefusingBackups(
      'kept refusal',
    );
    await _pumpSections(tester, <Widget>[buildAppServerSection(backups)]);
    await tapServerBackupToggle(tester, findServerBackupToggle());

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpSections(tester, <Widget>[buildAppServerSection(backups)]);

      expect(find.text('kept refusal'), findsOneWidget);
    }
  });

  testWidgets('test_app_server_section_create_state_property_new_key_resets', (
    WidgetTester tester,
  ) async {
    final ScriptedServerBackupRepository backups = _buildRefusingBackups(
      'forgotten refusal',
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpSections(tester, <Widget>[
        wrapInKeyedSection(ValueKey<int>(i), backups),
      ]);
      expect(find.text('forgotten refusal'), findsNothing);

      await tapServerBackupToggle(tester, findServerBackupToggle());
      expect(find.text('forgotten refusal'), findsOneWidget);
    }
  });

  testWidgets('test_app_server_section_build_property_titled_at_any_width', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomAppServerSection(tester, random);

      expect(readAppServerTexts(tester).first, _sectionTitle);
      expect(find.byType(ResponsiveList), findsOneWidget);
    }
  });

  testWidgets('test_app_server_section_build_property_counts_the_rows', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FakeWorkspaceRepository workspaces =
          await pumpRandomAppServerSection(tester, random);
      final AppServerGroup group = workspaces.findAppServerGroup();

      final ResponsiveList list = tester.widget(find.byType(ResponsiveList));
      final int toggleRows = group.canKeepBackup ? 1 : 0;
      final int expected = group.members.isEmpty
          ? 1
          : group.members.length + toggleRows;
      expect(list.rows, hasLength(expected));
    }
  });

  testWidgets('test_app_server_section_build_property_rebuild_reads_again', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(109107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppServerStatus status = randomAppServerStatus(random);
      final FakeWorkspaceRepository workspaces = buildServerWorkspaces(
        group: AppServerGroup(
          members: const <AppServerMember>[],
          thisDeviceStanding: ThisDeviceStanding.none,
          canKeepBackup: false,
        ),
        status: AppServerStatus(
          address: status.address,
          state: AppServerState.unreachable,
          lastConnectedAt: status.lastConnectedAt,
          retryInterval: status.retryInterval,
        ),
      );
      await pumpAppServerSection(tester, random, workspaces);
      expect(find.text('Unreachable'), findsOneWidget);

      await workspaces.retryAppServer();
      await pumpAppServerSection(tester, random, workspaces);

      expect(find.text('Online'), findsOneWidget);
      expect(find.text('Unreachable'), findsNothing);
    }
  });
}
