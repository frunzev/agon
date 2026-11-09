import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';
import 'project_screen_inputs.dart';

typedef _RefusingPage = ({Project project, ProjectRepository repository});

Future<_RefusingPage> _pumpRefusingPage(
  WidgetTester tester,
  Random random,
  String message,
) async {
  final Project galleryProject = pickOne(random, galleryProjects);
  final List<Repository> repositories = randomScreenRepositories(random);
  final AppDependencies base = buildDependenciesWithRepositories(
    projectId: galleryProject.id,
    repositories: repositories,
  );
  final ProjectRepository refusing = RefusingRepositoryChanges(
    stored: base.projectRepository,
    message: message,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpApp(
    tester,
    size: randomProjectPageSize(random),
    route: ProjectRoute(galleryProject.id),
    dependencies: replaceRepositories(base, projectRepository: refusing),
  );
  return (
    project: galleryProject.withRepositories(repositories),
    repository: refusing,
  );
}

Future<void> _tapButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label).last;
  await tester.ensureVisible(button);
  await tester.tap(button);
  await pumpFrames(tester);
}

List<String> _listStoredAddresses(_RefusingPage page) {
  return <String>[
    for (final Repository repository
        in page.repository.findProject(page.project.id).repositories)
      repository.address,
  ];
}

Future<void> _typeAddressAndAdd(WidgetTester tester, String text) async {
  await _tapButton(tester, 'Add repo');
  await enterFieldText(tester, label: 'Address', text: text);
  await _tapButton(tester, 'Add repo');
}

void main() {
  testWidgets('test_build_page_property_add_repo_refusal_is_shown', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String message = 'refused add $i';
      final _RefusingPage page = await _pumpRefusingPage(
        tester,
        random,
        message,
      );
      final List<String> before = _listStoredAddresses(page);

      await _typeAddressAndAdd(tester, randomCanonicalHostedAddress(random));

      expect(tester.takeException(), isNull);
      expect(find.textContaining(message), findsOneWidget);
      expect(_listStoredAddresses(page), before);
    }
  });

  testWidgets('test_build_page_property_add_repo_refuses_listed_repos', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RefusingPage page = await _pumpRefusingPage(
        tester,
        random,
        'never asked',
      );
      final List<String> hosted = <String>[
        for (final String address in _listStoredAddresses(page))
          if (!address.startsWith('local:')) address,
      ];
      if (hosted.isEmpty) {
        continue;
      }

      await _typeAddressAndAdd(
        tester,
        randomSpellingOf(random, pickOne(random, hosted)).trim(),
      );

      expect(find.text(repositoryAlreadyAddedProblem), findsOneWidget);
      expect(find.textContaining('never asked'), findsNothing);
    }
  });

  testWidgets('test_build_repository_row_property_remove_refusal_keeps_'
      'the_repo', (WidgetTester tester) async {
    final Random random = seededRandom(1051203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String message = 'refused removal $i';
      final _RefusingPage page = await _pumpRefusingPage(
        tester,
        random,
        message,
      );
      final List<String> before = _listStoredAddresses(page);
      if (before.isEmpty) {
        continue;
      }

      await _tapButton(tester, 'Remove');
      await _tapButton(tester, 'Remove repo');

      expect(tester.takeException(), isNull);
      expect(find.textContaining(message), findsOneWidget);
      expect(_listStoredAddresses(page), before);
    }
  });
}
