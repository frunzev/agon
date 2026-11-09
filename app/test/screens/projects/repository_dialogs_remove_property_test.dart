import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'project_screen_inputs.dart';
import 'repository_dialog_steps.dart';

const String _removeLabel = 'Remove repo';
const String _closeLabel = 'Close';
const Map<AgentAccess, String> _accessWords = <AgentAccess, String>{
  AgentAccess.readOnly: 'Read only',
  AgentAccess.pushAfterApproval: 'Read and push',
};

List<Repository> _atLeastOneRepository(Random random) {
  final List<Repository> repositories = randomScreenRepositories(random);
  if (repositories.isNotEmpty) {
    return repositories;
  }
  return <Repository>[
    const Repository(
      address: 'github.com/acme/only',
      defaultBranch: 'main',
      agentAccess: AgentAccess.readOnly,
    ),
  ];
}

typedef _RemovalPage = ({
  StoredProject stored,
  Repository repository,
  DialogClosing closing,
});

StoredProject _buildRemovableProject(Random random) {
  return buildStoredProject(random, _atLeastOneRepository(random));
}

Future<_RemovalPage> _openRemoveDialog(
  WidgetTester tester,
  Random random,
  StoredProject stored,
) async {
  final Repository chosen = pickOne(random, stored.project.repositories);
  final DialogClosing closing = DialogClosing();
  await tester.pumpWidget(const SizedBox.shrink());
  final BuildContext hostContext = await pumpDialogHost(tester, random);
  final Future<void> shown = showRemoveRepositoryDialog(
    context: hostContext,
    project: stored.project,
    repository: chosen,
    projectRepository: stored.repository,
  );
  unawaited(shown.then(closing.recordClosed));
  await pumpFrames(tester);
  return (stored: stored, repository: chosen, closing: closing);
}

List<String> _storedAddresses(_RemovalPage page) {
  final ProjectRepository repository = page.stored.repository;
  return <String>[
    for (final Repository stored
        in repository.findProject(page.stored.project.id).repositories)
      stored.address,
  ];
}

void main() {
  testWidgets('test_show_remove_repository_dialog_property_shows_every_'
      'fact', (WidgetTester tester) async {
    final Random random = seededRandom(1061601);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RemovalPage page = await _openRemoveDialog(
        tester,
        random,
        _buildRemovableProject(random),
      );
      final Repository repository = page.repository;

      final String path = describeRepositoryPath(repository.address);
      expect(find.text(path), findsWidgets);
      expect(find.text(repository.address), findsOneWidget);
      expect(find.text(repository.defaultBranch), findsOneWidget);
      expect(find.text(_accessWords[repository.agentAccess]!), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_show_remove_repository_dialog_property_close_keeps_'
      'the_repo', (WidgetTester tester) async {
    final Random random = seededRandom(1061602);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RemovalPage page = await _openRemoveDialog(
        tester,
        random,
        _buildRemovableProject(random),
      );
      final List<String> before = _storedAddresses(page);

      await tapDialogButton(tester, _closeLabel);

      expect(page.closing.isClosed, isTrue);
      expect(_storedAddresses(page), before);
    }
  });

  testWidgets('test_show_remove_repository_dialog_property_removes_only_'
      'that_repo', (WidgetTester tester) async {
    final Random random = seededRandom(1061603);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _RemovalPage page = await _openRemoveDialog(
        tester,
        random,
        _buildRemovableProject(random),
      );
      final List<String> expected = <String>[
        for (final String address in _storedAddresses(page))
          if (address != page.repository.address) address,
      ];

      await tapDialogButton(tester, _removeLabel);

      expect(_storedAddresses(page), expected);
      expect(page.closing.isClosed, isTrue);
    }
  });

  testWidgets('test_remove_repository_property_double_tap_removes_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1061604);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final StoredProject stored = _buildRemovableProject(random);
      final HeldChangesProjectRepository held = HeldChangesProjectRepository(
        stored.repository,
      );
      final _RemovalPage page = await _openRemoveDialog(tester, random, (
        project: stored.project,
        repository: held,
      ));
      await tapDialogButton(tester, _removeLabel);
      await tapDialogButton(tester, _removeLabel);

      held.release.complete();
      await pumpFrames(tester);

      expect(held.removalCount, 1);
      expect(find.text('$_removeLabel did not work'), findsNothing);
      expect(page.closing.isClosed, isTrue);
    }
  });
}
