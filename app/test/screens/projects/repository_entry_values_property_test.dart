import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/screens/projects/repository_entry.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';

RepositoryDraft _randomDraft(Random random, int round) {
  return RepositoryDraft(
    address: random.nextBool()
        ? randomCanonicalHostedAddress(random)
        : renderEditorFolderAddress(randomFolderPath(random, round)),
    defaultBranch: pickOne(random, <String>['main', 'trunk', 'dev']),
  );
}

void main() {
  test('test_accepted_repository_new_property_keeps_every_field', () {
    final Random random = seededRandom(54601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryDraft repository = _randomDraft(random, i);
      final bool hasStartedGit = random.nextBool();

      final AcceptedRepository accepted = AcceptedRepository(
        repository: repository,
        hasStartedGit: hasStartedGit,
      );

      expect(accepted.repository, same(repository));
      expect(accepted.hasStartedGit, hasStartedGit);
    }
  });

  test('test_accepted_repository_new_property_is_a_repository_entry', () {
    final Random random = seededRandom(54602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryEntry entry = AcceptedRepository(
        repository: _randomDraft(random, i),
        hasStartedGit: random.nextBool(),
      );

      final bool isAccepted = switch (entry) {
        AcceptedRepository() => true,
        RefusedRepository() => false,
      };
      expect(isAccepted, isTrue);
    }
  });

  test('test_accepted_repository_new_property_const_values_are_canonical', () {
    const AcceptedRepository first = AcceptedRepository(
      repository: RepositoryDraft(address: 'a', defaultBranch: 'main'),
      hasStartedGit: true,
    );
    const AcceptedRepository second = AcceptedRepository(
      repository: RepositoryDraft(address: 'a', defaultBranch: 'main'),
      hasStartedGit: true,
    );

    expect(identical(first, second), isTrue);
  });

  test('test_refused_repository_new_property_keeps_the_problem', () {
    final Random random = seededRandom(54604);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String problem = randomHostileText(random);

      final RefusedRepository refused = RefusedRepository(problem);

      expect(refused.problem, same(problem));
    }
  });

  test('test_refused_repository_new_property_is_a_repository_entry', () {
    final Random random = seededRandom(54605);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RepositoryEntry entry = RefusedRepository(
        randomHostileText(random),
      );

      final bool isRefused = switch (entry) {
        AcceptedRepository() => false,
        RefusedRepository() => true,
      };
      expect(isRefused, isTrue);
    }
  });

  test('test_refused_repository_new_property_const_values_are_canonical', () {
    const RefusedRepository first = RefusedRepository('taken');
    const RefusedRepository second = RefusedRepository('taken');

    expect(identical(first, second), isTrue);
    expect(first.problem, 'taken');
  });
}
