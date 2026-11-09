import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import 'project_form_pumps.dart';
import 'project_form_steps.dart';

const String _characterProblem = 'Use lowercase letters, digits and dashes';
const List<String> _lookAlikeCharacters = <String>[
  '\uFEFF',
  '\u200B',
  '\u180E',
  '\u2060',
];
const List<String> _fieldOrder = <String>[
  nameLabel,
  reposLabel,
  'What agents can do',
  'Commands and pushes',
  saveLabel,
];
final RuleTitleWhiteSpaceTable _whiteSpaceTable =
    readRuleTitleWhiteSpaceTable();

void main() {
  testWidgets('test_read_project_property_an_untouched_form_saves_its_'
      'initial_project', (WidgetTester tester) async {
    final Random random = seededRandom(105401);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);
      final FormRecorder recorder = await pumpRandomProjectForm(
        tester,
        random,
        initial,
      );

      await saveProjectForm(tester);

      final DraftedProject saved = recorder.submitted.single;
      expect(saved.name, initial.name);
      expect(
        listDraftAddresses(saved.repositories),
        listDraftAddresses(initial.repositories),
      );
      expect(saved.agentAccess, initial.agentAccess);
      expect(saved.approvalPolicy, initial.approvalPolicy);
    }
  });

  testWidgets('test_read_project_property_unicode_white_space_around_the_'
      'name_is_trimmed', (WidgetTester tester) async {
    final Random random = seededRandom(105402);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);
      final FormRecorder recorder = await pumpRandomProjectForm(
        tester,
        random,
        initial,
      );
      final String padded =
          '${_whiteSpaceTable.randomWhiteSpaceRun(random)}${initial.name}'
          '${_whiteSpaceTable.randomWhiteSpaceRun(random)}';

      await enterSettledText(tester, label: nameLabel, text: padded);
      await saveProjectForm(tester);

      expect(recorder.submitted.single.name, initial.name);
    }
  });

  testWidgets('test_read_project_property_look_alike_characters_are_not_'
      'white_space', (WidgetTester tester) async {
    final Random random = seededRandom(105403);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);
      final FormRecorder recorder = await pumpRandomProjectForm(
        tester,
        random,
        initial,
      );
      final String lookAlike = pickOne(random, _lookAlikeCharacters);
      final String typed = random.nextBool()
          ? '$lookAlike${initial.name}'
          : '${initial.name}$lookAlike';

      await enterSettledText(tester, label: nameLabel, text: typed);
      await saveProjectForm(tester);

      expect(recorder.submitted, isEmpty, reason: typed.runes.toString());
      expect(find.text(_characterProblem), findsOneWidget);
    }
  });

  testWidgets('test_project_form_build_property_fields_follow_the_design_'
      'order', (WidgetTester tester) async {
    final Random random = seededRandom(105404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomProjectForm(
        tester,
        random,
        randomInitialProject(random),
      );

      double previousTop = double.negativeInfinity;
      for (final String label in _fieldOrder) {
        final double top = tester.getTopLeft(find.text(label).first).dy;
        expect(top, greaterThan(previousTop), reason: label);
        previousTop = top;
      }
    }
  });

  testWidgets('test_project_form_build_property_long_names_and_many_repos_'
      'fit', (WidgetTester tester) async {
    final Random random = seededRandom(105405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);
      final double width = await pumpProjectForm(
        tester,
        random,
        buildProjectForm(
          initialProject: DraftedProject(
            name: 'a' * 40,
            repositories: initial.repositories,
            agentAccess: initial.agentAccess,
            approvalPolicy: initial.approvalPolicy,
          ),
          folderPicker: random.nextBool() ? HeldFolderPicker() : null,
          recorder: FormRecorder(),
          key: null,
        ),
      );

      final Rect save = tester.getRect(find.text(saveLabel));
      expect(save.right, lessThanOrEqualTo(width));
    }
  });

  testWidgets('test_project_form_build_property_name_field_is_plain_'
      'monospace', (WidgetTester tester) async {
    final Random random = seededRandom(105406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpRandomProjectForm(
        tester,
        random,
        randomInitialProject(random),
      );

      final TextField name = tester.widget(findFieldInput(nameLabel));
      expect(name.autocorrect, isFalse);
      expect(name.style?.fontFamily, isNotNull);
      expect(name.decoration?.errorText, isNull);
    }
  });
}
