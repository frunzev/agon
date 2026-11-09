import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/screens/runners/agent_offers_section.dart';
import 'package:agent_orchestration/widgets/forms/check_choice_list_field.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import 'agent_offers_probe.dart';

void _ignoreOffers(List<AgentPlace> offers) {}

void main() {
  test('test_agent_offers_section_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(108101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomNodeOffers(random);
      final Key key = ValueKey<int>(i);

      final AgentOffersSection section = AgentOffersSection(
        offers: offers,
        onChanged: _ignoreOffers,
        key: key,
      );

      expect(section.offers, same(offers));
      expect(section.onChanged, _ignoreOffers);
      expect(section.key, key);
    }
  });

  testWidgets('test_agent_offers_section_constructor_property_the_given_'
      'listener_hears_each_tap', (WidgetTester tester) async {
    final Random random = seededRandom(108102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomNodeOffers(random);
      final OffersProbe probe = await pumpOffersSection(
        tester,
        random,
        offers,
      );
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await tapOfferedPlace(tester, place);

      final bool isLastOffer =
          offers.length == 1 && offers.single.place == place;
      expect(probe.emitted, hasLength(isLastOffer ? 0 : 1));
    }
  });

  testWidgets('test_agent_offers_section_constructor_property_offers_'
      'decide_the_ticks', (WidgetTester tester) async {
    final Random random = seededRandom(108103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomNodeOffers(random);
      await pumpOffersSection(tester, random, offers);

      expect(readOffersField(tester).selected, listOfferedPlaces(offers));
    }
  });

  testWidgets('test_agent_offers_section_build_property_lists_both_places_'
      'in_design_order', (WidgetTester tester) async {
    final Random random = seededRandom(108104);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpOffersSection(tester, random, randomNodeOffers(random));

      final Offset dockerTop = tester.getTopLeft(find.text('In Docker'));
      final Offset localTop = tester.getTopLeft(find.text('On this computer'));
      expect(tester.takeException(), isNull);
      expect(dockerTop.dy, lessThan(localTop.dy));
      expect(find.text(agentOffersTitle), findsOneWidget);
      expect(find.text(agentOffersHint), findsOneWidget);
      for (final AgentPlace place in AgentPlace.values) {
        expect(find.text(describeAgentPlaceDetail(place)), findsOneWidget);
      }
    }
  });

  testWidgets('test_agent_offers_section_build_property_blocked_offers_'
      'show_their_problem', (WidgetTester tester) async {
    final Random random = seededRandom(108105);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomNodeOffers(random);
      await pumpOffersSection(tester, random, offers);

      for (final PlaceOffer offer in offers) {
        final String? problem = offer.problem;
        if (problem != null && problem.trim().isNotEmpty) {
          expect(find.text(problem), findsWidgets, reason: problem);
        }
      }
    }
  });

  testWidgets('test_agent_offers_section_build_property_renders_hostile_'
      'problems_at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(108106);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpOffersSection(tester, random, <PlaceOffer>[
        for (final AgentPlace place in placesInNodeOrder)
          PlaceOffer(place: place, problem: randomHostileText(random)),
      ]);

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_agent_offers_section_find_offered_places_property_'
      'ticks_each_offered_place_once', (WidgetTester tester) async {
    final Random random = seededRandom(108107);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = <PlaceOffer>[
        ...randomNodeOffers(random),
        ...randomNodeOffers(random),
      ];
      await pumpOffersSection(tester, random, offers);

      final CheckChoiceListField<AgentPlace> field = readOffersField(tester);
      expect(field.selected, listOfferedPlaces(offers));
      expect(field.options, hasLength(AgentPlace.values.length));
    }
  });

  testWidgets('test_agent_offers_section_find_offered_places_property_'
      'ticks_follow_emitted_offers', (WidgetTester tester) async {
    final Random random = seededRandom(108108);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomNodeOffers(random);
      final OffersProbe probe = await pumpOffersSection(
        tester,
        random,
        offers,
      );
      await tapOfferedPlace(tester, pickOne(random, AgentPlace.values));
      if (probe.emitted.isEmpty) {
        continue;
      }
      final List<PlaceOffer> nextOffers = <PlaceOffer>[
        for (final AgentPlace place in probe.emitted.single)
          PlaceOffer(place: place, problem: null),
      ];

      await pumpOffersSection(tester, random, nextOffers);

      expect(readOffersField(tester).selected, probe.emitted.single.toSet());
    }
  });

  testWidgets('test_agent_offers_section_find_problem_property_each_place_'
      'shows_its_own_problem', (WidgetTester tester) async {
    final Random random = seededRandom(108109);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<PlaceOffer> offers = randomNodeOffers(random);
      await pumpOffersSection(tester, random, offers);

      for (final CheckChoiceOption<AgentPlace> option in readOffersField(
        tester,
      ).options) {
        final Iterable<PlaceOffer> matching = offers.where(
          (PlaceOffer offer) => offer.place == option.value,
        );
        final String? expected = matching.isEmpty
            ? null
            : matching.first.problem;
        expect(option.problem, expected);
      }
    }
  });
}
