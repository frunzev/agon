import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/screens/files/branch_choice.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';

const String _branchesHeading = 'Branches';
const String _taskBranchesHeading = 'Task branches';

List<String> _listBranches(FilesFromRunner source) {
  return <String>[...source.branches, ...source.taskBranches];
}

String? _randomRequest(Random random, List<String> listed) {
  return pickOne(random, <String?>[
    null,
    randomHostileText(random),
    if (listed.isNotEmpty) pickOne(random, listed),
  ]);
}

List<String> _describeShape(List<SelectEntry<String>> entries) {
  return <String>[
    for (final SelectEntry<String> entry in entries)
      switch (entry) {
        SelectGroupHeading<String>(:final String label) => 'heading $label',
        SelectOption<String>(:final String value) => 'option $value',
      },
  ];
}

void main() {
  test('test_choose_initial_branch_property_always_picks_a_listed_one', () {
    final Random random = seededRandom(99301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesFromRunner source = randomFilesFromRunner(random);
      final List<String> listed = _listBranches(source);
      final String? chosen = chooseInitialBranch(
        source: source,
        requestedBranch: _randomRequest(random, listed),
        defaultBranch: randomHostileText(random),
      );

      if (listed.isEmpty) {
        expect(chosen, isNull);
      } else {
        expect(listed, contains(chosen));
      }
    }
  });

  test('test_choose_initial_branch_property_listed_request_always_wins', () {
    final Random random = seededRandom(99302);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesFromRunner source = randomFilesFromRunner(random);
      final List<String> listed = _listBranches(source);
      if (listed.isEmpty) {
        continue;
      }
      final String requested = pickOne(random, listed);
      final String defaultBranch = pickOne(random, listed);

      expect(
        chooseInitialBranch(
          source: source,
          requestedBranch: requested,
          defaultBranch: defaultBranch,
        ),
        requested,
      );
    }
  });

  test('test_choose_initial_branch_property_unlisted_request_is_ignored', () {
    final Random random = seededRandom(99303);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesFromRunner source = randomFilesFromRunner(random);
      final List<String> listed = _listBranches(source);
      final String unlisted = 'gone/${randomHostileText(random)}';
      final String defaultBranch = pickOne(random, <String>[
        'main',
        ...listed,
      ]);

      expect(
        chooseInitialBranch(
          source: source,
          requestedBranch: unlisted,
          defaultBranch: defaultBranch,
        ),
        chooseInitialBranch(
          source: source,
          requestedBranch: null,
          defaultBranch: defaultBranch,
        ),
      );
    }
  });

  test('test_build_branch_entries_property_options_are_enabled_names', () {
    final Random random = seededRandom(99304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesFromRunner source = randomFilesFromRunner(random);

      for (final SelectEntry<String> entry in buildBranchEntries(source)) {
        if (entry is SelectOption<String>) {
          expect(entry.label, entry.value);
          expect(entry.isEnabled, isTrue);
        }
      }
    }
  });

  test('test_build_branch_entries_property_offers_the_initial_branch', () {
    final Random random = seededRandom(99305);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesFromRunner source = randomFilesFromRunner(random);
      final String? chosen = chooseInitialBranch(
        source: source,
        requestedBranch: _randomRequest(random, _listBranches(source)),
        defaultBranch: 'main',
      );
      if (chosen == null) {
        continue;
      }
      final Iterable<SelectOption<String>> matching =
          buildBranchEntries(source)
              .whereType<SelectOption<String>>()
              .where((SelectOption<String> option) => option.value == chosen);

      expect(matching, hasLength(1));
    }
  });

  test('test_build_group_property_heading_then_its_branches_in_order', () {
    final Random random = seededRandom(99306);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FilesFromRunner source = randomFilesFromRunner(random);

      expect(_describeShape(buildBranchEntries(source)), <String>[
        if (source.branches.isNotEmpty) 'heading $_branchesHeading',
        for (final String branch in source.branches) 'option $branch',
        if (source.taskBranches.isNotEmpty) 'heading $_taskBranchesHeading',
        for (final String branch in source.taskBranches) 'option $branch',
      ]);
    }
  });

  test('test_build_group_property_empty_groups_have_no_heading', () {
    final Random random = seededRandom(99307);

    for (int i = 0; i < propertyIterations; i += 1) {
      final bool hasBranches = random.nextBool();
      final FilesFromRunner source = FilesFromRunner(
        runnerId: const DeviceId('runner'),
        runnerName: randomHostileText(random),
        branches: hasBranches ? <String>['main'] : const <String>[],
        taskBranches: hasBranches ? const <String>[] : <String>['task/a'],
      );
      final List<SelectEntry<String>> entries = buildBranchEntries(source);

      expect(entries, hasLength(2));
      expect(entries.first, isA<SelectGroupHeading<String>>());
      expect(entries.last, isA<SelectOption<String>>());
    }
  });

  test('test_build_group_property_keeps_hostile_names_verbatim', () {
    final Random random = seededRandom(99308);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String branch = randomHostileText(random);
      final FilesFromRunner source = FilesFromRunner(
        runnerId: const DeviceId('runner'),
        runnerName: 'runner',
        branches: <String>[branch],
        taskBranches: const <String>[],
      );

      expect(
        _describeShape(buildBranchEntries(source)).last,
        'option $branch',
      );
    }
  });
}
