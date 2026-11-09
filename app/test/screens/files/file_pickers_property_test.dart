import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/branch_choice.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';
import 'file_property_inputs.dart';

const Key _repositoryKey = ValueKey<String>('repository');
const Key _branchKey = ValueKey<String>('branch');
const double _pickerHeight = 10;

List<Repository> _randomRepositories(Random random) {
  final int count = 1 + random.nextInt(4);
  return <Repository>[
    for (int index = 0; index < count; index += 1)
      Repository(
        address: 'github.com/acme/${randomHostileText(random) * 3}$index',
        defaultBranch: 'main',
        agentAccess: pickOne(random, AgentAccess.values),
      ),
  ];
}

BranchPicker _randomBranchPicker(Random random) {
  final FilesFromRunner source = FilesFromRunner(
    runnerId: const DeviceId('runner'),
    runnerName: 'runner',
    branches: <String>[
      'main',
      ...randomDistinctBranches(random, 'release ' * 6),
    ],
    taskBranches: randomDistinctBranches(random, 'task/'),
  );
  return BranchPicker(
    entries: buildBranchEntries(source),
    chosenBranch: pickOne(random, <String>[
      ...source.branches,
      ...source.taskBranches,
    ]),
    onChosen: (String branch) {},
  );
}

Widget _buildRealPickers(Random random) {
  final List<Repository> repositories = _randomRepositories(random);
  return FilePickers(
    repository: RepositoryPicker(
      repositories: repositories,
      chosenAddress: pickOne(random, repositories).address,
      onChosen: (String address) {},
    ),
    branch: random.nextBool() ? null : _randomBranchPicker(random),
  );
}

void main() {
  test('test_file_pickers_new_property_keeps_both_pickers', () {
    final Random random = seededRandom(100201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Widget repository = Text(randomHostileText(random));
      final Widget branch = Text(randomHostileText(random));
      final FilePickers pickers = FilePickers(
        repository: repository,
        branch: branch,
      );

      expect(pickers.repository, same(repository));
      expect(pickers.branch, same(branch));
    }
  });

  test('test_file_pickers_new_property_branch_may_be_missing', () {
    final Random random = seededRandom(100202);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Widget repository = Text(randomHostileText(random));

      expect(FilePickers(repository: repository, branch: null).branch, isNull);
    }
  });

  test('test_file_pickers_new_property_keeps_the_key', () {
    final Random random = seededRandom(100203);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<int>(random.nextInt(1 << 20));
      final FilePickers pickers = FilePickers(
        key: key,
        repository: const SizedBox(),
        branch: null,
      );

      expect(pickers.key, key);
    }
  });

  testWidgets('test_file_pickers_build_property_long_names_never_overflow', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 100204,
      buildChild: _buildRealPickers,
    );
  });

  testWidgets('test_file_pickers_build_property_branch_takes_the_rest', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      final List<Repository> repositories = _randomRepositories(random);
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: FilePickers(
          repository: RepositoryPicker(
            repositories: repositories,
            chosenAddress: repositories.first.address,
            onChosen: (String address) {},
          ),
          branch: KeyedSubtree(
            key: _branchKey,
            child: _randomBranchPicker(random),
          ),
        ),
      );

      final Rect branch = tester.getRect(find.byKey(_branchKey));
      final Rect repository = tester.getRect(find.byType(RepositoryPicker));

      expect(branch.right, closeTo(width, 0.01));
      expect(branch.left - repository.right, closeTo(AppSpacing.space3, 0.01));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_columns_property_repository_then_branch', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: FilePickers(
          repository: SizedBox(
            key: _repositoryKey,
            width: random.nextDouble() * width / 2,
            height: _pickerHeight,
          ),
          branch: const SizedBox(key: _branchKey, height: _pickerHeight),
        ),
      );
      final Rect repository = tester.getRect(find.byKey(_repositoryKey));
      final Rect branch = tester.getRect(find.byKey(_branchKey));

      expect(repository.left, closeTo(0, 0.01));
      expect(repository.top, closeTo(branch.top, 0.01));
      expect(branch.left - repository.right, closeTo(AppSpacing.space3, 0.01));
    }
  });

  testWidgets('test_build_columns_property_no_branch_leaves_room_empty', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      final double repositoryWidth = random.nextDouble() * width / 2;
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: FilePickers(
          repository: SizedBox(
            key: _repositoryKey,
            width: repositoryWidth,
            height: _pickerHeight,
          ),
          branch: null,
        ),
      );

      expect(
        tester.getSize(find.byKey(_repositoryKey)).width,
        closeTo(repositoryWidth, 0.01),
      );
      expect(
        tester.getSize(find.byType(FilePickers)).width,
        closeTo(width, 0.01),
      );
    }
  });

  testWidgets('test_build_columns_property_pickers_share_one_row', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final double width = randomWidth(
        random,
        least: narrowestWidth,
        most: widestWidth,
      );
      await pumpScrollableAtWidth(
        tester,
        width: width,
        child: FilePickers(
          repository: SizedBox(
            key: _repositoryKey,
            width: random.nextDouble() * width * 2,
            height: _pickerHeight,
          ),
          branch: const SizedBox(key: _branchKey, height: _pickerHeight),
        ),
      );
      final Rect branch = tester.getRect(find.byKey(_branchKey));

      expect(branch.right, closeTo(width, 0.01));
      expect(
        tester.getRect(find.byKey(_repositoryKey)).right,
        lessThanOrEqualTo(width - AppSpacing.space3 + 0.01),
      );
    }
  });
}
