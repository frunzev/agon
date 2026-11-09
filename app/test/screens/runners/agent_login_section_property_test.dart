import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/agent_login.dart';
import 'package:agent_orchestration/data/models/runner.dart';
import 'package:agent_orchestration/presentation/agent_login_text.dart';
import 'package:agent_orchestration/screens/runners/agent_login_section.dart';
import 'package:agent_orchestration/screens/runners/api_key_form.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/random_inputs.dart';
import 'agent_login_probe.dart';

const AgentLoginStatus _keylessDocker = AgentLoginStatus(
  claudeLogin: ClaudeLogin.loggedIn,
  containerCredential: null,
);

Future<RecordingAgentLoginRepository> _pumpOne(
  WidgetTester tester,
  Random random, {
  required AgentPlace place,
  required AgentLoginStatus status,
}) async {
  final RecordingAgentLoginRepository repository = buildLoginRepository(
    status,
  );
  await pumpLoginSections(
    tester,
    random,
    places: <AgentPlace>[place],
    repository: repository,
  );
  return repository;
}

void main() {
  test('test_agent_login_section_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(108501);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        randomLoginStatus(random),
      );

      final AgentLoginSection section = AgentLoginSection(
        place: place,
        repository: repository,
      );

      expect(section.place, place);
      expect(section.repository, same(repository));
    }
  });

  testWidgets('test_agent_login_section_constructor_property_names_its_'
      'place', (WidgetTester tester) async {
    final Random random = seededRandom(108502);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      await _pumpOne(
        tester,
        random,
        place: place,
        status: randomLoginStatus(random),
      );

      expect(find.text(describeAgentLoginTitle(place)), findsOneWidget);
      for (final AgentPlace other in AgentPlace.values) {
        if (other != place) {
          expect(find.text(describeAgentLoginTitle(other)), findsNothing);
        }
      }
    }
  });

  testWidgets('test_agent_login_section_constructor_property_status_label_'
      'follows_readiness', (WidgetTester tester) async {
    final Random random = seededRandom(108503);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final AgentLoginStatus status = randomLoginStatus(random);
      await _pumpOne(tester, random, place: place, status: status);

      final AgentLoginDescription description = describeAgentLogin(
        place: place,
        status: status,
      );
      final StatusLabel label = tester.widget<StatusLabel>(
        find.byType(StatusLabel),
      );
      final StatusTone expectedTone = description.isReady
          ? StatusTone.normal
          : StatusTone.attention;
      expect(label.text, description.statusText);
      expect(label.tone, expectedTone);
    }
  });

  test('test_agent_login_section_create_state_property_each_call_is_a_'
      'fresh_state', () {
    final Random random = seededRandom(108504);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AgentLoginSection section = AgentLoginSection(
        place: pickOne(random, AgentPlace.values),
        repository: buildLoginRepository(randomLoginStatus(random)),
      );

      final State<AgentLoginSection> first = section.createState();
      final State<AgentLoginSection> second = section.createState();

      expect(identical(first, second), isFalse);
      expect(first.mounted, isFalse);
    }
  });

  testWidgets('test_agent_login_section_create_state_property_a_new_'
      'section_forgets_the_key_form', (WidgetTester tester) async {
    final Random random = seededRandom(108505);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = await _pumpOne(
        tester,
        random,
        place: AgentPlace.container,
        status: _keylessDocker,
      );
      await tapLoginButton(tester, useApiKeyLabel);
      expect(find.byType(ApiKeyForm), findsOneWidget);

      await pumpLoginSections(
        tester,
        random,
        places: const <AgentPlace>[AgentPlace.container],
        repository: repository,
      );

      expect(find.byType(ApiKeyForm), findsNothing);
      expect(find.text(useApiKeyLabel), findsOneWidget);
    }
  });

  testWidgets('test_agent_login_section_create_state_property_the_key_'
      'form_survives_rebuilds', (WidgetTester tester) async {
    final Random random = seededRandom(108506);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = await _pumpOne(
        tester,
        random,
        place: AgentPlace.container,
        status: _keylessDocker,
      );
      await tapLoginButton(tester, useApiKeyLabel);

      await repository.checkStatus();
      await tester.pump();

      expect(find.byType(ApiKeyForm), findsOneWidget);
    }
  });

  testWidgets('test_agent_login_section_init_state_property_checks_the_'
      'status_once', (WidgetTester tester) async {
    final Random random = seededRandom(108507);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<AgentPlace> places = <AgentPlace>[
        for (final AgentPlace place in AgentPlace.values)
          if (random.nextBool()) place,
      ];
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        randomLoginStatus(random),
      );

      await pumpLoginSections(
        tester,
        random,
        places: places,
        repository: repository,
      );

      expect(repository.statusChecks, places.length);
    }
  });

  testWidgets('test_agent_login_section_init_state_property_rebuilds_do_'
      'not_check_again', (WidgetTester tester) async {
    final Random random = seededRandom(108508);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final RecordingAgentLoginRepository repository = await _pumpOne(
        tester,
        random,
        place: pickOne(random, AgentPlace.values),
        status: randomLoginStatus(random),
      );

      tester.element(find.byType(AgentLoginSection)).markNeedsBuild();
      await tester.pump();
      repository.revealStatus();
      await tester.pump();

      expect(repository.statusChecks, 1);
    }
  });

  testWidgets('test_agent_login_section_init_state_property_shows_nothing_'
      'until_the_status_arrives', (WidgetTester tester) async {
    final Random random = seededRandom(108509);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentPlace place = pickOne(random, AgentPlace.values);
      final RecordingAgentLoginRepository repository = buildLoginRepository(
        randomLoginStatus(random),
      );
      repository.isStatusHidden = true;
      await pumpLoginSections(
        tester,
        random,
        places: <AgentPlace>[place],
        repository: repository,
      );
      expect(find.text(describeAgentLoginTitle(place)), findsNothing);

      repository.revealStatus();
      await tester.pump();

      expect(find.text(describeAgentLoginTitle(place)), findsOneWidget);
    }
  });
}
