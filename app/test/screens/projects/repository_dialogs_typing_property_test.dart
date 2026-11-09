import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/project.dart';

import '../../support/fixed_folder_picker.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'project_repositories_editor_inputs.dart';
import 'project_screen_inputs.dart';
import 'repository_dialog_steps.dart';

const String _sharedCasesPath =
    '../rust/crates/orchestration-core/tests/fixtures/'
    'repository_address_cases.json';
const List<String> _credentialPrefixes = <String>[
  'https://user:ghp_secret@',
  'https://x-access-token:abc123@',
  'https://ghp_token@',
  'HTTPS://git@',
  'deploy@',
];

typedef _SharedAddressCase = ({String address, String? canonical});

List<_SharedAddressCase> _readSharedCases() {
  final String text = File(_sharedCasesPath).readAsStringSync();
  final List<Object?> entries = jsonDecode(text) as List<Object?>;
  final List<_SharedAddressCase> cases = <_SharedAddressCase>[];
  for (final Object? entry in entries) {
    final Map<String, Object?> fields = entry! as Map<String, Object?>;
    cases.add((
      address: fields['address']! as String,
      canonical: fields['canonical'] as String?,
    ));
  }
  return cases;
}

FolderPicker? _randomPicker(Random random) {
  return random.nextBool() ? FixedFolderPicker(null) : null;
}

Future<AddRepositoryDialogPage> _openDialog(
  WidgetTester tester,
  Random random,
  List<Repository> repositories,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  return openAddRepositoryDialog(
    tester,
    random: random,
    stored: buildStoredProject(random, repositories),
    folderPicker: _randomPicker(random),
  );
}

List<Repository> _hostedRepositories(Random random) {
  final List<Repository> repositories = <Repository>[];
  for (final Repository repository in randomScreenRepositories(random)) {
    if (!repository.address.startsWith('local:')) {
      repositories.add(repository);
    }
  }
  return repositories;
}

void main() {
  final List<_SharedAddressCase> sharedCases = _readSharedCases();

  testWidgets('test_add_typed_repository_property_dialog_agrees_with_the_'
      'shared_table', (WidgetTester tester) async {
    final Random random = seededRandom(1061201);

    for (final _SharedAddressCase sharedCase in sharedCases) {
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random,
        <Repository>[],
      );

      await typeAddressAndAdd(tester, sharedCase.address);

      final String? canonical = sharedCase.canonical;
      final List<String> expected = canonical == null
          ? <String>[]
          : <String>[canonical];
      expect(page.listStoredAddresses(), expected, reason: sharedCase.address);
      expect(page.closing.isClosed, canonical != null);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_add_typed_repository_property_any_spelling_stores_the_'
      'canonical_once', (WidgetTester tester) async {
    final Random random = seededRandom(1061202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random,
        randomScreenRepositories(random),
      );
      final List<String> before = page.listStoredAddresses();
      final String canonical = '${randomCanonicalHostedAddress(random)}-new';

      await typeAddressAndAdd(tester, randomSpellingOf(random, canonical));

      expect(page.listStoredAddresses(), <String>[...before, canonical]);
      expect(page.listStoredRepositories().last.defaultBranch, 'main');
    }
  });

  testWidgets('test_add_typed_repository_property_credentials_are_refused_'
      'by_name', (WidgetTester tester) async {
    final Random random = seededRandom(1061203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random,
        randomScreenRepositories(random),
      );
      final List<String> before = page.listStoredAddresses();
      final String prefix = pickOne(random, _credentialPrefixes);
      final String typed = '$prefix${randomCanonicalHostedAddress(random)}';

      await typeAddressAndAdd(tester, typed);

      expect(page.listStoredAddresses(), before, reason: typed);
      expect(page.closing.isClosed, isFalse);
      final TextField field = tester.widget(findFieldInput(addressFieldLabel));
      expect(field.decoration!.errorText, contains('token'), reason: typed);
    }
  });

  testWidgets('test_list_added_addresses_property_any_spelling_of_an_added_'
      'repo_is_refused', (WidgetTester tester) async {
    final Random random = seededRandom(1061204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Repository> repositories = _hostedRepositories(random);
      if (repositories.isEmpty) {
        continue;
      }
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random,
        repositories,
      );
      final String added = pickOne(random, repositories).address;

      await typeAddressAndAdd(tester, randomSpellingOf(random, added));

      expect(find.text(alreadyAddedProblem), findsOneWidget, reason: added);
      expect(page.listStoredAddresses(), hasLength(repositories.length));
      expect(page.closing.isClosed, isFalse);
    }
  });

  testWidgets('test_list_added_addresses_property_path_case_makes_a_new_'
      'repo', (WidgetTester tester) async {
    final Random random = seededRandom(1061205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final String canonical = 'github.com/acme/app${random.nextInt(99)}';
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random,
        <Repository>[
          Repository(
            address: canonical,
            defaultBranch: 'main',
            agentAccess: pickOne(random, AgentAccess.values),
          ),
        ],
      );
      final String otherCase = canonical.replaceFirst('acme', 'Acme');

      await typeAddressAndAdd(tester, otherCase);

      expect(page.listStoredAddresses(), <String>[canonical, otherCase]);
      expect(find.text(alreadyAddedProblem), findsNothing);
    }
  });

  testWidgets('test_list_added_addresses_property_a_refusal_clears_on_'
      'typing', (WidgetTester tester) async {
    final Random random = seededRandom(1061206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Repository> repositories = _hostedRepositories(random);
      if (repositories.isEmpty) {
        continue;
      }
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random,
        repositories,
      );
      await typeAddressAndAdd(tester, pickOne(random, repositories).address);
      expect(find.text(alreadyAddedProblem), findsOneWidget);

      final String canonical = '${randomCanonicalHostedAddress(random)}-x';
      await typeAddressAndAdd(tester, canonical);

      expect(find.text(alreadyAddedProblem), findsNothing);
      expect(page.listStoredAddresses().last, canonical);
    }
  });

  testWidgets('test_save_repository_property_keeps_the_chosen_access', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1061207);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random,
        <Repository>[],
      );
      final bool choosesReadOnly = random.nextBool();
      if (choosesReadOnly) {
        await tester.tap(find.text('Read only'));
        await tester.pump();
      }

      await typeAddressAndAdd(tester, randomCanonicalHostedAddress(random));

      final AgentAccess expected = choosesReadOnly
          ? AgentAccess.readOnly
          : AgentAccess.pushAfterApproval;
      expect(page.listStoredRepositories().single.agentAccess, expected);
    }
  });

  testWidgets('test_save_repository_property_closes_only_after_storing', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1061208);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AddRepositoryDialogPage page = await _openDialog(
        tester,
        random,
        randomScreenRepositories(random),
      );
      final int before = page.listStoredAddresses().length;

      final String canonical = '${randomCanonicalHostedAddress(random)}z';
      await typeAddressAndAdd(tester, canonical);

      expect(page.listStoredAddresses(), hasLength(before + 1));
      expect(page.closing.isClosed, isTrue);
      expect(find.text(addRepositoryLabel), findsNothing);
    }
  });
}
