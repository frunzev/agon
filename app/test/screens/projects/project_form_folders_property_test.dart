import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/screens/projects/new_project_repos_field.dart';
import 'package:agent_orchestration/screens/projects/project_text.dart';
import 'package:agent_orchestration/screens/projects/repository_rows.dart';

import '../../support/fixed_folder_picker.dart';
import '../../support/random_inputs.dart';
import 'project_form_steps.dart';

const String _noRepositoryProblem = 'Add at least one repo';
const String _badAddressProblem = 'Paste an address like github.com/acme/repo';
const String _removeLabel = 'Remove';

Future<NewProjectPage> _openOnComputer(WidgetTester tester, Random random) {
  return openNewProjectPage(
    tester,
    size: randomProjectWindow(random),
    platform: pickOne(random, computerPlatforms),
    projectRepository: null,
  );
}

String _randomName(Random random) => 'p-${random.nextInt(10000)}';

Future<void> _planNewFolder(
  WidgetTester tester,
  FixedFolderPicker picker,
  String parent,
) async {
  picker.chosenPath = parent;
  await tapShownText(tester, createNewFolderLabel);
}

List<String> _readCreatedPaths(NewProjectPage page) {
  return <String>[
    for (final Repository repository in listCreatedProjects(
      page,
    ).single.repositories)
      parseLocalFolderAddress(repository.address)!.path,
  ];
}

void main() {
  testWidgets('test_build_local_folder_actions_property_a_chosen_folder_'
      'becomes_a_local_repo', (WidgetTester tester) async {
    final Random random = seededRandom(105501);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await _openOnComputer(tester, random);
      final String folderName = randomFolderName(random);
      final String path = '$folderRoot/$folderName';

      await chooseFolderPath(tester, page.picker, path);
      expect(readRepositoryRowTitles(tester), <String>[folderName]);
      await createWithName(tester, _randomName(random));

      expect(
        listCreatedProjects(page).single.repositories.single.address,
        describeLocalAddress(path),
      );
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_build_local_folder_actions_property_a_planned_folder_'
      'can_be_dropped', (WidgetTester tester) async {
    final Random random = seededRandom(105502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await _openOnComputer(tester, random);
      final String name = _randomName(random);
      await enterSettledText(tester, label: nameLabel, text: name);

      await _planNewFolder(tester, page.picker, folderRoot);
      expect(find.text(newFolderNote), findsOneWidget);
      await tapShownText(tester, _removeLabel);

      expect(find.text(newFolderNote), findsNothing);
      expect(readRepositoryRowTitles(tester), isEmpty);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_build_local_folder_actions_property_a_cancelled_pick_'
      'changes_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(105503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await _openOnComputer(tester, random);
      page.picker.chosenPath = null;

      await tapShownText(
        tester,
        pickOne(random, <String>[chooseFolderLabel, createNewFolderLabel]),
      );

      expect(readRepositoryRowTitles(tester), isEmpty);
      expect(page.picker.chooseCount, 1);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_describe_new_folder_path_property_follows_the_typed_'
      'name', (WidgetTester tester) async {
    final Random random = seededRandom(105504);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await _openOnComputer(tester, random);
      await _planNewFolder(tester, page.picker, folderRoot);
      final String name = _randomName(random);

      await enterSettledText(tester, label: nameLabel, text: '  $name\u3000');

      expect(readRepositoryRowTitles(tester), <String>['$folderRoot/$name']);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_describe_new_folder_path_property_the_created_repo_is_'
      'the_shown_path', (WidgetTester tester) async {
    final Random random = seededRandom(105505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await _openOnComputer(tester, random);
      await _planNewFolder(tester, page.picker, folderRoot);
      final String name = _randomName(random);
      await enterSettledText(tester, label: nameLabel, text: name);
      final List<String> shown = readRepositoryRowTitles(tester);

      await tapShownText(tester, createProjectLabel);

      expect(_readCreatedPaths(page), shown);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_describe_new_folder_path_property_no_row_without_a_'
      'chosen_place', (WidgetTester tester) async {
    final Random random = seededRandom(105506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openOnComputer(tester, random);

      final String name = _randomName(random);
      await enterSettledText(tester, label: nameLabel, text: name);

      expect(find.text(newFolderNote), findsNothing);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_plan_first_repository_folder_property_a_name_alone_'
      'names_the_first_repo', (WidgetTester tester) async {
    final Random random = seededRandom(105507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await _openOnComputer(tester, random);
      final String name = _randomName(random);

      await createWithName(tester, name);

      expect(_readCreatedPaths(page), <String>[
        '$fixedNewProjectsFolder/$name',
      ]);
      expect(page.picker.prepareCount, 1);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_plan_first_repository_folder_property_an_added_repo_'
      'needs_no_default', (WidgetTester tester) async {
    final Random random = seededRandom(105508);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await _openOnComputer(tester, random);
      final TypedRepository repository = randomTypedGitHubRepository(random);
      await addTypedRepository(tester, repository.typed);

      await createWithName(tester, _randomName(random));

      final Project created = listCreatedProjects(page).single;
      expect(created.repositories.single.address, repository.canonical);
      expect(page.picker.prepareCount, 0);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_plan_first_repository_folder_property_phones_still_'
      'need_a_repo', (WidgetTester tester) async {
    final Random random = seededRandom(105509);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: pickOne(random, phonePlatforms),
        projectRepository: null,
      );

      await createWithName(tester, _randomName(random));

      expect(find.text(_noRepositoryProblem), findsOneWidget);
      expect(listCreatedProjects(page), isEmpty);
      expect(page.picker.prepareCount, 0);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_show_repository_change_property_the_same_repo_typed_'
      'twice_is_refused', (WidgetTester tester) async {
    final Random random = seededRandom(105510);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openOnComputer(tester, random);
      final TypedRepository first = randomTypedGitHubRepository(random);
      final String sameAgain = pickOne(random, <String>[
        'https://${first.canonical}',
        '${first.canonical}.git',
        ' ${first.canonical}/',
      ]);

      await addTypedRepository(tester, first.typed);
      await addTypedRepository(tester, sameAgain);

      expect(find.text(repositoryAlreadyAddedProblem), findsOneWidget);
      expect(readRepositoryRowTitles(tester), hasLength(1));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_show_repository_change_property_typing_clears_the_'
      'problem', (WidgetTester tester) async {
    final Random random = seededRandom(105511);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openOnComputer(tester, random);

      await addTypedRepository(tester, 'nope ${random.nextInt(100)}');
      expect(find.text(_badAddressProblem), findsOneWidget);
      await enterSettledText(
        tester,
        label: reposLabel,
        text: randomTypedGitHubRepository(random).typed,
      );

      expect(find.text(_badAddressProblem), findsNothing);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_show_repository_change_property_the_same_folder_is_'
      'added_once', (WidgetTester tester) async {
    final Random random = seededRandom(105512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await _openOnComputer(tester, random);
      final String path = '$folderRoot/${randomFolderName(random)}';

      await chooseFolderPath(tester, page.picker, path);
      if (random.nextBool()) {
        await chooseFolderPath(tester, page.picker, path);
      } else {
        await addTypedRepository(tester, '$path/');
      }

      expect(find.text(repositoryAlreadyAddedProblem), findsOneWidget);
      expect(readRepositoryRowTitles(tester), <String>[
        describeFolderName(path),
      ]);
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
