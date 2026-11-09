import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import 'project_repositories_editor_inputs.dart';
import 'repository_dialog_steps.dart';

const String _typedAddress = 'github.com/acme/new-repo';

final class _RefusingAddProjectRepository implements ProjectRepository {
  _RefusingAddProjectRepository({required this.stored, required this.refusal});

  final ProjectRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Project> listProjects(WorkspaceId workspaceId) {
    return stored.listProjects(workspaceId);
  }

  @override
  Project findProject(ProjectId projectId) => stored.findProject(projectId);

  @override
  Future<Project> createProject(ProjectDraft draft) {
    return stored.createProject(draft);
  }

  @override
  Future<Project> addRepository(ProjectId projectId, Repository repository) {
    return refusal.refuseOr(() => stored.addRepository(projectId, repository));
  }

  @override
  Future<Project> removeRepository(ProjectId projectId, String address) {
    return stored.removeRepository(projectId, address);
  }

  @override
  Future<void> deleteProject(ProjectId projectId) {
    return stored.deleteProject(projectId);
  }
}

List<String> _listAddresses(ProjectRepository repository) {
  return <String>[
    for (final Repository stored
        in repository.findProject(GalleryProjectIds.acmeApp).repositories)
      stored.address,
  ];
}

RefusedActionCase _buildSaveRepositoryCase() {
  late ProjectRepository projectRepository;

  return RefusedActionCase(
    functionName: 'save_repository',
    actionLabel: addRepositoryLabel,
    place: RefusalPlace.dialogOverPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      projectRepository = _RefusingAddProjectRepository(
        stored: gallery.projectRepository,
        refusal: refusal,
      );
      await pumpApp(
        tester,
        size: size,
        route: const ProjectRoute(GalleryProjectIds.acmeApp),
        dependencies: replaceRepositories(
          gallery,
          projectRepository: projectRepository,
        ),
      );
      await tapDialogButton(tester, addRepositoryLabel);
    },
    performAction: (tester) => typeAddressAndAdd(tester, _typedAddress),
    expectSucceeded: (tester) {
      expect(_listAddresses(projectRepository), contains(_typedAddress));
      expect(find.text(addressFieldLabel), findsNothing);
    },
  );
}

Future<AddRepositoryDialogPage> _openNamedDialog(
  WidgetTester tester,
  Random random,
  String projectName,
  PlannedRefusal refusal,
) async {
  final StoredProject stored = buildStoredProject(random, <Repository>[]);
  final Project project = stored.project;
  final Project renamed = Project(
    id: project.id,
    workspaceId: project.workspaceId,
    name: projectName,
    repositories: project.repositories,
    approvalPolicy: project.approvalPolicy,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  return openAddRepositoryDialog(
    tester,
    random: random,
    stored: (
      project: renamed,
      repository: _RefusingAddProjectRepository(
        stored: stored.repository,
        refusal: refusal,
      ),
    ),
    folderPicker: null,
  );
}

void main() {
  registerRefusedActionProperties(_buildSaveRepositoryCase(), seed: 1061501);

  testWidgets('test_add_repository_dialog_describe_title_property_names_'
      'the_project_verbatim', (WidgetTester tester) async {
    final Random random = seededRandom(1061511);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = randomHostileText(random);
      await _openNamedDialog(tester, random, name, PlannedRefusal());

      expect(find.text('Add repo to $name'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_add_repository_dialog_describe_title_property_titles_'
      'the_refusal_too', (WidgetTester tester) async {
    final Random random = seededRandom(1061512);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = 'p${randomHostileText(random)}';
      final PlannedRefusal refusal = PlannedRefusal();
      final String reason = 'refused ${random.nextInt(999)}';
      refusal.problem = PeopleFacingRefusal(reason);
      final AddRepositoryDialogPage page = await _openNamedDialog(
        tester,
        random,
        name,
        refusal,
      );

      await typeAddressAndAdd(tester, randomCanonicalHostedAddress(random));

      expect(find.text('Add repo to $name'), findsNWidgets(2));
      expect(find.text(reason), findsOneWidget);
      expect(page.listStoredAddresses(), isEmpty);
    }
  });

  testWidgets('test_add_repository_dialog_describe_title_property_survives_'
      'rebuilds', (WidgetTester tester) async {
    final Random random = seededRandom(1061513);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String name = 'q${randomHostileText(random)}';
      await _openNamedDialog(tester, random, name, PlannedRefusal());

      await typeAddressAndAdd(tester, 'nowhere ${random.nextInt(99)}');
      await tester.tap(find.text('Read only'));
      await tester.pump();

      expect(find.text('Add repo to $name'), findsOneWidget);
    }
  });

  testWidgets('test_save_repository_property_double_tap_adds_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1061514);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StoredProject stored = buildStoredProject(random, <Repository>[]);
      final HeldChangesProjectRepository held = HeldChangesProjectRepository(
        stored.repository,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final AddRepositoryDialogPage page = await openAddRepositoryDialog(
        tester,
        random: random,
        stored: (project: stored.project, repository: held),
        folderPicker: null,
      );
      final String canonical = randomCanonicalHostedAddress(random);
      await typeAddressAndAdd(tester, canonical);
      await tapDialogButton(tester, addRepositoryLabel);

      held.release.complete();
      await pumpFrames(tester);

      expect(held.addCount, 1);
      expect(find.text('$addRepositoryLabel did not work'), findsNothing);
      expect(page.listStoredAddresses(), <String>[canonical]);
      expect(page.closing.isClosed, isTrue);
    }
  });
}
