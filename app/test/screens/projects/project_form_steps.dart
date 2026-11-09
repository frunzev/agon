import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/fake_task_work_links.dart';
import '../../support/fixed_folder_picker.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';
import '../../support/widget_harness.dart';

const String createProjectLabel = 'Create project';
const String addRepoLabel = 'Add repo';
const String reposLabel = 'Repos';
const String nameLabel = 'Name';
const String folderRoot = '/work';
const SectionRoute projectsRoute = SectionRoute(AppSection.projects);
const List<TargetPlatform> computerPlatforms = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.linux,
  TargetPlatform.windows,
];
const List<TargetPlatform> phonePlatforms = <TargetPlatform>[
  TargetPlatform.android,
  TargetPlatform.iOS,
];
const List<String> _owners = <String>['acme', 'Octo-Org', 'a_b'];
const List<String> _folderWords = <String>[
  'billing',
  'Site 2',
  'api_v2',
  'Ünïcødé app',
  'docs',
];

typedef TypedRepository = ({String typed, String canonical});

typedef NewProjectPage = ({
  AppDependencies dependencies,
  FixedFolderPicker picker,
  AppNavigation navigation,
});

final class HeldProjectRepository implements ProjectRepository {
  HeldProjectRepository(this.stored);

  final ProjectRepository stored;
  Completer<void>? heldCreation;
  int creationCount = 0;

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
  Future<Project> createProject(ProjectDraft draft) async {
    creationCount += 1;
    final Completer<void>? hold = heldCreation;
    if (hold != null) {
      await hold.future;
    }
    return stored.createProject(draft);
  }

  @override
  Future<Project> addRepository(ProjectId projectId, Repository repository) {
    return stored.addRepository(projectId, repository);
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

TypedRepository randomTypedGitHubRepository(Random random) {
  final String owner = pickOne(random, _owners);
  final String name = randomPathPartWithoutGitSuffix(random);
  final String canonical = 'github.com/$owner/$name';
  final String typed = switch (random.nextInt(5)) {
    0 => canonical,
    1 => 'https://$canonical',
    2 => 'https://GitHub.com/$owner/$name.git',
    3 => 'git@github.com:$owner/$name.git',
    _ => ' \u3000$canonical/\u2003',
  };
  return (typed: typed, canonical: canonical);
}

String randomFolderName(Random random) {
  return '${pickOne(random, _folderWords)}-${random.nextInt(100)}';
}

String describeLocalAddress(String path) {
  return 'local:${GalleryDeviceIds.airLaptop.value}:$path';
}

Size randomProjectWindow(Random random) {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  return Size(width, pickOne(random, <double>[phoneHeight, desktopHeight]));
}

Future<NewProjectPage> openNewProjectPage(
  WidgetTester tester, {
  required Size size,
  required TargetPlatform platform,
  required ProjectRepository? projectRepository,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  final FixedFolderPicker picker = FixedFolderPicker(null);
  final AppDependencies gallery = buildGalleryDependencies();
  final AppDependencies dependencies = replaceRepositories(
    gallery,
    projectRepository:
        projectRepository ??
        buildProjectRepositoryOver(gallery, const <Project>[]),
    deviceRepository: FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      peerAddressProblem: null,
      gitlessFolderPaths: const <String>{},
    ),
    folderPicker: picker,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  final AppNavigation navigation = await pumpApp(
    tester,
    size: size,
    route: projectsRoute,
    dependencies: dependencies,
  );
  navigation.openRoute(const NewProjectRoute());
  await pumpFrames(tester);
  return (dependencies: dependencies, picker: picker, navigation: navigation);
}

bool canPickFolders() => canChooseFolders(defaultTargetPlatform);

Future<void> tapShownText(WidgetTester tester, String text) async {
  await tapVisible(tester, find.text(text).last);
  await pumpFrames(tester);
}

Future<void> enterSettledText(
  WidgetTester tester, {
  required String label,
  required String text,
}) async {
  await enterFieldText(tester, label: label, text: text);
  await pumpFrames(tester);
}

Future<void> tapBackLink(WidgetTester tester, String label) async {
  final Finder backLink = find.descendant(
    of: find.byType(BackLinkButton),
    matching: find.text(label),
  );
  await tester.ensureVisible(backLink);
  await pumpFrames(tester);
  await tester.tap(backLink);
  await pumpFrames(tester);
}

Future<void> addTypedRepository(WidgetTester tester, String text) async {
  await enterSettledText(tester, label: reposLabel, text: text);
  await tapShownText(tester, addRepoLabel);
}

Future<void> chooseFolderPath(
  WidgetTester tester,
  FixedFolderPicker picker,
  String path,
) async {
  picker.chosenPath = path;
  await tapShownText(tester, chooseFolderLabel);
}

Future<void> createWithName(WidgetTester tester, String name) async {
  await enterSettledText(tester, label: nameLabel, text: name);
  await tapShownText(tester, createProjectLabel);
}

List<String> readRepositoryRowTitles(WidgetTester tester) {
  final Finder rows = find.descendant(
    of: find.byWidgetPredicate(
      (Widget widget) =>
          widget is FormFieldBlock && widget.label == reposLabel,
    ),
    matching: find.byType(ListRowMain),
  );
  return <String>[
    for (final ListRowMain row in tester.widgetList<ListRowMain>(rows))
      row.title,
  ];
}

List<Project> listCreatedProjects(NewProjectPage page) {
  final AppDependencies dependencies = page.dependencies;
  return dependencies.projectRepository.listProjects(
    dependencies.workspaceRepository.currentWorkspace().id,
  );
}
