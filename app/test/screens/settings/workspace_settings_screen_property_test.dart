import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/tab_strip.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../../support/recording_runner_presence.dart';
import 'support/settings_screen_harness.dart';

const List<String> _designTabLabels = <String>[
  'Server',
  'Commands and pushes',
  "Files agents can't read",
  'Audit log',
];

AppButton _readDeleteButton(WidgetTester tester) {
  return tester.widget<AppButton>(findSettingsDeleteButton());
}

void main() {
  testWidgets(
    'test_workspace_settings_screen_constructor_property_keeps_fields',
    (WidgetTester tester) async {
      final Random random = seededRandom(311041);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        final AppNavigation navigation = AppNavigation(
          initialRoute: settingsRoute,
        );
        final bool hasPresence = random.nextBool();
        final RecordedRunnerPresence recorded = RecordedRunnerPresence(
          isStartAtLoginChosen: random.nextBool(),
        );
        final Key key = ValueKey<int>(i);

        final WorkspaceSettingsScreen screen = WorkspaceSettingsScreen(
          workspaceRepository: dependencies.workspaceRepository,
          deviceRepository: dependencies.deviceRepository,
          auditRepository: dependencies.auditRepository,
          clock: dependencies.clock,
          navigation: navigation,
          runnerPresence: hasPresence ? recorded.presence : null,
          key: key,
        );

        expect(screen.workspaceRepository, dependencies.workspaceRepository);
        expect(screen.deviceRepository, dependencies.deviceRepository);
        expect(screen.auditRepository, dependencies.auditRepository);
        expect(screen.clock, dependencies.clock);
        expect(screen.navigation, navigation);
        expect(screen.runnerPresence == null, !hasPresence);
        expect(screen.key, key);
      }
    },
  );

  testWidgets(
    'test_workspace_settings_screen_constructor_property_needs_no_key',
    (WidgetTester tester) async {
      final AppDependencies dependencies = buildGalleryDependencies();

      final WorkspaceSettingsScreen screen = WorkspaceSettingsScreen(
        workspaceRepository: dependencies.workspaceRepository,
        deviceRepository: dependencies.deviceRepository,
        auditRepository: dependencies.auditRepository,
        clock: dependencies.clock,
        navigation: AppNavigation(initialRoute: settingsRoute),
        runnerPresence: null,
      );

      expect(screen.key, isNull);
      expect(screen.runnerPresence, isNull);
    },
  );

  testWidgets(
    'test_workspace_settings_screen_constructor_property_own_repository',
    (WidgetTester tester) async {
      final Random random = seededRandom(311050);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        final Workspace created = await dependencies.workspaceRepository
            .createWorkspace(name: 'own-$i');
        if (random.nextBool()) {
          await dependencies.workspaceRepository.switchWorkspace(created.id);
        }
        final String currentName = dependencies.workspaceRepository
            .currentWorkspace()
            .name;

        await pumpSettingsScreen(
          tester,
          size: randomWindowSize(random),
          dependencies: dependencies,
        );

        final String summary = describeWorkspaceSummary(currentName);
        expect(findInSettingsScreen(find.text(summary)), findsOneWidget);
      }
    },
  );

  testWidgets(
    'test_workspace_settings_screen_create_state_property_new_state',
    (WidgetTester tester) async {
      final AppDependencies dependencies = buildGalleryDependencies();
      final WorkspaceSettingsScreen screen = WorkspaceSettingsScreen(
        workspaceRepository: dependencies.workspaceRepository,
        deviceRepository: dependencies.deviceRepository,
        auditRepository: dependencies.auditRepository,
        clock: dependencies.clock,
        navigation: AppNavigation(initialRoute: settingsRoute),
        runnerPresence: null,
      );

      final State<WorkspaceSettingsScreen> first = screen.createState();
      final State<WorkspaceSettingsScreen> second = screen.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
    },
  );

  testWidgets(
    'test_workspace_settings_screen_create_state_property_tab_kept',
    (WidgetTester tester) async {
      final Random random = seededRandom(311042);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        await pumpSettingsScreen(
          tester,
          size: randomWindowSize(random),
          dependencies: dependencies,
        );
        final SettingsTab tab = pickOne(random, SettingsTab.values);
        await selectSettingsTab(tester, tab);

        await dependencies.workspaceRepository.createWorkspace(
          name: 'kept-$i',
        );
        await pumpFrames(tester);

        final TabStrip strip = tester.widget<TabStrip>(find.byType(TabStrip));
        expect(strip.selectedIndex, tab.index);
        expect(
          findInSettingsScreen(find.byType(sectionTypeOfTab(tab))),
          findsOne,
        );
      }
    },
  );

  testWidgets(
    'test_workspace_settings_screen_create_state_property_opens_server',
    (WidgetTester tester) async {
      final Random random = seededRandom(311043);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        await pumpSettingsScreen(
          tester,
          size: randomWindowSize(random),
          dependencies: buildGalleryDependencies(),
        );

        final TabStrip strip = tester.widget<TabStrip>(find.byType(TabStrip));
        expect(strip.selectedIndex, SettingsTab.server.index);
        expect(strip.labels, _designTabLabels);
      }
    },
  );

  testWidgets('test_workspace_settings_screen_build_property_no_overflow', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311044);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomWindowSize(random);
      await pumpSettingsScreen(
        tester,
        size: size,
        dependencies: buildGalleryDependencies(),
      );

      await selectSettingsTab(tester, pickOne(random, SettingsTab.values));

      expect(tester.takeException(), isNull, reason: 'size $size');
      expect(findInSettingsScreen(find.text(settingsTitle)), findsOne);
    }
  });

  testWidgets(
    'test_workspace_settings_screen_build_property_follows_a_switch',
    (WidgetTester tester) async {
      final Random random = seededRandom(311045);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        final List<Workspace> workspaces = await createRandomWorkspaces(
          random,
          dependencies,
        );
        await pumpSettingsScreen(
          tester,
          size: randomWindowSize(random),
          dependencies: dependencies,
        );
        final Workspace chosen = pickOne(random, workspaces);

        await dependencies.workspaceRepository.switchWorkspace(chosen.id);
        await pumpFrames(tester);

        final String summary = describeWorkspaceSummary(chosen.name);
        expect(findInSettingsScreen(find.text(summary)), findsOneWidget);
      }
    },
  );

  testWidgets(
    'test_workspace_settings_screen_build_property_delete_follows_list',
    (WidgetTester tester) async {
      final Random random = seededRandom(311046);
      for (int i = 0; i < widgetPropertyIterations; i += 1) {
        final AppDependencies dependencies = buildGalleryDependencies();
        await dependencies.workspaceRepository.deleteWorkspace(
          GalleryWorkspaceIds.personal,
        );
        await pumpSettingsScreen(
          tester,
          size: randomWindowSize(random),
          dependencies: dependencies,
        );
        expect(_readDeleteButton(tester).onPressed, isNull);

        await dependencies.workspaceRepository.createWorkspace(
          name: 'second-$i',
        );
        await pumpFrames(tester);

        expect(_readDeleteButton(tester).onPressed, isNotNull);
      }
    },
  );
}
