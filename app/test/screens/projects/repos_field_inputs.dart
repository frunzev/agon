import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_devices.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/presentation/device_names.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects/new_project_repos_field.dart';
import 'package:agent_orchestration/widgets/app_button.dart';

import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'project_form_steps.dart';

const String _removeLabel = 'Remove';
const int _mostDrafts = 5;

final class ReposFieldInputs {
  ReposFieldInputs(Random random)
    : drafts = _randomDrafts(random),
      newFolderPath = random.nextBool()
          ? '$folderRoot/${randomFolderName(random)}'
          : null,
      hasFolderActions = random.nextBool(),
      addressProblem = random.nextBool() ? randomWordPhrase(random) : null;

  final List<RepositoryDraft> drafts;
  final String? newFolderPath;
  final bool hasFolderActions;
  final String? addressProblem;
  final List<String> calls = <String>[];
  final TextEditingController controller = TextEditingController();

  Set<String> get startedAddresses => <String>{
    for (int index = 0; index < drafts.length; index += 2)
      drafts[index].address,
  };

  LocalFolderActions get folderActions => LocalFolderActions(
    onFolderChosen: () => calls.add('choose'),
    onNewFolderStarted: () => calls.add('start'),
    onNewFolderRemoved: () => calls.add('drop'),
  );

  NewProjectReposField buildField() {
    return NewProjectReposField(
      drafts: drafts,
      newFolderPath: newFolderPath,
      gitStartedAddresses: startedAddresses,
      deviceNames: DeviceNames(galleryDevices),
      addressController: controller,
      addressProblem: addressProblem,
      onAddressChanged: (String text) => calls.add('changed $text'),
      onAddressAdded: () => calls.add('added'),
      localFolderActions: hasFolderActions ? folderActions : null,
      onRemoved: (String address) => calls.add('removed $address'),
    );
  }
}

List<RepositoryDraft> _randomDrafts(Random random) {
  final int count = random.nextInt(_mostDrafts);
  return <RepositoryDraft>[
    for (int index = 0; index < count; index += 1)
      RepositoryDraft(
        address: random.nextBool()
            ? '${randomTypedGitHubRepository(random).canonical}$index'
            : describeLocalAddress('$folderRoot/folder-$index'),
        defaultBranch: pickOne(random, <String>['main', 'dev']),
      ),
  ];
}

Future<void> pumpReposFieldInputs(
  WidgetTester tester,
  Random random,
  ReposFieldInputs inputs,
) async {
  addTearDown(inputs.controller.dispose);
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: inputs.buildField(),
  );
  expect(tester.takeException(), isNull);
}

Future<ReposFieldInputs> pumpReposField(
  WidgetTester tester,
  Random random,
) async {
  final ReposFieldInputs inputs = ReposFieldInputs(random);
  await pumpReposFieldInputs(tester, random, inputs);
  return inputs;
}

List<String> listInputAddresses(List<RepositoryDraft> drafts) {
  return <String>[for (final RepositoryDraft draft in drafts) draft.address];
}

List<String> describeExpectedReposRows(ReposFieldInputs inputs) {
  return <String>[
    for (final RepositoryDraft draft in inputs.drafts)
      describeRepositoryPath(draft.address),
    if (inputs.newFolderPath != null && inputs.hasFolderActions)
      inputs.newFolderPath!,
  ];
}

Future<void> tapRemoveOfReposRow(WidgetTester tester, int rowIndex) async {
  final Finder remove = find.widgetWithText(AppButton, _removeLabel);
  await tester.ensureVisible(remove.at(rowIndex));
  await tester.tap(remove.at(rowIndex));
  await tester.pump();
}
