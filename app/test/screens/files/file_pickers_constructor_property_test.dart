import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/files/branch_choice.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'file_property_inputs.dart';

void _ignoreChoice(String choice) {}

void main() {
  test('test_repository_picker_new_property_keeps_the_key', () {
    final Random random = seededRandom(100401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));
      final RepositoryPicker picker = RepositoryPicker(
        key: key,
        repositories: const <Repository>[],
        chosenAddress: '',
        onChosen: _ignoreChoice,
      );

      expect(picker.key, key);
    }
  });

  test('test_repository_picker_new_property_keeps_hostile_addresses', () {
    final Random random = seededRandom(100402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String address = randomHostileText(random);
      final RepositoryPicker picker = RepositoryPicker(
        repositories: <Repository>[
          Repository(
            address: address,
            defaultBranch: randomHostileText(random),
            agentAccess: pickOne(random, AgentAccess.values),
          ),
        ],
        chosenAddress: address,
        onChosen: _ignoreChoice,
      );

      expect(picker.chosenAddress, address);
      expect(picker.repositories.single.address, address);
    }
  });

  test('test_branch_picker_new_property_keeps_the_key', () {
    final Random random = seededRandom(100403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final Key key = ValueKey<String>(randomHostileText(random));
      final BranchPicker picker = BranchPicker(
        key: key,
        entries: const <SelectEntry<String>>[],
        chosenBranch: '',
        onChosen: _ignoreChoice,
      );

      expect(picker.key, key);
    }
  });

  test('test_branch_picker_new_property_keeps_entries_in_order', () {
    final Random random = seededRandom(100404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SelectEntry<String>> entries = buildBranchEntries(
        randomFilesFromRunner(random),
      );
      final BranchPicker picker = BranchPicker(
        entries: entries,
        chosenBranch: randomHostileText(random),
        onChosen: _ignoreChoice,
      );

      for (int index = 0; index < entries.length; index += 1) {
        expect(picker.entries[index], same(entries[index]));
      }
    }
  });
}
