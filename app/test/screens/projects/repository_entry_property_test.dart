import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/rules/local_folder_address.dart';
import 'package:agent_orchestration/data/rules/repository_address.dart';
import 'package:agent_orchestration/screens/projects/agent_access_choices.dart';
import 'package:agent_orchestration/screens/projects/project_text.dart';
import 'package:agent_orchestration/screens/projects/repository_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../support/planned_refusal.dart';
import 'project_repositories_editor_inputs.dart';

final class _FolderChecks {
  _FolderChecks(this.answer);

  final Future<CheckedFolder> Function(String path) answer;
  final List<String> checkedPaths = <String>[];

  Future<CheckedFolder> check(String path) {
    checkedPaths.add(path);
    return answer(path);
  }
}

CheckedFolder _randomCheckedFolder(Random random, int round) {
  return CheckedFolder(
    repository: RepositoryDraft(
      address: renderEditorFolderAddress(randomFolderPath(random, round)),
      defaultBranch: pickOne(random, <String>['main', 'trunk']),
    ),
    hasStartedGit: random.nextBool(),
  );
}

List<String> _randomAddedAddresses(Random random) {
  return <String>[
    for (int index = 0; index < random.nextInt(3); index += 1)
      randomCanonicalHostedAddress(random),
  ];
}

String _randomTypedText(Random random) {
  final List<String> choices = <String>[
    randomSpellingOf(random, randomCanonicalHostedAddress(random)),
    randomHostileText(random),
    randomFolderPath(random, random.nextInt(9)),
    '  ',
  ];
  return pickOne(random, choices);
}

void _expectSameEntry(RepositoryEntry actual, RepositoryEntry expected) {
  switch (expected) {
    case RefusedRepository(:final String problem):
      expect(actual, isA<RefusedRepository>());
      expect((actual as RefusedRepository).problem, problem);
    case AcceptedRepository(:final RepositoryDraft repository):
      expect(actual, isA<AcceptedRepository>());
      final AcceptedRepository accepted = actual as AcceptedRepository;
      expect(accepted.repository.address, repository.address);
      expect(accepted.repository.defaultBranch, repository.defaultBranch);
      expect(accepted.hasStartedGit, expected.hasStartedGit);
  }
}

void main() {
  test(
    'test_read_typed_repository_property_hosted_text_follows_rules',
    () async {
      final Random random = seededRandom(54001);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String text = _randomTypedText(random);
        final List<String> added = _randomAddedAddresses(random);
        if (random.nextBool()) {
          final String? address = parseRepositoryAddress(text);
          if (address != null) {
            added.add(address);
          }
        }

        final RepositoryEntry entry = await readTypedRepository(
          text: text,
          checkFolder: null,
          listAddedAddresses: () => added,
        );

        final String? problem = describeRepositoryEntryProblem(
          text: text,
          addedAddresses: added,
        );
        if (problem == null) {
          _expectSameEntry(
            entry,
            AcceptedRepository(
              repository: RepositoryDraft(
                address: parseRepositoryAddress(text)!,
                defaultBranch: defaultRepositoryBranch,
              ),
              hasStartedGit: false,
            ),
          );
        } else {
          _expectSameEntry(entry, RefusedRepository(problem));
        }
      }
    },
  );

  test(
    'test_read_typed_repository_property_folder_paths_are_checked',
    () async {
      final Random random = seededRandom(54002);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String text = _randomTypedText(random);
        final CheckedFolder checked = _randomCheckedFolder(random, i);
        final _FolderChecks checks = _FolderChecks(
          (String _) async => checked,
        );

        final RepositoryEntry entry = await readTypedRepository(
          text: text,
          checkFolder: checks.check,
          listAddedAddresses: () => const <String>[],
        );

        if (looksLikeFolderPath(text)) {
          expect(checks.checkedPaths, <String>[text]);
          _expectSameEntry(
            entry,
            AcceptedRepository(
              repository: checked.repository,
              hasStartedGit: checked.hasStartedGit,
            ),
          );
        } else {
          expect(checks.checkedPaths, isEmpty);
        }
      }
    },
  );

  test(
    'test_read_typed_repository_property_no_check_never_reads_folders',
    () async {
      final Random random = seededRandom(54003);

      for (int i = 0; i < propertyIterations; i += 1) {
        final String text = randomFolderPath(random, i);

        final RepositoryEntry entry = await readTypedRepository(
          text: text,
          checkFolder: null,
          listAddedAddresses: () => const <String>[],
        );

        final String? problem = describeRepositoryEntryProblem(
          text: text,
          addedAddresses: const <String>[],
        );
        expect(problem, isNotNull);
        _expectSameEntry(entry, RefusedRepository(problem!));
      }
    },
  );

  test(
    'test_read_checked_folder_property_new_folder_kept_with_git_start',
    () async {
      final Random random = seededRandom(54004);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CheckedFolder checked = _randomCheckedFolder(random, i);

        final RepositoryEntry entry = await readCheckedFolder(
          folderAnswer: Future<CheckedFolder>.value(checked),
          listAddedAddresses: () => _randomAddedAddresses(random),
        );

        _expectSameEntry(
          entry,
          AcceptedRepository(
            repository: checked.repository,
            hasStartedGit: checked.hasStartedGit,
          ),
        );
      }
    },
  );

  test(
    'test_read_checked_folder_property_added_after_answer_is_refused',
    () async {
      final Random random = seededRandom(54005);

      for (int i = 0; i < propertyIterations; i += 1) {
        final CheckedFolder checked = _randomCheckedFolder(random, i);
        final Completer<CheckedFolder> answer = Completer<CheckedFolder>();
        final List<String> added = _randomAddedAddresses(random);

        final Future<RepositoryEntry> reading = readCheckedFolder(
          folderAnswer: answer.future,
          listAddedAddresses: () => added,
        );
        added.add(checked.repository.address);
        answer.complete(checked);

        _expectSameEntry(
          await reading,
          const RefusedRepository(repositoryAlreadyAddedProblem),
        );
      }
    },
  );

  test(
    'test_read_checked_folder_property_explains_or_passes_problems',
    () async {
      final Random random = seededRandom(54006);

      for (int i = 0; i < propertyIterations; i += 1) {
        final bool isExplained = random.nextBool();
        final ExplainedRefusal refusal = randomExplainedRefusal(random);
        final FormatException unexplained = randomUnexplainedProblem(random);
        final Object problem = isExplained ? refusal.problem : unexplained;

        final Future<RepositoryEntry> reading = readCheckedFolder(
          folderAnswer: Future<CheckedFolder>.error(problem),
          listAddedAddresses: () => const <String>[],
        );

        if (isExplained) {
          _expectSameEntry(
            await reading,
            RefusedRepository(refusal.explanation),
          );
        } else {
          await expectLater(reading, throwsA(same(unexplained)));
        }
      }
    },
  );
}
