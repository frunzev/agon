import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';
import 'project_screen_inputs.dart';

typedef _OpenDialog = ({Project project, ProjectRepository repository});

Future<_OpenDialog> _openAddDialog(
  WidgetTester tester,
  Random random, {
  required String? refusalMessage,
}) async {
  final Project galleryProject = pickOne(random, galleryProjects);
  final List<Repository> repositories = randomScreenRepositories(random);
  final AppDependencies base = buildDependenciesWithRepositories(
    projectId: galleryProject.id,
    repositories: repositories,
  );
  final ProjectRepository repository = refusalMessage == null
      ? base.projectRepository
      : RefusingRepositoryChanges(
          stored: base.projectRepository,
          message: refusalMessage,
        );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: randomProjectPageSize(random),
    route: ProjectRoute(galleryProject.id),
    dependencies: replaceRepositories(base, projectRepository: repository),
  );
  await _tapButton(tester, 'Add repo');
  return (project: galleryProject, repository: repository);
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await pumpFrames(tester);
}

Future<void> _addTyped(WidgetTester tester, String address) async {
  await enterFieldText(tester, label: 'Address', text: address);
  await _tapButton(tester, 'Add repo');
}

void main() {
  testWidgets('test_save_repository_property_refusal_keeps_the_dialog', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1052001);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _OpenDialog dialog = await _openAddDialog(
        tester,
        random,
        refusalMessage: 'refused $i',
      );
      final String address = randomCanonicalHostedAddress(random);
      await _addTyped(tester, address);

      await _tapButton(tester, 'Close');

      expect(find.text('Add repo to ${dialog.project.name}'), findsOneWidget);
      expect(find.textContaining('refused $i'), findsNothing);
      expect(findFieldText('Address', address), findsOneWidget);
    }
  });

  testWidgets('test_save_repository_property_refusal_names_the_project', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1052002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _OpenDialog dialog = await _openAddDialog(
        tester,
        random,
        refusalMessage: 'no $i',
      );

      await _addTyped(tester, randomCanonicalHostedAddress(random));

      expect(
        find.text('Add repo to ${dialog.project.name}'),
        findsNWidgets(2),
      );
      expect(find.textContaining('no $i'), findsOneWidget);
    }
  });

  testWidgets('test_save_repository_property_success_closes_and_adds', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1052003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _OpenDialog dialog = await _openAddDialog(
        tester,
        random,
        refusalMessage: null,
      );
      final bool isReadOnly = random.nextBool();
      if (isReadOnly) {
        await tapVisible(tester, find.text('Read only').last);
        await tester.pump();
      }
      final String address = '${randomCanonicalHostedAddress(random)}-new';

      await _addTyped(tester, address);

      final Repository added = dialog.repository
          .findProject(dialog.project.id)
          .repositories
          .last;
      expect(find.text('Add repo to ${dialog.project.name}'), findsNothing);
      expect(added.address, address);
      expect(
        added.agentAccess,
        isReadOnly ? AgentAccess.readOnly : AgentAccess.pushAfterApproval,
      );
    }
  });
}
