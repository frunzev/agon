import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/presentation/scope_catalog.dart';

import '../screens/new_items/draft_record_fields.dart';
import '../support/random_inputs.dart';
import '../support/random_scope_catalogs.dart';
import '../support/random_unknown_scope_places.dart';

void main() {
  test('test_keep_known_places_property_drops_only_unknown_places', () {
    final Random random = seededRandom(110401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeWithUnknownPlaces(random, catalog);

      final Scope knownScope = catalog.keepKnownPlaces(scope);

      expect(
        describeScopeFields(knownScope),
        describeScopeFields(pruneUnknownPlacesByHand(scope, catalog)),
      );
    }
  });

  test('test_keep_known_places_property_known_scopes_stay_the_same', () {
    final Random random = seededRandom(110402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeInCatalog(random, catalog);

      final Scope knownScope = catalog.keepKnownPlaces(scope);

      expect(describeScopeFields(knownScope), describeScopeFields(scope));
    }
  });

  test('test_keep_known_places_property_is_idempotent', () {
    final Random random = seededRandom(110403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ScopeCatalog catalog = randomScopeCatalog(random);
      final Scope scope = randomScopeWithUnknownPlaces(random, catalog);

      final Scope once = catalog.keepKnownPlaces(scope);
      final Scope twice = catalog.keepKnownPlaces(once);

      expect(describeScopeFields(twice), describeScopeFields(once));
      expect(scope.workspaces.runtimeType, once.workspaces.runtimeType);
      expect(scope.projects.runtimeType, once.projects.runtimeType);
    }
  });
}
