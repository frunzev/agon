import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects/project_form.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'project_form_pumps.dart';
import 'project_form_steps.dart';

void main() {
  test('test_project_form_new_property_keeps_every_input', () {
    final Random random = seededRandom(105301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);
      final FormRecorder recorder = FormRecorder();
      final ValueKey<int> key = ValueKey<int>(random.nextInt(1 << 20));

      final ProjectForm form = buildProjectForm(
        initialProject: initial,
        folderPicker: random.nextBool() ? HeldFolderPicker() : null,
        recorder: recorder,
        key: key,
      );

      expect(form.initialProject, same(initial));
      expect(form.key, key);
      expect(form.actions, hasLength(2));
    }
  });

  testWidgets('test_project_form_new_property_shows_the_actions_in_order', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormRecorder recorder = FormRecorder();

      await pumpProjectForm(
        tester,
        random,
        buildRandomProjectForm(random, recorder),
      );

      final double leave = tester.getTopLeft(find.text(leaveLabel)).dx;
      final double save = tester.getTopLeft(find.text(saveLabel)).dx;
      final double leaveTop = tester.getTopLeft(find.text(leaveLabel)).dy;
      final double saveTop = tester.getTopLeft(find.text(saveLabel)).dy;
      expect(leave < save || leaveTop < saveTop, isTrue);
    }
  });

  testWidgets('test_project_form_new_property_leave_runs_only_its_action', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(105303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormRecorder recorder = FormRecorder();
      await pumpProjectForm(
        tester,
        random,
        buildRandomProjectForm(random, recorder),
      );

      await tapVisible(tester, find.text(leaveLabel));
      await tester.pump();

      expect(recorder.leaveCount, 1);
      expect(recorder.submitted, isEmpty);
    }
  });

  test('test_project_form_create_state_property_every_call_makes_a_fresh_'
      'state', () {
    final Random random = seededRandom(105304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ProjectForm form = buildRandomProjectForm(random, FormRecorder());
      final int count = 2 + random.nextInt(4);

      final Set<State<ProjectForm>> states = <State<ProjectForm>>{
        for (int index = 0; index < count; index += 1) form.createState(),
      };

      expect(states, hasLength(count));
    }
  });

  testWidgets('test_project_form_create_state_property_starts_from_the_'
      'initial_project', (WidgetTester tester) async {
    final Random random = seededRandom(105305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);

      await pumpProjectForm(
        tester,
        random,
        buildProjectForm(
          initialProject: initial,
          folderPicker: null,
          recorder: FormRecorder(),
          key: null,
        ),
      );

      expect(findFieldText(nameLabel, initial.name), findsOneWidget);
      expect(
        readRepositoryRowTitles(tester),
        describeExpectedRowTitles(initial),
      );
    }
  });

  testWidgets('test_project_form_create_state_property_starts_with_the_'
      'initial_choices', (WidgetTester tester) async {
    final Random random = seededRandom(105306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final DraftedProject initial = randomInitialProject(random);

      await pumpProjectForm(
        tester,
        random,
        buildProjectForm(
          initialProject: initial,
          folderPicker: null,
          recorder: FormRecorder(),
          key: null,
        ),
      );

      final ChoiceListField<AgentAccess> access = tester.widget(
        find.byType(ChoiceListField<AgentAccess>),
      );
      final ApprovalPolicyField policy = tester.widget(
        find.byType(ApprovalPolicyField),
      );
      expect(access.selected, initial.agentAccess);
      expect(policy.selected, initial.approvalPolicy);
    }
  });
}
