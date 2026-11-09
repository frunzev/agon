import 'dart:async';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/random_inputs.dart';
import 'workflow_change_scene.dart';

const Duration _betweenTwoTaps = Duration(milliseconds: 80);
const List<AppRoute> _placesToMoveOn = <AppRoute>[
  SectionRoute(AppSection.devices),
  NewWorkflowRoute(),
  NewProjectRoute(),
];

void main() {
  testWidgets('test_workflow_change_screen_settle_change_property_settles_'
      'and_returns_to_workflows', (WidgetTester tester) async {
    final Random random = seededRandom(1220301);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SettlePage page = await openSettlePage(
        tester,
        random,
        refusal: null,
      );
      final bool signs = random.nextBool();

      await tapChangeAction(
        tester,
        signs ? signChangeLabel : discardChangeLabel,
      );
      await pumpFrames(tester);

      final Workflow settled = page.stored.findWorkflow(page.workflow.id);
      expect(tester.takeException(), isNull);
      expect(page.stored.findPendingChange(page.workflow.id), isNull);
      expect(page.navigation.routes, const <AppRoute>[changeWorkflowsRoute]);
      expect(page.saveHold.saveCount, 1);
      if (signs) {
        expect(settled.signature!.signedBy, GalleryDeviceIds.airLaptop);
      } else {
        expect(
          settled.signature!.signedDocument,
          page.workflow.signature!.signedDocument,
        );
      }
    }
  });

  testWidgets('test_workflow_change_screen_settle_change_property_double_'
      'taps_act_once', (WidgetTester tester) async {
    final Random random = seededRandom(1220302);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SettlePage page = await openSettlePage(
        tester,
        random,
        refusal: null,
      );
      final Completer<void> hold = Completer<void>();
      page.saveHold.hold = hold;
      final String first = random.nextBool()
          ? signChangeLabel
          : discardChangeLabel;
      final String second = random.nextBool()
          ? signChangeLabel
          : discardChangeLabel;

      await tapChangeAction(tester, first);
      await tester.pump(_betweenTwoTaps);
      await tapChangeAction(tester, second);
      await tester.pump(_betweenTwoTaps);
      hold.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.saveHold.saveCount, 1, reason: '$first then $second');
      expect(find.textContaining('did not work'), findsNothing);
      expect(page.navigation.routes, const <AppRoute>[changeWorkflowsRoute]);
    }
  });

  testWidgets('test_workflow_change_screen_settle_change_property_a_person_'
      'who_moved_on_stays_where_they_went', (WidgetTester tester) async {
    final Random random = seededRandom(1220303);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SettlePage page = await openSettlePage(
        tester,
        random,
        refusal: null,
      );
      final Completer<void> hold = Completer<void>();
      page.saveHold.hold = hold;

      await tapChangeAction(
        tester,
        random.nextBool() ? signChangeLabel : discardChangeLabel,
      );
      await tester.pump();
      final AppRoute place = pickOne(random, _placesToMoveOn);
      if (place is SectionRoute) {
        page.navigation.openSection(place);
      } else {
        page.navigation.openRoute(place);
      }
      await pumpFrames(tester);
      final List<AppRoute> wentTo = page.navigation.routes;
      hold.complete();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(page.navigation.routes, wentTo);
      expect(page.stored.findPendingChange(page.workflow.id), isNull);
    }
  });
}
