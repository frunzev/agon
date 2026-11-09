import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_place_text.dart';
import 'package:agent_orchestration/screens/runners/agent_offers_section.dart';
import 'package:agent_orchestration/widgets/forms/check_choice_list_field.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const List<AgentPlace> placesInNodeOrder = <AgentPlace>[
  AgentPlace.localProcess,
  AgentPlace.container,
];

final class OffersProbe {
  final List<List<AgentPlace>> emitted = <List<AgentPlace>>[];
}

List<PlaceOffer> randomNodeOffers(Random random) {
  return <PlaceOffer>[
    for (final AgentPlace place in placesInNodeOrder)
      if (random.nextBool())
        PlaceOffer(place: place, problem: randomOptionalHostileText(random)),
  ];
}

Set<AgentPlace> listOfferedPlaces(List<PlaceOffer> offers) {
  return <AgentPlace>{for (final PlaceOffer offer in offers) offer.place};
}

Future<OffersProbe> pumpOffersSection(
  WidgetTester tester,
  Random random,
  List<PlaceOffer> offers,
) async {
  final OffersProbe probe = OffersProbe();
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: AgentOffersSection(offers: offers, onChanged: probe.emitted.add),
  );
  return probe;
}

CheckChoiceListField<AgentPlace> readOffersField(WidgetTester tester) {
  return tester.widget<CheckChoiceListField<AgentPlace>>(
    find.byType(CheckChoiceListField<AgentPlace>),
  );
}

Future<void> tapOfferedPlace(WidgetTester tester, AgentPlace place) async {
  await tapVisible(tester, find.text(describeAgentPlaceTitle(place)));
  await tester.pump();
}

Set<AgentPlace>? modelToggledPlaces(
  Set<AgentPlace> offered,
  AgentPlace place,
) {
  final Set<AgentPlace> next = <AgentPlace>{...offered};
  if (next.contains(place)) {
    next.remove(place);
  } else {
    next.add(place);
  }
  if (next.isEmpty) {
    return null;
  }
  return next;
}
