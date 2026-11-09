import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/branch_choice.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../support/random_inputs.dart';
import '../../support/random_repository_addresses.dart';
import '../../support/widget_harness.dart';

const Key _repositoryKey = ValueKey<String>('repository');
const Key _branchKey = ValueKey<String>('branch');
const double _narrowestPickerRow = 240;
const double _widestPickerRow = 900;
const double _pickerHeight = 10;
const double _tolerance = 0.01;

List<Repository> _randomRealisticRepositories(Random random) {
  return <Repository>[
    for (int index = 0; index < 1 + random.nextInt(4); index += 1)
      Repository(
        address:
            'github.com/acme/${randomPathPartWithoutGitSuffix(random)}-$index',
        defaultBranch: 'main',
        agentAccess: AgentAccess.readOnly,
      ),
  ];
}

Widget _buildRealisticPickers(Random random) {
  final List<Repository> repositories = _randomRealisticRepositories(random);
  final FilesFromRunner source = FilesFromRunner(
    runnerId: const DeviceId('runner'),
    runnerName: 'runner',
    branches: <String>['main', 'release/${randomRepositoryName(random)}'],
    taskBranches: <String>['task/${randomRepositoryName(random)}'],
  );
  return FilePickers(
    repository: RepositoryPicker(
      repositories: repositories,
      chosenAddress: pickOne(random, repositories).address,
      onChosen: (String address) {},
    ),
    branch: KeyedSubtree(
      key: _branchKey,
      child: BranchPicker(
        entries: buildBranchEntries(source),
        chosenBranch: 'main',
        onChosen: (String branch) {},
      ),
    ),
  );
}

double _randomRowWidth(Random random) {
  return randomWidth(
    random,
    least: _narrowestPickerRow,
    most: _widestPickerRow,
  );
}

void main() {
  testWidgets('test_file_pickers_build_property_realistic_names_never_'
      'overflow', (WidgetTester tester) async {
    final Random random = seededRandom(1051301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomRowWidth(random);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: _buildRealisticPickers(random),
      );

      expect(tester.takeException(), isNull, reason: 'width $width');
    }
  });

  testWidgets('test_build_columns_property_branch_keeps_half_the_row', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1051302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomRowWidth(random);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: _buildRealisticPickers(random),
      );
      final Rect branch = tester.getRect(find.byKey(_branchKey));
      final Rect repository = tester.getRect(find.byType(RepositoryPicker));

      expect(
        branch.width,
        greaterThanOrEqualTo((width - AppSpacing.space3) / 2 - _tolerance),
      );
      expect(repository.right, lessThanOrEqualTo(branch.left + _tolerance));
    }
  });

  testWidgets('test_build_columns_property_short_repository_keeps_its_'
      'width', (WidgetTester tester) async {
    final Random random = seededRandom(1051303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = _randomRowWidth(random);
      final double repositoryWidth =
          random.nextDouble() * (width - AppSpacing.space3) / 2;
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: FilePickers(
          repository: SizedBox(
            key: _repositoryKey,
            width: repositoryWidth,
            height: _pickerHeight,
          ),
          branch: const SizedBox(key: _branchKey, height: _pickerHeight),
        ),
      );

      expect(
        tester.getSize(find.byKey(_repositoryKey)).width,
        closeTo(repositoryWidth, _tolerance),
      );
      expect(
        tester.getRect(find.byKey(_branchKey)).left,
        closeTo(repositoryWidth + AppSpacing.space3, _tolerance),
      );
    }
  });
}
