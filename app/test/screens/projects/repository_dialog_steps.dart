import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/gallery/gallery_workspaces.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/app_harness.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/form_finders.dart';
import '../../support/list_harness.dart';
import '../../support/random_inputs.dart';
import '../support/random_page_windows.dart';
import 'project_repositories_editor_inputs.dart';
import 'project_screen_inputs.dart';

const String addRepositoryLabel = 'Add repo';
const String addressFieldLabel = 'Address';
const String cancelLabel = 'Cancel';
const String alreadyAddedProblem = 'This repo is already added';

typedef StoredProject = ({Project project, ProjectRepository repository});

final class DialogClosing {
  bool isClosed = false;

  void recordClosed(Object? _) {
    isClosed = true;
  }
}

final class HeldChangesProjectRepository implements ProjectRepository {
  HeldChangesProjectRepository(this.stored);

  final ProjectRepository stored;
  final Completer<void> release = Completer<void>();
  int addCount = 0;
  int removalCount = 0;

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
  Future<Project> addRepository(
    ProjectId projectId,
    Repository repository,
  ) async {
    addCount += 1;
    await release.future;
    return stored.addRepository(projectId, repository);
  }

  @override
  Future<Project> removeRepository(ProjectId projectId, String address) async {
    removalCount += 1;
    await release.future;
    return stored.removeRepository(projectId, address);
  }

  @override
  Future<void> deleteProject(ProjectId projectId) {
    return stored.deleteProject(projectId);
  }
}

final class AddRepositoryDialogPage {
  AddRepositoryDialogPage({
    required this.stored,
    required this.devices,
    required this.closing,
  });

  final StoredProject stored;
  final ScriptedFolderDevices devices;
  final DialogClosing closing;

  List<Repository> listStoredRepositories() {
    return stored.repository.findProject(stored.project.id).repositories;
  }

  List<String> listStoredAddresses() {
    return <String>[
      for (final Repository repository in listStoredRepositories())
        repository.address,
    ];
  }
}

StoredProject buildStoredProject(
  Random random,
  List<Repository> repositories,
) {
  final Project galleryProject = pickOne(random, galleryProjects);
  final ProjectRepository repository = buildDependenciesWithRepositories(
    projectId: galleryProject.id,
    repositories: repositories,
  ).projectRepository;
  return (
    project: repository.findProject(galleryProject.id),
    repository: repository,
  );
}

Future<BuildContext> pumpDialogHost(WidgetTester tester, Random random) async {
  final GlobalKey hostKey = GlobalKey();
  await pumpPageInRandomWindow(
    tester,
    random: random,
    page: SizedBox.expand(key: hostKey),
  );
  return hostKey.currentContext!;
}

Future<AddRepositoryDialogPage> openAddRepositoryDialog(
  WidgetTester tester, {
  required Random random,
  required StoredProject stored,
  required FolderPicker? folderPicker,
}) async {
  final AddRepositoryDialogPage page = AddRepositoryDialogPage(
    stored: stored,
    devices: ScriptedFolderDevices(gitlessPaths: <String>{}),
    closing: DialogClosing(),
  );
  final BuildContext hostContext = await pumpDialogHost(tester, random);
  final Future<void> shown = showAddRepositoryDialog(
    context: hostContext,
    project: stored.project,
    projectRepository: stored.repository,
    deviceRepository: page.devices,
    folderPicker: folderPicker,
  );
  unawaited(shown.then(page.closing.recordClosed));
  await pumpFrames(tester);
  return page;
}

Future<void> tapDialogButton(WidgetTester tester, String label) async {
  final Finder button = find.widgetWithText(AppButton, label).last;
  await tester.ensureVisible(button);
  await pumpFrames(tester);
  await tester.tap(button);
  await pumpFrames(tester);
}

Future<void> typeAddressAndAdd(WidgetTester tester, String text) async {
  await enterFieldText(tester, label: addressFieldLabel, text: text);
  await tapDialogButton(tester, addRepositoryLabel);
}

FolderPicker? randomFolderPicker(Random random) {
  return random.nextBool() ? FixedFolderPicker(null) : null;
}

Future<AddRepositoryDialogPage> openRandomAddRepositoryDialog(
  WidgetTester tester,
  Random random,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  return openAddRepositoryDialog(
    tester,
    random: random,
    stored: buildStoredProject(random, randomScreenRepositories(random)),
    folderPicker: randomFolderPicker(random),
  );
}
