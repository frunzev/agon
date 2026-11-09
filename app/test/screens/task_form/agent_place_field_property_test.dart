import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/screens/task_form/agent_place_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/select_entry.dart';
import 'package:agent_orchestration/widgets/forms/select_field.dart';

import '../../presentation/support/plain_shown_text.dart';
import '../../support/random_inputs.dart';
import 'task_form_scene.dart';

const String _designPage = 'task-new';
const String _designTitle = 'Where agents run';
const String _designHint =
    'Only runners that offer it take the task. A workflow runs all its '
    'agents there.';
const Map<AgentPlace, String> _designLabels = <AgentPlace, String>{
  AgentPlace.localProcess: "On the runner's computer",
  AgentPlace.container: 'In Docker',
};
const Duration _menuAnimation = Duration(seconds: 1);

final class _PlaceRecorder {
  final List<AgentPlace> chosen = <AgentPlace>[];

  void record(AgentPlace place) {
    chosen.add(place);
  }
}

void _ignorePlace(AgentPlace _) {}

void main() {
  test('test_agent_place_field_constructor_property_keeps_the_place', () {
    final Random random = seededRandom(1132501);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final AgentPlaceField field = AgentPlaceField(
        place: place,
        onChanged: _ignorePlace,
      );

      expect(field.place, place);
    }
  });

  test('test_agent_place_field_constructor_property_keeps_the_callback', () {
    final Random random = seededRandom(1132502);
    for (int i = 0; i < propertyIterations; i += 1) {
      final _PlaceRecorder recorder = _PlaceRecorder();
      final AgentPlace place = pickOne(random, AgentPlace.values);

      final AgentPlaceField field = AgentPlaceField(
        place: place,
        onChanged: recorder.record,
      );
      field.onChanged(place);

      expect(recorder.chosen, <AgentPlace>[place]);
    }
  });

  test('test_agent_place_field_constructor_property_no_key_unless_given', () {
    final Random random = seededRandom(1132503);
    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final Key key = ValueKey<int>(random.nextInt(1000));

      final AgentPlaceField bare = AgentPlaceField(
        place: place,
        onChanged: _ignorePlace,
      );
      final AgentPlaceField keyed = AgentPlaceField(
        place: place,
        onChanged: _ignorePlace,
        key: key,
      );

      expect(bare.key, isNull);
      expect(keyed.key, key);
    }
  });

  testWidgets('test_agent_place_field_build_property_shows_design_texts', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132504);
    final String designText = readDesignPageText(_designPage);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await pumpScrollingPage(
        tester,
        random: random,
        page: AgentPlaceField(place: place, onChanged: _ignorePlace),
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      final FormFieldBlock block = tester.widget(find.byType(FormFieldBlock));
      expect(block.label, _designTitle);
      expect(block.hint, _designHint);
      expect(find.text(_designHint), findsOneWidget);
      expect(find.text(_designLabels[place]!), findsWidgets);
      expect(designText, contains(' $_designTitle '));
      expect(designText, contains(' $_designHint '));
    }
  });

  testWidgets('test_agent_place_field_build_property_offers_every_place', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132505);
    final String designText = readDesignPageText(_designPage);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);

      await pumpScrollingPage(
        tester,
        random: random,
        page: AgentPlaceField(place: place, onChanged: _ignorePlace),
      );

      final SelectField<AgentPlace> select = tester.widget(
        find.byType(SelectField<AgentPlace>),
      );
      final List<SelectOption<AgentPlace>> options =
          <SelectOption<AgentPlace>>[
            for (final SelectEntry<AgentPlace> entry in select.entries)
              entry as SelectOption<AgentPlace>,
          ];
      expect(select.value, place);
      expect(listOptionValues(select.entries), _designLabels.keys.toList());
      for (final SelectOption<AgentPlace> option in options) {
        expect(option.label, _designLabels[option.value]);
        expect(designText, contains(' ${option.label} '));
      }
    }
  });

  testWidgets('test_agent_place_field_build_property_picking_reports_once', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1132506);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentPlace picked = pickOne(random, AgentPlace.values);
      final _PlaceRecorder recorder = _PlaceRecorder();
      await pumpScrollingPage(
        tester,
        random: random,
        page: AgentPlaceField(place: place, onChanged: recorder.record),
      );

      await tester.tap(find.byType(SelectField<AgentPlace>));
      await tester.pump();
      await tester.pump(_menuAnimation);
      await tester.tap(find.text(_designLabels[picked]!).last);
      await tester.pump();
      await tester.pump(_menuAnimation);

      expect(tester.takeException(), isNull);
      expect(recorder.chosen, <AgentPlace>[picked]);
    }
  });
}
