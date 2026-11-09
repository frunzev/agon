import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/device.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/data/rules/device_roles.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/tab_strip.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/recording_runner_presence.dart';
import 'support/settings_screen_harness.dart';
import 'support/start_at_login_harness.dart';

const String _removeLabel = 'Remove';
const String _intactLogTitle = 'The log is intact';

AppDependencies _buildDependenciesOnDevice(
  Device device, {
  required RunnerPresence? presence,
}) {
  return replaceRepositories(
    buildGalleryDependencies(),
    deviceRepository: FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: device.id,
      peerAddressProblem: null,
      gitlessFolderPaths: const <String>{},
    ),
    runnerPresence: presence,
  );
}

Device _findRunnerDevice() {
  return galleryDevices.firstWhere(
    (Device device) => roleRunsTasks(device.role),
  );
}

List<Type> _listShownSectionTypes() {
  return <Type>[
    for (final SettingsTab tab in SettingsTab.values)
      if (findInSettingsScreen(find.byType(sectionTypeOfTab(tab)))
          .evaluate()
          .isNotEmpty)
        sectionTypeOfTab(tab),
  ];
}

void main() {
  testWidgets('test_find_start_at_login_presence_property_only_on_runners', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311061);
    for (final Device device in galleryDevices) {
      final RecordedRunnerPresence recorded = RecordedRunnerPresence(
        isStartAtLoginChosen: random.nextBool(),
      );
      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: _buildDependenciesOnDevice(
          device,
          presence: recorded.presence,
        ),
      );

      final Matcher expected = roleRunsTasks(device.role)
          ? findsOneWidget
          : findsNothing;
      expect(findStartAtLoginToggle(), expected, reason: device.name);
      expect(find.text(thisComputerTitle), expected, reason: device.name);
    }
  });

  testWidgets('test_find_start_at_login_presence_property_needs_a_presence', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311062);
    for (int i = 0; i < galleryDevices.length; i += 1) {
      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: _buildDependenciesOnDevice(
          galleryDevices[i],
          presence: null,
        ),
      );

      expect(findStartAtLoginToggle(), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'test_find_start_at_login_presence_property_only_on_server_tab',
    (WidgetTester tester) async {
      final Random random = seededRandom(311063);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        await pumpSettingsScreen(
          tester,
          size: randomWindowSize(random),
          dependencies: _buildDependenciesOnDevice(
            _findRunnerDevice(),
            presence: RecordedRunnerPresence(
              isStartAtLoginChosen: random.nextBool(),
            ).presence,
          ),
        );
        final SettingsTab tab = pickOne(random, SettingsTab.values);

        await selectSettingsTab(tester, tab);

        final Matcher expected = tab == SettingsTab.server
            ? findsOneWidget
            : findsNothing;
        expect(findStartAtLoginToggle(), expected, reason: tab.label);
      }
    },
  );

  testWidgets('test_select_tab_property_selection_follows_the_last_tap', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311064);
    await pumpSettingsScreen(
      tester,
      size: randomWindowSize(random),
      dependencies: buildGalleryDependencies(),
    );

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SettingsTab tab = pickOne(random, SettingsTab.values);
      await selectSettingsTab(tester, tab);

      final TabStrip strip = tester.widget<TabStrip>(find.byType(TabStrip));
      expect(strip.selectedIndex, tab.index);
    }
  });

  testWidgets('test_select_tab_property_selecting_twice_changes_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311065);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: buildGalleryDependencies(),
      );
      final SettingsTab tab = pickOne(random, SettingsTab.values);
      await selectSettingsTab(tester, tab);
      final List<Type> shownOnce = _listShownSectionTypes();

      await selectSettingsTab(tester, tab);

      expect(_listShownSectionTypes(), shownOnce);
      final TabStrip strip = tester.widget<TabStrip>(find.byType(TabStrip));
      expect(strip.selectedIndex, tab.index);
    }
  });

  testWidgets('test_select_tab_property_changes_no_workspace_setting', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311066);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Workspace> before = dependencies.workspaceRepository
          .listWorkspaces();
      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: dependencies,
      );

      final int tapCount = 1 + random.nextInt(4);
      for (int tap = 0; tap < tapCount; tap += 1) {
        await selectSettingsTab(tester, pickOne(random, SettingsTab.values));
      }

      final List<Workspace> after = dependencies.workspaceRepository
          .listWorkspaces();
      expect(identical(after, before), isTrue);
    }
  });

  testWidgets('test_build_tab_property_each_tab_shows_only_its_section', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311067);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: buildGalleryDependencies(),
      );
      final SettingsTab tab = pickOne(random, SettingsTab.values);

      await selectSettingsTab(tester, tab);

      expect(_listShownSectionTypes(), <Type>[sectionTypeOfTab(tab)]);
    }
  });

  testWidgets(
    'test_build_tab_property_files_tab_lists_the_current_workspace',
    (WidgetTester tester) async {
      final Random random = seededRandom(311068);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        final List<Workspace> workspaces = await createRandomWorkspaces(
          random,
          dependencies,
        );
        final Workspace chosen = pickOne(random, workspaces);
        await dependencies.workspaceRepository.switchWorkspace(chosen.id);
        await pumpSettingsScreen(
          tester,
          size: randomWindowSize(random),
          dependencies: dependencies,
        );

        await selectSettingsTab(tester, SettingsTab.protectedFiles);

        expect(
          find.widgetWithText(AppButton, _removeLabel),
          findsNWidgets(chosen.protectedFiles.length),
        );
      }
    },
  );

  testWidgets(
    'test_build_tab_property_commands_and_audit_tabs_use_their_data',
    (WidgetTester tester) async {
      final Random random = seededRandom(311069);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        final Workspace current = dependencies.workspaceRepository
            .currentWorkspace();
        final ApprovalPolicy policy = pickOne(random, ApprovalPolicy.values);
        await dependencies.workspaceRepository.changeApprovalPolicy(
          workspaceId: current.id,
          approvalPolicy: policy,
        );
        await pumpSettingsScreen(
          tester,
          size: randomWindowSize(random),
          dependencies: dependencies,
        );

        await selectSettingsTab(tester, SettingsTab.commandsAndPushes);
        final ChoiceListField<ApprovalPolicy> field = tester
            .widget<ChoiceListField<ApprovalPolicy>>(
              find.byType(ChoiceListField<ApprovalPolicy>),
            );
        expect(field.selected, policy);

        await selectSettingsTab(tester, SettingsTab.auditLog);
        expect(
          findInSettingsScreen(find.text(_intactLogTitle)),
          findsOneWidget,
        );
      }
    },
  );
}
