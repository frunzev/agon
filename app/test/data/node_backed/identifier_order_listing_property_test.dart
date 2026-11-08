import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/node_backed/identifier_order.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'support/identifier_ordered_records.dart';

typedef _Listed = ({String identifier, int position});

const int _largestListingLength = 9;

String _identifyListed(_Listed listed) => listed.identifier;

List<_Listed> _randomUnsortedListing(Random random) {
  final Set<String> identifiers = <String>{};
  final int length = random.nextInt(_largestListingLength);
  for (int i = 0; i < length; i += 1) {
    identifiers.add(randomHostileText(random));
  }
  final List<_Listed> listing = <_Listed>[];
  for (final String identifier in identifiers) {
    listing.add((identifier: identifier, position: listing.length));
  }
  listing.shuffle(random);
  return listing;
}

List<String> _listIdentifiers(List<_Listed> listing) {
  return <String>[for (final _Listed listed in listing) listed.identifier];
}

List<_Listed> _order(List<_Listed> listing) {
  return listInIdentifierOrder(listing, identify: _identifyListed);
}

void main() {
  test('test_list_in_identifier_order_property_results_are_in_id_order', () {
    final Random random = seededRandom(89601);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_Listed> listing = _randomUnsortedListing(random);

      final List<_Listed> ordered = _order(listing);

      expect(isInIdentifierOrder(_listIdentifiers(ordered)), isTrue);
    }
  });

  test('test_list_in_identifier_order_property_keeps_every_record', () {
    final Random random = seededRandom(89602);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_Listed> listing = _randomUnsortedListing(random);

      final List<_Listed> ordered = _order(listing);

      expect(ordered, unorderedEquals(listing));
    }
  });

  test('test_list_in_identifier_order_property_input_order_does_not_'
      'matter', () {
    final Random random = seededRandom(89603);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<_Listed> listing = _randomUnsortedListing(random);
      final List<_Listed> reshuffled = List<_Listed>.of(listing);
      reshuffled.shuffle(random);

      final List<_Listed> ordered = _order(listing);
      final List<_Listed> reorderedAgain = _order(reshuffled);

      expect(reorderedAgain, orderedEquals(ordered));
      expect(_order(ordered), orderedEquals(ordered));
    }
  });
}
