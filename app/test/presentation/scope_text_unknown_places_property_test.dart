import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';
import 'package:agent_orchestration/presentation/scope_text.dart';

import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';
import '../support/random_unknown_scope_places.dart';
import '../support/sample_scopes.dart';

const String _nowhereLabel = 'Nowhere';

Scope _randomScopeListingOnlyUnknownPlaces(Random random) {
  if (random.nextBool()) {
    return Scope(
      workspaces: OnlyWorkspaces(
        mixInUnknownWorkspaces(random, const <WorkspaceId>[]),
      ),
      projects: const AllProjects(),
    );
  }
  return Scope(
    workspaces: const AllWorkspaces(),
    projects: OnlyProjects(mixInUnknownProjects(random, const <ProjectId>[])),
  );
}

void _expectNoUnknownIdentifier(String shownText) {
  expect(shownText, isNot(contains('unknown-')));
}

void main() {
  test('test_describe_scope_chips_property_unknown_places_read_like_'
      'pruned_ones', () {
    final Random random = seededRandom(110411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeWithUnknownPlaces(random, catalog);
      final Scope pruned = pruneUnknownPlacesByHand(scope, catalog);

      final List<String> chips = describeScopeChips(scope, catalog);

      expect(chips, describeScopeChips(pruned, catalog));
      expect(chips, isNotEmpty);
      chips.forEach(_expectNoUnknownIdentifier);
    }
  });

  test('test_describe_scope_chips_property_only_unknown_places_read_'
      'nowhere', () {
    final Random random = seededRandom(110412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = _randomScopeListingOnlyUnknownPlaces(random);

      expect(describeScopeChips(scope, catalog), <String>[_nowhereLabel]);
    }
  });

  test('test_describe_scope_chips_property_known_names_keep_their_'
      'order', () {
    final Random random = seededRandom(110413);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final List<WorkspaceId> known = pickSome(
        random,
        listCatalogWorkspaceIds(catalog),
      );
      if (known.isEmpty) {
        continue;
      }
      final Scope scope = Scope(
        workspaces: OnlyWorkspaces(mixInUnknownWorkspaces(random, known)),
        projects: const AllProjects(),
      );

      expect(describeScopeChips(scope, catalog), <String>[
        for (final WorkspaceId workspaceId in known)
          catalog.nameOfWorkspace(workspaceId),
      ]);
    }
  });

  test('test_describe_scope_line_property_unknown_places_read_like_'
      'pruned_ones', () {
    final Random random = seededRandom(110414);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeWithUnknownPlaces(random, catalog);
      final Scope pruned = pruneUnknownPlacesByHand(scope, catalog);

      final String line = describeScopeLine(scope, catalog);

      expect(line, describeScopeLine(pruned, catalog));
      expect(line, isNotEmpty);
      _expectNoUnknownIdentifier(line);
    }
  });

  test('test_describe_scope_line_property_only_unknown_places_read_'
      'nowhere', () {
    final Random random = seededRandom(110415);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = _randomScopeListingOnlyUnknownPlaces(random);

      expect(describeScopeLine(scope, catalog), _nowhereLabel);
    }
  });

  test('test_describe_scope_line_property_matches_the_chips_names', () {
    final Random random = seededRandom(110416);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeWithUnknownPlaces(random, catalog);

      final String line = describeScopeLine(scope, catalog);
      final List<String> chips = describeScopeChips(scope, catalog);

      for (final String chip in chips) {
        expect(line, contains(chip));
      }
    }
  });
}
