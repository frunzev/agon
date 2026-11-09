import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/screens/projects/new_project_repos_field.dart';
import 'package:agent_orchestration/screens/projects/repository_rows.dart';

import '../../support/random_inputs.dart';
import 'project_form_steps.dart';
import 'repos_field_inputs.dart';

const String _computerHint =
    'Paste a GitHub address, choose a folder on this computer or create a '
    'new one. Add as many as needed.';
const String _phoneHint = 'Paste a GitHub address. Add as many as needed.';

void main() {
  testWidgets('test_new_project_repos_field_build_property_hint_and_'
      'buttons_follow_the_folder_ability', (WidgetTester tester) async {
    final Random random = seededRandom(105107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReposFieldInputs inputs = await pumpReposField(tester, random);

      final bool isComputer = inputs.hasFolderActions;
      expect(find.text(isComputer ? _computerHint : _phoneHint), findsOne);
      expect(
        find.text(
          isComputer
              ? computerRepositoryPlaceholder
              : phoneRepositoryPlaceholder,
        ),
        findsOneWidget,
      );
      expect(
        find.text(createNewFolderLabel),
        findsNWidgets(isComputer ? 1 : 0),
      );
    }
  });

  testWidgets('test_new_project_repos_field_build_property_shows_the_'
      'address_problem_only_when_given', (WidgetTester tester) async {
    final Random random = seededRandom(105108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReposFieldInputs inputs = await pumpReposField(tester, random);

      final String? problem = inputs.addressProblem;
      if (problem != null && problem.isNotEmpty) {
        expect(find.text(problem), findsOneWidget);
      }
      final TextField input = tester.widget(find.byType(TextField));
      expect(input.decoration?.errorText, problem);
    }
  });

  testWidgets('test_new_project_repos_field_build_property_typing_and_'
      'adding_reach_the_callbacks', (WidgetTester tester) async {
    final Random random = seededRandom(105109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReposFieldInputs inputs = await pumpReposField(tester, random);
      final String typed = randomTypedGitHubRepository(random).canonical;

      await tester.enterText(find.byType(TextField), typed);
      await tester.ensureVisible(find.text(addRepoLabel));
      await tester.tap(find.text(addRepoLabel));
      await tester.pump();

      expect(inputs.calls, <String>['changed $typed', 'added']);
      expect(inputs.controller.text, typed);
    }
  });

  testWidgets('test_build_rows_property_one_row_per_draft_then_the_new_'
      'folder', (WidgetTester tester) async {
    final Random random = seededRandom(105110);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReposFieldInputs inputs = await pumpReposField(tester, random);

      expect(
        readRepositoryRowTitles(tester),
        describeExpectedReposRows(inputs),
      );
      final bool showsNewFolder =
          inputs.newFolderPath != null && inputs.hasFolderActions;
      expect(find.text(newFolderNote), findsNWidgets(showsNewFolder ? 1 : 0));
    }
  });

  testWidgets('test_build_rows_property_remove_names_exactly_its_row', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105111);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReposFieldInputs inputs = await pumpReposField(tester, random);
      final int rowCount = describeExpectedReposRows(inputs).length;
      if (rowCount == 0) {
        continue;
      }
      final int rowIndex = random.nextInt(rowCount);

      await tapRemoveOfReposRow(tester, rowIndex);

      final String expected = rowIndex < inputs.drafts.length
          ? 'removed ${inputs.drafts[rowIndex].address}'
          : 'drop';
      expect(inputs.calls, <String>[expected]);
    }
  });

  testWidgets('test_build_rows_property_started_git_only_under_its_own_'
      'repo', (WidgetTester tester) async {
    final Random random = seededRandom(105112);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final ReposFieldInputs inputs = await pumpReposField(tester, random);

      final int startedCount = inputs.drafts
          .where(
            (RepositoryDraft draft) =>
                inputs.startedAddresses.contains(draft.address),
          )
          .length;
      expect(
        find.textContaining(startedGitNote, findRichText: true),
        findsNWidgets(startedCount),
      );
    }
  });
}
