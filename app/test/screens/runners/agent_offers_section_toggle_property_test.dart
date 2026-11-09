import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/widgets/forms/check_choice_list_field.dart';

import '../../support/random_inputs.dart';
import 'agent_offers_probe.dart';

Map<AgentPlace, String?> _readShownProblems(WidgetTester tester) {
  return <AgentPlace, String?>{
    for (final CheckChoiceOption<AgentPlace> option in readOffersField(
      tester,
    ).options)
      option.value: option.problem,
  };
}

void main() {
  testWidgets('test_agent_offers_section_find_problem_property_unoffered_'
      'places_have_no_problem', (WidgetTester tester) async {
    final Random random = seededRandom(108201);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace offered = pickOne(random, AgentPlace.values);
      await pumpOffersSection(tester, random, <PlaceOffer>[
        PlaceOffer(place: offered, problem: 'blocked ${randomText(random)}'),
      ]);

      final Map<AgentPlace, String?> problems = _readShownProblems(tester);
      for (final AgentPlace place in AgentPlace.values) {
        if (place != offered) {
          expect(problems[place], isNull);
        }
      }
      expect(problems[offered], isNotNull);
    }
  });

  testWidgets('test_agent_offers_section_find_problem_property_a_working_'
      'offer_beside_a_blocked_one_shows_none', (WidgetTester tester) async {
    final Random random = seededRandom(108202);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace blocked = pickOne(random, AgentPlace.values);
      final String problem = 'blocked ${randomText(random)}';
      await pumpOffersSection(tester, random, <PlaceOffer>[
        for (final AgentPlace place in placesInNodeOrder)
          PlaceOffer(place: place, problem: place == blocked ? problem : null),
      ]);

      final Map<AgentPlace, String?> problems = _readShownProblems(tester);
      for (final AgentPlace place in AgentPlace.values) {
        expect(problems[place], place == blocked ? problem : null);
      }
    }
  });

  testWidgets('test_agent_offers_section_toggle_property_matches_the_'
      'set_model', (WidgetTester tester) async {
    final Random random = seededRandom(108203);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomNodeOffers(random);
      final OffersProbe probe = await pumpOffersSection(
        tester,
        random,
        offers,
      );
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await tapOfferedPlace(tester, place);

      final Set<AgentPlace>? expected = modelToggledPlaces(
        listOfferedPlaces(offers),
        place,
      );
      if (expected == null) {
        expect(probe.emitted, isEmpty);
      } else {
        expect(probe.emitted.single.toSet(), expected);
      }
    }
  });

  testWidgets('test_agent_offers_section_toggle_property_emits_distinct_'
      'non_empty_offers', (WidgetTester tester) async {
    final Random random = seededRandom(108204);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = <PlaceOffer>[
        ...randomNodeOffers(random),
        ...randomNodeOffers(random),
      ];
      final OffersProbe probe = await pumpOffersSection(
        tester,
        random,
        offers,
      );

      await tapOfferedPlace(tester, pickOne(random, AgentPlace.values));

      for (final List<AgentPlace> emitted in probe.emitted) {
        expect(emitted, isNotEmpty);
        expect(emitted.toSet(), hasLength(emitted.length));
      }
    }
  });

  testWidgets('test_agent_offers_section_toggle_property_toggling_twice_'
      'restores_the_offers', (WidgetTester tester) async {
    final Random random = seededRandom(108205);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = <PlaceOffer>[
        for (final AgentPlace place in placesInNodeOrder)
          PlaceOffer(place: place, problem: null),
      ];
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final OffersProbe first = await pumpOffersSection(
        tester,
        random,
        offers,
      );
      await tapOfferedPlace(tester, place);
      final List<PlaceOffer> afterFirst = <PlaceOffer>[
        for (final AgentPlace emitted in first.emitted.single)
          PlaceOffer(place: emitted, problem: null),
      ];

      final OffersProbe second = await pumpOffersSection(
        tester,
        random,
        afterFirst,
      );
      await tapOfferedPlace(tester, place);

      expect(second.emitted.single.toSet(), listOfferedPlaces(offers));
    }
  });

  testWidgets('test_agent_offers_section_find_offered_places_property_no_'
      'offers_tick_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(108206);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final OffersProbe probe = await pumpOffersSection(
        tester,
        random,
        const <PlaceOffer>[],
      );
      expect(readOffersField(tester).selected, isEmpty);
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await tapOfferedPlace(tester, place);

      expect(probe.emitted, <List<AgentPlace>>[
        <AgentPlace>[place],
      ]);
    }
  });
}
