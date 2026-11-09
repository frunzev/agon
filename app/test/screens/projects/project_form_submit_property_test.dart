import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/naming.dart';

import '../../support/app_harness.dart';
import '../../support/fake_task_work_links.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import 'project_form_steps.dart';

const List<String> _badNames = <String>[
  '',
  'Billing',
  'my app',
  'café',
  'a_b',
  'way-too-long-name-for-a-project-it-goes-on-and-on',
];
final RuleTitleWhiteSpaceTable _whiteSpaceTable =
    readRuleTitleWhiteSpaceTable();

TargetPlatform _randomPlatform(Random random) {
  return pickOne(random, <TargetPlatform>[
    ...computerPlatforms,
    ...phonePlatforms,
  ]);
}

Future<String> _addFirstRepository(
  WidgetTester tester,
  NewProjectPage page,
  Random random,
) async {
  if (canPickFolders() && random.nextBool()) {
    final String path = '$folderRoot/${randomFolderName(random)}';
    await chooseFolderPath(tester, page.picker, path);
    return describeFolderName(path);
  }
  final TypedRepository repository = randomTypedGitHubRepository(random);
  await addTypedRepository(tester, repository.typed);
  return repository.canonical.split('/').last;
}

String _readName(WidgetTester tester) {
  final TextField name = tester.widget(findFieldInput(nameLabel));
  return name.controller!.text;
}

void main() {
  testWidgets('test_fill_name_from_first_repository_property_an_empty_'
      'name_follows_the_first_repo_only', (WidgetTester tester) async {
    final Random random = seededRandom(105601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: null,
      );

      final String firstName = await _addFirstRepository(tester, page, random);
      await addTypedRepository(
        tester,
        randomTypedGitHubRepository(random).typed,
      );

      expect(_readName(tester), convertToProjectName(firstName));
      expect(describeNameProblem(_readName(tester)), isNull);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_fill_name_from_first_repository_property_a_typed_name_'
      'is_kept', (WidgetTester tester) async {
    final Random random = seededRandom(105602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: null,
      );
      final String typed = pickOne(random, <String>['mine', 'Not Valid', 'x']);
      await enterSettledText(tester, label: nameLabel, text: typed);

      await _addFirstRepository(tester, page, random);

      expect(_readName(tester), typed);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_fill_name_from_first_repository_property_a_blank_name_'
      'counts_as_empty', (WidgetTester tester) async {
    final Random random = seededRandom(105603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final NewProjectPage page = await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: null,
      );
      final String blank =
          '${pickOne(random, _whiteSpaceTable.whiteSpace)}'
          '${_whiteSpaceTable.randomWhiteSpaceRun(random)}';
      await enterSettledText(tester, label: nameLabel, text: blank);

      final String firstName = await _addFirstRepository(tester, page, random);

      expect(_readName(tester), convertToProjectName(firstName));
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_project_form_submit_property_bad_names_create_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(105604);

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
      final String name = pickOne(random, _badNames);

      await createWithName(tester, name);

      final TextField field = tester.widget(findFieldInput(nameLabel));
      expect(field.decoration?.errorText, describeNameProblem(name));
      expect(listCreatedProjects(page), isEmpty);
      expect(page.picker.prepareCount, 0);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_project_form_submit_property_a_slow_create_runs_'
      'once', (WidgetTester tester) async {
    final Random random = seededRandom(105605);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies gallery = buildGalleryDependencies();
      final HeldProjectRepository held = HeldProjectRepository(
        buildProjectRepositoryOver(gallery, const <Project>[]),
      );
      await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: held,
      );
      await addTypedRepository(
        tester,
        randomTypedGitHubRepository(random).typed,
      );
      final Completer<void> slowNode = Completer<void>();
      held.heldCreation = slowNode;

      await createWithName(tester, 'slow-${random.nextInt(1000)}');
      await tapShownText(tester, createProjectLabel);
      slowNode.complete();
      await pumpFrames(tester);

      expect(held.creationCount, 1);
    }
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('test_project_form_submit_property_typing_clears_the_name_'
      'problem', (WidgetTester tester) async {
    final Random random = seededRandom(105606);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openNewProjectPage(
        tester,
        size: randomProjectWindow(random),
        platform: _randomPlatform(random),
        projectRepository: null,
      );
      await createWithName(tester, pickOne(random, _badNames));

      await enterSettledText(tester, label: nameLabel, text: 'good-name');

      final TextField field = tester.widget(findFieldInput(nameLabel));
      expect(field.decoration?.errorText, isNull);
    }
    debugDefaultTargetPlatformOverride = null;
  });
}
