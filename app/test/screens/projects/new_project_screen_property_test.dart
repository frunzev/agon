import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/screens/projects/new_project_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../../support/fake_task_work_links.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';
import 'project_form_steps.dart';

const String _pageTitle = 'New project';
const String _cancelLabel = 'Cancel';
const String _projectsLabel = 'Projects';
const int _mostRepositories = 3;

NewProjectScreen _buildScreen(
  AppDependencies dependencies,
  FixedFolderPicker? picker,
  Key? key,
) {
  return NewProjectScreen(
    projectRepository: dependencies.projectRepository,
    workspaceRepository: dependencies.workspaceRepository,
    deviceRepository: dependencies.deviceRepository,
    folderPicker: picker,
    navigation: AppNavigation(initialRoute: projectsRoute),
    key: key,
  );
}

TargetPlatform _randomPlatform(Random random) {
  return pickOne(random, <TargetPlatform>[
    ...computerPlatforms,
    ...phonePlatforms,
  ]);
}

Future<List<String>> _addRandomRepositories(
  WidgetTester tester,
  Random random,
) async {
  final List<String> canonicals = <String>[];
  final int count = 1 + random.nextInt(_mostRepositories);
  for (int index = 0; index < count; index += 1) {
    final TypedRepository repository = randomTypedGitHubRepository(random);
    if (canonicals.contains(repository.canonical)) {
      continue;
    }
    await addTypedRepository(tester, repository.typed);
    canonicals.add(repository.canonical);
  }
  return canonicals;
}

void main() {
  test('test_new_project_screen_new_property_keeps_every_dependency', () {
    final Random random = seededRandom(105201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final FixedFolderPicker? picker = random.nextBool()
          ? FixedFolderPicker(null)
          : null;

      final NewProjectScreen screen = _buildScreen(dependencies, picker, null);

      expect(screen.projectRepository, same(dependencies.projectRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.deviceRepository, same(dependencies.deviceRepository));
      expect(screen.folderPicker, same(picker));
    }
  });

  test('test_new_project_screen_new_property_keeps_its_key', () {
    final Random random = seededRandom(105202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ValueKey<String> key = ValueKey<String>(randomText(random));

      final NewProjectScreen screen = _buildScreen(
        buildGalleryDependencies(),
        null,
        key,
      );

      expect(screen.key, key);
    }
  });

  testWidgets('test_new_project_screen_new_property_one_page_per_route', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: null,
      );

      expect(find.byType(NewProjectScreen), findsOneWidget);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_project_screen_build_property_shows_the_design_'
      'parts_at_any_size', (WidgetTester tester) async {
    final Random random = seededRandom(105204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Size size = randomProjectWindow(random);

      await openNewProjectPage(
        tester,
        size: size,
        platform: _randomPlatform(random),
        projectRepository: null,
      );

      expect(tester.takeException(), isNull, reason: '$size');
      expect(find.text(_pageTitle), findsWidgets);
      for (final String label in <String>[
        nameLabel,
        reposLabel,
        'What agents can do',
        'Commands and pushes',
        _cancelLabel,
        createProjectLabel,
      ]) {
        expect(find.text(label), findsWidgets, reason: label);
      }
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_project_screen_build_property_cancel_and_back_'
      'create_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(105205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: null,
      );
      await addTypedRepository(
        tester,
        randomTypedGitHubRepository(random).typed,
      );

      if (random.nextBool()) {
        await tapShownText(tester, _cancelLabel);
      } else {
        await tapBackLink(tester, _projectsLabel);
      }

      expect(page.navigation.routes, <AppRoute>[projectsRoute]);
      expect(listCreatedProjects(page), isEmpty);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_new_project_screen_build_property_starts_blank', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: null,
      );

      expect(readRepositoryRowTitles(tester), isEmpty);
      final EditableText name = tester.widget(
        find
            .descendant(
              of: find.byType(NewProjectScreen),
              matching: find.byType(EditableText),
            )
            .first,
      );
      expect(name.controller.text, isEmpty);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_create_project_property_files_the_typed_project_in_the_'
      'current_workspace', (WidgetTester tester) async {
    final Random random = seededRandom(105207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: null,
      );
      final List<String> canonicals = await _addRandomRepositories(
        tester,
        random,
      );
      final String name = 'project-${random.nextInt(1000)}';

      await createWithName(tester, name);

      final Project created = listCreatedProjects(page).single;
      expect(created.name, name);
      expect(<String>[
        for (final Repository repository in created.repositories)
          repository.address,
      ], canonicals);
      expect(page.navigation.routes, <AppRoute>[
        projectsRoute,
        ProjectRoute(created.id),
      ]);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_create_project_property_every_repo_gets_the_chosen_'
      'access', (WidgetTester tester) async {
    final Random random = seededRandom(105208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: null,
      );
      await _addRandomRepositories(tester, random);
      final AgentAccess access = pickOne(random, AgentAccess.values);
      await tapShownText(tester, describeAgentAccessChoiceTitle(access));

      await createWithName(tester, 'access-${random.nextInt(1000)}');

      final Project created = listCreatedProjects(page).single;
      for (final Repository repository in created.repositories) {
        expect(repository.agentAccess, access);
      }
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_create_project_property_leaving_during_a_slow_create_'
      'keeps_where_the_person_went', (WidgetTester tester) async {
    final Random random = seededRandom(105209);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies gallery = buildGalleryDependencies();
      final HeldProjectRepository held = HeldProjectRepository(
        buildProjectRepositoryOver(gallery, const <Project>[]),
      );
      final NewProjectPage page = await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: held,
      );
      await _addRandomRepositories(tester, random);
      final Completer<void> slowNode = Completer<void>();
      held.heldCreation = slowNode;

      await createWithName(tester, 'slow-${random.nextInt(1000)}');
      await tapBackLink(tester, _projectsLabel);
      slowNode.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, <AppRoute>[projectsRoute]);
      final WorkspaceId workspaceId = page.dependencies.workspaceRepository
          .currentWorkspace()
          .id;
      expect(held.listProjects(workspaceId), hasLength(1));
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
