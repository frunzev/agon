import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/repository/pairing_repository.dart';
import 'package:agent_orchestration/screens/pairing.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import '../support/refused_action_properties.dart';
import 'pairing_flow_harness.dart';

const String _cancelLabel = 'Cancel';
const String _devicesLabel = 'Devices';

PairingCodeScreen _buildScreen() {
  final AppDependencies dependencies = buildGalleryDependencies();
  return PairingCodeScreen(
    pairingRepository: dependencies.pairingRepository,
    workspaceRepository: dependencies.workspaceRepository,
    clock: dependencies.clock,
    navigation: AppNavigation(initialRoute: devicesRoute),
  );
}

Future<PairingPage> _openLiveCodePage(WidgetTester tester, Random random) {
  return openPairingPage(
    tester,
    size: randomPairingWindow(random),
    route: const PairingCodeRoute(),
    session: buildLiveSession(problem: null),
    request: null,
  );
}

Future<void> _tapBackLink(WidgetTester tester) async {
  final Finder backLink = find.descendant(
    of: find.byType(BackLinkButton),
    matching: find.text(_devicesLabel),
  );
  await tester.ensureVisible(backLink);
  await tester.tap(backLink);
  await pumpFrames(tester);
}

void main() {
  test('test_pairing_code_screen_create_state_property_every_call_makes_a_'
      'fresh_state', () {
    final Random random = seededRandom(104701);

    for (int i = 0; i < propertyIterations; i += 1) {
      final PairingCodeScreen screen = _buildScreen();
      final int count = 2 + random.nextInt(4);

      final Set<State<PairingCodeScreen>> states = <State<PairingCodeScreen>>{
        for (int index = 0; index < count; index += 1) screen.createState(),
      };

      expect(states, hasLength(count));
    }
  });

  testWidgets('test_pairing_code_screen_create_state_property_a_new_page_'
      'starts_with_cancel_enabled', (WidgetTester tester) async {
    final Random random = seededRandom(104702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openPairingPage(
        tester,
        size: randomPairingWindow(random),
        route: const PairingCodeRoute(),
        session: random.nextBool() ? buildLiveSession(problem: null) : null,
        request: null,
      );

      expect(isButtonEnabled(tester, _cancelLabel), isTrue);
    }
  });

  testWidgets('test_pairing_code_screen_create_state_property_a_reopened_'
      'page_forgets_an_unfinished_cancel', (WidgetTester tester) async {
    final Random random = seededRandom(104703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openLiveCodePage(tester, random);
      final Completer<void> slowNode = Completer<void>();
      page.pairing.heldAction = slowNode;
      await tapButtonLabelled(tester, _cancelLabel);
      await _tapBackLink(tester);

      page.navigation.openRoute(const PairingCodeRoute());
      await pumpFrames(tester);

      expect(isButtonEnabled(tester, _cancelLabel), isTrue);
      page.pairing.heldAction = null;
      slowNode.complete();
      await pumpFrames(tester);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_stop_cancelling_property_cancel_is_disabled_only_while_'
      'the_node_answers', (WidgetTester tester) async {
    final Random random = seededRandom(104704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openLiveCodePage(tester, random);
      final Completer<void> slowNode = Completer<void>();
      page.pairing.heldAction = slowNode;

      await tapButtonLabelled(tester, _cancelLabel);
      expect(isButtonEnabled(tester, _cancelLabel), isFalse);
      page.pairing.heldAction = null;
      slowNode.complete();
      await pumpFrames(tester);

      expect(page.pairing.calls, <String>['cancel']);
      expect(page.navigation.routes, <AppRoute>[devicesRoute]);
    }
  });

  testWidgets('test_stop_cancelling_property_a_refused_cancel_can_be_'
      'tried_again', (WidgetTester tester) async {
    final Random random = seededRandom(104705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openLiveCodePage(tester, random);
      final Completer<void> slowNode = Completer<void>();
      page.pairing.heldAction = slowNode;
      await tapButtonLabelled(tester, _cancelLabel);

      page.pairing.session = null;
      page.pairing.heldAction = null;
      slowNode.complete();
      await pumpFrames(tester);

      expect(find.text(describeRefusalTitle(_cancelLabel)), findsOneWidget);
      expect(find.text(noShowingPairingCode), findsOneWidget);
      await tapButtonLabelled(tester, refusalCloseLabel);
      expect(isButtonEnabled(tester, _cancelLabel), isTrue);
      expect(find.byType(PairingCodeScreen), findsOneWidget);
    }
  });

  testWidgets('test_stop_cancelling_property_leaving_before_the_answer_'
      'raises_nothing', (WidgetTester tester) async {
    final Random random = seededRandom(104706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final PairingPage page = await _openLiveCodePage(tester, random);
      final Completer<void> slowNode = Completer<void>();
      page.pairing.heldAction = slowNode;

      await tapButtonLabelled(tester, _cancelLabel);
      await _tapBackLink(tester);
      page.pairing.heldAction = null;
      slowNode.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, <AppRoute>[devicesRoute]);
    }
  });
}
