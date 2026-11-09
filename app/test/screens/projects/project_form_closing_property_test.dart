import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects/repository_rows.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'project_form_pumps.dart';
import 'project_form_steps.dart';

DraftedProject _withoutRepositories(DraftedProject project) {
  return DraftedProject(
    name: project.name,
    repositories: const <RepositoryDraft>[],
    agentAccess: project.agentAccess,
    approvalPolicy: project.approvalPolicy,
  );
}

Future<HeldFolderPicker> _saveWhilePreparing(
  WidgetTester tester,
  Random random,
  FormRecorder recorder,
) async {
  final HeldFolderPicker picker = HeldFolderPicker();
  await pumpProjectForm(
    tester,
    random,
    buildProjectForm(
      initialProject: _withoutRepositories(randomInitialProject(random)),
      folderPicker: picker,
      recorder: recorder,
      key: const ValueKey<String>('first'),
    ),
  );
  await tapVisible(tester, find.text(saveLabel));
  await tester.pump();
  return picker;
}

void main() {
  testWidgets('test_plan_first_repository_folder_property_closing_while_'
      'preparing_raises_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(106101);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldFolderPicker picker = await _saveWhilePreparing(
        tester,
        random,
        FormRecorder(),
      );

      await tester.pumpWidget(const SizedBox.shrink());
      picker.preparedFolder.complete(
        '$folderRoot/${randomFolderName(random)}',
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_plan_first_repository_folder_property_a_closed_form_'
      'saves_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(106102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormRecorder recorder = FormRecorder();
      final HeldFolderPicker picker = await _saveWhilePreparing(
        tester,
        random,
        recorder,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      picker.preparedFolder.complete(folderRoot);
      await tester.pump();
      await tester.pump();

      expect(recorder.submitted, isEmpty);
    }
  });

  testWidgets('test_plan_first_repository_folder_property_a_new_form_'
      'keeps_none_of_the_old_plan', (WidgetTester tester) async {
    final Random random = seededRandom(106103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final HeldFolderPicker picker = await _saveWhilePreparing(
        tester,
        random,
        FormRecorder(),
      );

      await pumpProjectForm(
        tester,
        random,
        buildProjectForm(
          initialProject: _withoutRepositories(randomInitialProject(random)),
          folderPicker: HeldFolderPicker(),
          recorder: FormRecorder(),
          key: const ValueKey<String>('second'),
        ),
      );
      picker.preparedFolder.complete(folderRoot);
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(newFolderNote), findsNothing);
      expect(readRepositoryRowTitles(tester), isEmpty);
    }
  });
}
