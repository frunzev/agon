import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/files/branch_choice.dart';
import 'package:agent_orchestration/screens/files/file_pickers.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

final class _ChoiceRecorder {
  final List<String> choices = <String>[];

  void record(String choice) {
    choices.add(choice);
  }
}

List<Repository> _randomRepositories(Random random) {
  final int count = 2 + random.nextInt(3);
  return <Repository>[
    for (int index = 0; index < count; index += 1)
      Repository(
        address: 'github.com/acme/repo$index',
        defaultBranch: 'main',
        agentAccess: pickOne(random, AgentAccess.values),
      ),
  ];
}

FilesFromRunner _randomSource(Random random) {
  final int taskCount = 1 + random.nextInt(3);
  return FilesFromRunner(
    runnerId: const DeviceId('runner'),
    runnerName: 'runner',
    branches: <String>['main', 'release'],
    taskBranches: <String>[
      for (int index = 0; index < taskCount; index += 1) 'task/t$index',
    ],
  );
}

Future<void> _pump(WidgetTester tester, Random random, Widget child) async {
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: child,
  );
}

RepositoryPicker _buildHostileRepositoryPicker(Random random) {
  final String address = 'github.com/${randomHostileText(random)}';
  return RepositoryPicker(
    repositories: <Repository>[
      Repository(
        address: address,
        defaultBranch: 'main',
        agentAccess: pickOne(random, AgentAccess.values),
      ),
    ],
    chosenAddress: address,
    onChosen: (String chosen) {},
  );
}

String _describeOption(Repository repository) {
  final String label = describeRepositoryPath(repository.address);
  return '${repository.address} $label';
}

Future<void> _chooseOption(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  test('test_repository_picker_new_property_keeps_every_field', () {
    final Random random = seededRandom(100301);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<Repository> repositories = _randomRepositories(random);
      final String chosen = pickOne(random, repositories).address;
      final _ChoiceRecorder recorder = _ChoiceRecorder();
      final RepositoryPicker picker = RepositoryPicker(
        repositories: repositories,
        chosenAddress: chosen,
        onChosen: recorder.record,
      );

      expect(picker.repositories, same(repositories));
      expect(picker.chosenAddress, chosen);
      expect(picker.onChosen, recorder.record);
    }
  });

  testWidgets('test_repository_picker_build_property_one_option_each', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Repository> repositories = _randomRepositories(random);
      final Repository chosen = pickOne(random, repositories);
      await _pump(
        tester,
        random,
        RepositoryPicker(
          repositories: repositories,
          chosenAddress: chosen.address,
          onChosen: (String address) {},
        ),
      );
      final SelectField<String> field = tester.widget<SelectField<String>>(
        find.byType(SelectField<String>),
      );
      final FormFieldBlock block = tester.widget<FormFieldBlock>(
        find.byType(FormFieldBlock),
      );

      expect(block.label, repositoryPickerLabel);
      expect(field.value, chosen.address);
      expect(
        <String>[
          for (final SelectEntry<String> entry in field.entries)
            if (entry is SelectOption<String>) '${entry.value} ${entry.label}',
        ],
        <String>[
          for (final Repository repository in repositories)
            _describeOption(repository),
        ],
      );
    }
  });

  testWidgets('test_repository_picker_build_property_choice_reports_address', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Repository> repositories = _randomRepositories(random);
      final Repository picked = pickOne(random, repositories);
      final _ChoiceRecorder recorder = _ChoiceRecorder();
      await _pump(
        tester,
        random,
        RepositoryPicker(
          repositories: repositories,
          chosenAddress: repositories.first.address,
          onChosen: recorder.record,
        ),
      );
      await _chooseOption(tester, describeRepositoryPath(picked.address));

      expect(recorder.choices, <String>[picked.address]);
    }
  });

  test('test_branch_picker_new_property_keeps_every_field', () {
    final Random random = seededRandom(100304);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<SelectEntry<String>> entries = buildBranchEntries(
        _randomSource(random),
      );
      final String chosen = randomHostileText(random);
      final _ChoiceRecorder recorder = _ChoiceRecorder();
      final BranchPicker picker = BranchPicker(
        entries: entries,
        chosenBranch: chosen,
        onChosen: recorder.record,
      );

      expect(picker.entries, same(entries));
      expect(picker.chosenBranch, chosen);
      expect(picker.onChosen, recorder.record);
    }
  });

  testWidgets('test_branch_picker_build_property_passes_entries_through', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100305);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesFromRunner source = _randomSource(random);
      final List<SelectEntry<String>> entries = buildBranchEntries(source);
      final String chosen = pickOne(random, <String>[
        ...source.branches,
        ...source.taskBranches,
      ]);
      await _pump(
        tester,
        random,
        BranchPicker(
          entries: entries,
          chosenBranch: chosen,
          onChosen: (String branch) {},
        ),
      );
      final SelectField<String> field = tester.widget<SelectField<String>>(
        find.byType(SelectField<String>),
      );

      expect(field.entries, same(entries));
      expect(field.value, chosen);
      expect(find.text(branchPickerLabel), findsOneWidget);
    }
  });

  testWidgets('test_branch_picker_build_property_choice_reports_branch', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100306);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FilesFromRunner source = _randomSource(random);
      final String picked = pickOne(random, source.taskBranches);
      final _ChoiceRecorder recorder = _ChoiceRecorder();
      await _pump(
        tester,
        random,
        BranchPicker(
          entries: buildBranchEntries(source),
          chosenBranch: 'main',
          onChosen: recorder.record,
        ),
      );
      await _chooseOption(tester, picked);

      expect(recorder.choices, <String>[picked]);
    }
  });

  testWidgets('test_branch_picker_build_property_headings_cannot_be_chosen', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(100307);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _ChoiceRecorder recorder = _ChoiceRecorder();
      await _pump(
        tester,
        random,
        BranchPicker(
          entries: buildBranchEntries(_randomSource(random)),
          chosenBranch: 'main',
          onChosen: recorder.record,
        ),
      );
      await _chooseOption(
        tester,
        pickOne(random, <String>['Branches', 'Task branches']),
      );

      expect(recorder.choices, isEmpty);
      await tester.tapAt(Offset.zero);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('test_repository_picker_build_property_hostile_names_render', (
    WidgetTester tester,
  ) async {
    await expectRendersAtRandomWidths(
      tester,
      seed: 100308,
      buildChild: _buildHostileRepositoryPicker,
    );
  });
}
