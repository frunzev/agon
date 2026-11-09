import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects/project_form.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';
import '../../support/widget_harness.dart';
import 'project_form_steps.dart';

const String saveLabel = 'Save project';
const String leaveLabel = 'Leave';
const String _nameCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789-';
const int _longestName = 40;
const int _mostInitialRepositories = 4;

final class HeldFolderPicker implements FolderPicker {
  final Completer<String?> chosenFolder = Completer<String?>();
  final Completer<String> preparedFolder = Completer<String>();

  @override
  Future<String?> chooseFolder() => chosenFolder.future;

  @override
  Future<String> prepareNewProjectsFolder() => preparedFolder.future;
}

final class FormRecorder {
  final List<DraftedProject> submitted = <DraftedProject>[];
  int leaveCount = 0;
  Object? plannedProblem;
  Completer<void>? heldSubmission;

  Future<void> submit(DraftedProject drafted) async {
    submitted.add(drafted);
    final Completer<void>? hold = heldSubmission;
    if (hold != null) {
      await hold.future;
    }
    final Object? problem = plannedProblem;
    if (problem != null) {
      await Future<void>.error(problem);
    }
  }

  void leave() {
    leaveCount += 1;
  }

  List<FormAction<DraftedProject>> buildActions() {
    return <FormAction<DraftedProject>>[
      LeaveFormAction<DraftedProject>(label: leaveLabel, onPressed: leave),
      SubmitFormAction<DraftedProject>(
        label: saveLabel,
        tone: ButtonTone.primary,
        onSubmitted: submit,
      ),
    ];
  }
}

String randomValidName(Random random) {
  final int length = 1 + random.nextInt(_longestName);
  return randomCharacters(random, _nameCharacters, length);
}

DraftedProject randomInitialProject(Random random) {
  final int count = 1 + random.nextInt(_mostInitialRepositories);
  return DraftedProject(
    name: randomValidName(random),
    repositories: <RepositoryDraft>[
      for (int index = 0; index < count; index += 1)
        RepositoryDraft(
          address: '${randomTypedGitHubRepository(random).canonical}-$index',
          defaultBranch: pickOne(random, <String>['main', 'trunk']),
        ),
    ],
    agentAccess: pickOne(random, AgentAccess.values),
    approvalPolicy: pickOne(random, <ApprovalPolicy?>[
      ...ApprovalPolicy.values,
      null,
    ]),
  );
}

ProjectForm buildProjectForm({
  required DraftedProject initialProject,
  required FolderPicker? folderPicker,
  required FormRecorder recorder,
  required Key? key,
}) {
  return ProjectForm(
    initialProject: initialProject,
    deviceRepository: FakeDeviceRepository(
      devices: galleryDevices,
      currentDeviceId: GalleryDeviceIds.airLaptop,
      peerAddressProblem: null,
      gitlessFolderPaths: const <String>{},
    ),
    folderPicker: folderPicker,
    actions: recorder.buildActions(),
    key: key,
  );
}

Future<double> pumpProjectForm(
  WidgetTester tester,
  Random random,
  ProjectForm form,
) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(tester, width: width, child: form);
  expect(tester.takeException(), isNull, reason: 'width $width');
  return width;
}

bool isSaveEnabled(WidgetTester tester) {
  final AppButton save = tester.widget<AppButton>(
    find.widgetWithText(AppButton, saveLabel),
  );
  return save.onPressed != null;
}

List<String> listDraftAddresses(List<RepositoryDraft> drafts) {
  return <String>[for (final RepositoryDraft draft in drafts) draft.address];
}

ProjectForm buildRandomProjectForm(Random random, FormRecorder recorder) {
  return buildProjectForm(
    initialProject: randomInitialProject(random),
    folderPicker: null,
    recorder: recorder,
    key: null,
  );
}

List<String> describeExpectedRowTitles(DraftedProject project) {
  return <String>[
    for (final RepositoryDraft draft in project.repositories)
      describeRepositoryPath(draft.address),
  ];
}

Future<FormRecorder> pumpRandomProjectForm(
  WidgetTester tester,
  Random random,
  DraftedProject initial,
) async {
  final FormRecorder recorder = FormRecorder();
  await pumpProjectForm(
    tester,
    random,
    buildProjectForm(
      initialProject: initial,
      folderPicker: null,
      recorder: recorder,
      key: null,
    ),
  );
  return recorder;
}

Future<void> saveProjectForm(WidgetTester tester) async {
  await tapVisible(tester, find.text(saveLabel));
  await tester.pump();
  await tester.pump();
}
