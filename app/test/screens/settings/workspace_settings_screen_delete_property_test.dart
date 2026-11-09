import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/workspace.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import 'support/settings_screen_harness.dart';

const String _runningTaskRefusal =
    'a task in workspace acme is running; cancel its run first';
const String _refusalTitle = 'Delete workspace did not work';

typedef _DeletionPage = ({
  AppDependencies dependencies,
  AppNavigation navigation,
  Workspace doomed,
});

Future<_DeletionPage> _openSettingsOnCreatedWorkspace(
  WidgetTester tester,
  Random random,
  int position,
) async {
  final AppDependencies dependencies = buildGalleryDependencies();
  await createRandomWorkspaces(random, dependencies);
  final Workspace doomed = await dependencies.workspaceRepository
      .createWorkspace(name: 'doomed-$position');
  await dependencies.workspaceRepository.switchWorkspace(doomed.id);
  final AppNavigation navigation = await pumpSettingsScreen(
    tester,
    size: randomWindowSize(random),
    dependencies: dependencies,
  );
  return (dependencies: dependencies, navigation: navigation, doomed: doomed);
}

Workspace _findFirstOther(List<Workspace> workspaces, Workspace doomed) {
  return workspaces.firstWhere(
    (Workspace workspace) => workspace.id != doomed.id,
  );
}

void main() {
  testWidgets('test_build_delete_button_property_on_only_with_another_space', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311081);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      await createRandomWorkspaces(random, dependencies);
      if (random.nextBool()) {
        await dependencies.workspaceRepository.deleteWorkspace(
          GalleryWorkspaceIds.personal,
        );
      }
      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: dependencies,
      );

      final int workspaceCount = dependencies.workspaceRepository
          .listWorkspaces()
          .length;
      final AppButton button = tester.widget<AppButton>(
        findSettingsDeleteButton(),
      );
      expect(button.onPressed != null, workspaceCount > 1);
    }
  });

  testWidgets('test_build_delete_button_property_keep_changes_nothing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311082);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletionPage page = await _openSettingsOnCreatedWorkspace(
        tester,
        random,
        i,
      );
      final List<Workspace> before = page.dependencies.workspaceRepository
          .listWorkspaces();

      await tapLastButton(tester, deleteWorkspaceLabel);
      expect(find.text('Delete ${page.doomed.name}?'), findsOneWidget);
      await tapLastButton(tester, keepWorkspaceLabel);

      expect(
        identical(
          page.dependencies.workspaceRepository.listWorkspaces(),
          before,
        ),
        isTrue,
      );
      expect(page.navigation.currentRoute, settingsRoute);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_delete_button_property_delete_leaves_for_projects', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311083);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletionPage page = await _openSettingsOnCreatedWorkspace(
        tester,
        random,
        i,
      );

      await tapLastButton(tester, deleteWorkspaceLabel);
      await tapLastButton(tester, deleteWorkspaceLabel);

      final List<Workspace> after = page.dependencies.workspaceRepository
          .listWorkspaces();
      expect(after.any((Workspace w) => w.id == page.doomed.id), isFalse);
      expect(page.navigation.currentRoute, projectsRoute);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_delete_button_property_refused_while_a_task_runs', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311084);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      await createRandomWorkspaces(random, dependencies);
      await dependencies.workspaceRepository.switchWorkspace(
        GalleryWorkspaceIds.acme,
      );
      final int countBefore = dependencies.workspaceRepository
          .listWorkspaces()
          .length;
      final AppNavigation navigation = await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: dependencies,
      );

      await tapLastButton(tester, deleteWorkspaceLabel);
      await tapLastButton(tester, deleteWorkspaceLabel);

      expect(find.text(_refusalTitle), findsOneWidget);
      expect(find.text(_runningTaskRefusal), findsOneWidget);
      expect(
        dependencies.workspaceRepository.listWorkspaces().length,
        countBefore,
      );
      expect(navigation.currentRoute, settingsRoute);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_find_next_workspace_property_prompt_names_first_other', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311085);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletionPage page = await _openSettingsOnCreatedWorkspace(
        tester,
        random,
        i,
      );
      final Workspace next = _findFirstOther(
        page.dependencies.workspaceRepository.listWorkspaces(),
        page.doomed,
      );

      await tapLastButton(tester, deleteWorkspaceLabel);

      expect(find.textContaining('You switch to ${next.name}.'), findsOne);
      await tapLastButton(tester, keepWorkspaceLabel);
    }
  });

  testWidgets('test_find_next_workspace_property_prompt_matches_the_outcome', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311086);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _DeletionPage page = await _openSettingsOnCreatedWorkspace(
        tester,
        random,
        i,
      );
      final Workspace next = _findFirstOther(
        page.dependencies.workspaceRepository.listWorkspaces(),
        page.doomed,
      );

      await tapLastButton(tester, deleteWorkspaceLabel);
      await tapLastButton(tester, deleteWorkspaceLabel);

      final Workspace current = page.dependencies.workspaceRepository
          .currentWorkspace();
      expect(current.id, next.id);
    }
  });

  testWidgets('test_find_next_workspace_property_never_names_the_doomed_one', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(311087);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Workspace> workspaces = await createRandomWorkspaces(
        random,
        dependencies,
      );
      final Workspace doomed = pickOne(random, workspaces);
      await dependencies.workspaceRepository.switchWorkspace(doomed.id);
      await pumpSettingsScreen(
        tester,
        size: randomWindowSize(random),
        dependencies: dependencies,
      );

      await tapLastButton(tester, deleteWorkspaceLabel);

      expect(
        find.textContaining('You switch to ${doomed.name}.'),
        findsNothing,
      );
      expect(find.text('Delete ${doomed.name}?'), findsOneWidget);
      await tapLastButton(tester, keepWorkspaceLabel);
    }
  });
}
