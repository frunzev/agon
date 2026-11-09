import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';
import 'package:agent_orchestration/shell/deleted_record_guard.dart';

import '../screens/support/random_page_windows.dart';
import '../support/app_harness.dart';
import '../support/random_inputs.dart';
import 'record_deletion_cases.dart';
import 'route_record_samples.dart';

Future<AppNavigation> _openStack(
  WidgetTester tester, {
  required Random random,
  required AppDependencies dependencies,
  required List<AppRoute> routes,
}) async {
  final AppNavigation navigation = await pumpApp(
    tester,
    size: randomPageWindowSize(random),
    route: routes.first,
    dependencies: dependencies,
  );
  navigation.restoreRoutes(routes);
  await pumpFrames(tester);
  return navigation;
}

SampledRoute _sampleUnknownRecordRoute(
  Random random,
  AppDependencies dependencies,
) {
  SampledRoute sample = sampleRecordRoute(random, dependencies);
  while (!sample.usesUnknownRecord) {
    sample = sampleRecordRoute(random, dependencies);
  }
  return sample;
}

void main() {
  testWidgets('test_deleted_record_guard_build_property_a_record_deleted_'
      'elsewhere_closes_its_pages', (WidgetTester tester) async {
    final Random random = seededRandom(5311101);

    for (int i = 0; i < widgetPropertyIterations * 2; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final RecordDeletionCase deletion = randomRecordDeletionCase(
        random,
        dependencies,
      );
      final AppNavigation navigation = await _openStack(
        tester,
        random: random,
        dependencies: dependencies,
        routes: deletion.routes,
      );
      expect(tester.takeException(), isNull, reason: '${deletion.routes}');

      await deletion.deleteRecord();
      await pumpFrames(tester);

      expect(tester.takeException(), isNull, reason: '${deletion.routes}');
      expect(navigation.routes, <AppRoute>[deletion.routes.first]);
    }
  });

  testWidgets('test_deleted_record_guard_build_property_another_deletion_'
      'keeps_the_page', (WidgetTester tester) async {
    final Random random = seededRandom(5311102);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Skill> skills = dependencies.skillRepository.listSkills();
      final Skill shown = pickOne(random, skills);
      final List<Skill> otherSkills = <Skill>[
        for (final Skill skill in skills)
          if (skill.id != shown.id) skill,
      ];
      final Skill deleted = pickOne(random, otherSkills);
      final List<AppRoute> routes = <AppRoute>[
        const SectionRoute(AppSection.skills),
        SkillDetailRoute(shown.id),
        if (random.nextBool()) EditSkillRoute(shown.id),
      ];
      final AppNavigation navigation = await _openStack(
        tester,
        random: random,
        dependencies: dependencies,
        routes: routes,
      );

      await dependencies.skillRepository.deleteSkill(deleted.id);
      await pumpFrames(tester);

      expect(tester.takeException(), isNull);
      expect(navigation.routes, routes);
      expect(find.text(shown.name), findsWidgets);
    }
  });

  testWidgets('test_deleted_record_guard_build_property_a_stale_link_closes_'
      'without_crashing', (WidgetTester tester) async {
    final Random random = seededRandom(5311103);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final SampledRoute stale = _sampleUnknownRecordRoute(
        random,
        dependencies,
      );
      final SectionRoute section = SectionRoute(stale.route.section);
      final AppNavigation navigation = await _openStack(
        tester,
        random: random,
        dependencies: dependencies,
        routes: <AppRoute>[section],
      );

      navigation.openRoute(stale.route);
      await pumpFrames(tester);

      expect(tester.takeException(), isNull, reason: '${stale.route}');
      expect(navigation.routes, <AppRoute>[section]);
      expect(find.byType(DeletedRecordGuard), findsOneWidget);
    }
  });
}
