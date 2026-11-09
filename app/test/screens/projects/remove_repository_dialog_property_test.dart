import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../support/refusing_place_repositories.dart';
import 'project_screen_inputs.dart';
import 'repository_dialog_steps.dart';

const String _removeLabel = 'Remove repo';

const Repository _sampleRepository = Repository(
  address: 'github.com/acme/sample',
  defaultBranch: 'main',
  agentAccess: AgentAccess.readOnly,
);

RemoveRepositoryDialog _buildDialog(Random random, {Key? key}) {
  final StoredProject stored = buildStoredProject(random, <Repository>[
    _sampleRepository,
  ]);
  return RemoveRepositoryDialog(
    project: stored.project,
    repository: stored.project.repositories.single,
    projectRepository: stored.repository,
    key: key,
  );
}

Future<void> _openDialog(
  WidgetTester tester,
  Random random,
  StoredProject stored,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final BuildContext hostContext = await pumpDialogHost(tester, random);
  unawaited(
    showRemoveRepositoryDialog(
      context: hostContext,
      project: stored.project,
      repository: pickOne(random, stored.project.repositories),
      projectRepository: stored.repository,
    ),
  );
  await pumpFrames(tester);
}

AppButton _removeButton(WidgetTester tester) {
  return tester.widget(find.widgetWithText(AppButton, _removeLabel));
}

List<Repository> _withSample(Random random) {
  return <Repository>[...randomScreenRepositories(random), _sampleRepository];
}

void main() {
  test('test_remove_repository_dialog_new_property_keeps_every_field', () {
    final Random random = seededRandom(1062501);

    for (int i = 0; i < propertyIterations ~/ 20; i += 1) {
      final StoredProject stored = buildStoredProject(
        random,
        _withSample(random),
      );
      final Repository repository = pickOne(
        random,
        stored.project.repositories,
      );

      final RemoveRepositoryDialog dialog = RemoveRepositoryDialog(
        project: stored.project,
        repository: repository,
        projectRepository: stored.repository,
      );

      expect(dialog.project, same(stored.project));
      expect(dialog.repository, same(repository));
      expect(dialog.projectRepository, same(stored.repository));
    }
  });

  test('test_remove_repository_dialog_new_property_keeps_the_key', () {
    final Random random = seededRandom(1062502);

    for (int i = 0; i < propertyIterations ~/ 20; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));

      expect(_buildDialog(random, key: key).key, key);
    }
  });

  test('test_remove_repository_dialog_new_property_no_key_by_default', () {
    final Random random = seededRandom(1062503);

    expect(_buildDialog(random).key, isNull);
  });

  test('test_remove_repository_dialog_create_state_property_fresh', () {
    final Random random = seededRandom(1062504);
    final RemoveRepositoryDialog dialog = _buildDialog(random);

    for (int i = 0; i < propertyIterations; i += 1) {
      final State<RemoveRepositoryDialog> first = dialog.createState();

      expect(identical(first, dialog.createState()), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_remove_repository_dialog_create_state_property_serves_'
      'its_widget', (WidgetTester tester) async {
    final Random random = seededRandom(1062505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openDialog(
        tester,
        random,
        buildStoredProject(random, _withSample(random)),
      );
      final Finder dialog = find.byType(RemoveRepositoryDialog);

      final State<RemoveRepositoryDialog> state = tester.state(dialog);

      expect(state.widget, same(tester.widget(dialog)));
    }
  });

  testWidgets('test_remove_repository_dialog_create_state_property_starts_'
      'ready_to_remove', (WidgetTester tester) async {
    final Random random = seededRandom(1062506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _openDialog(
        tester,
        random,
        buildStoredProject(random, _withSample(random)),
      );

      expect(_removeButton(tester).onPressed, isNotNull);
      expect(_removeButton(tester).tone, ButtonTone.danger);
    }
  });

  testWidgets('test_remove_repository_dialog_build_property_disabled_'
      'while_removing', (WidgetTester tester) async {
    final Random random = seededRandom(1062507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StoredProject stored = buildStoredProject(
        random,
        _withSample(random),
      );
      final HeldChangesProjectRepository held = HeldChangesProjectRepository(
        stored.repository,
      );
      await _openDialog(tester, random, (
        project: stored.project,
        repository: held,
      ));

      await tapDialogButton(tester, _removeLabel);

      expect(_removeButton(tester).onPressed, isNull);
      held.release.complete();
      await pumpFrames(tester);
      expect(find.byType(RemoveRepositoryDialog), findsNothing);
    }
  });

  testWidgets('test_remove_repository_dialog_build_property_enabled_again_'
      'after_a_refusal', (WidgetTester tester) async {
    final Random random = seededRandom(1062508);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StoredProject stored = buildStoredProject(
        random,
        _withSample(random),
      );
      final PlannedRefusal refusal = PlannedRefusal();
      refusal.problem = PeopleFacingRefusal('busy ${random.nextInt(99)}');
      await _openDialog(tester, random, (
        project: stored.project,
        repository: RefusingProjectRepository(
          stored: stored.repository,
          refusal: refusal,
        ),
      ));

      await tapDialogButton(tester, _removeLabel);
      await tapDialogButton(tester, 'Close');

      expect(find.byType(RemoveRepositoryDialog), findsOneWidget);
      expect(_removeButton(tester).onPressed, isNotNull);
    }
  });
}
