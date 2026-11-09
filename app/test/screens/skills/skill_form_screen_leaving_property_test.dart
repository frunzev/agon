import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/skills/skills_screen.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../support/form_leaving_scene.dart';
import 'skill_form_probe.dart';

const SectionRoute _skillsRoute = SectionRoute(AppSection.skills);

List<AppRoute> _randomNewSkillRoutes(Random random) {
  final AppRoute form = NewItemFormRoute(DraftKind.skill);
  if (random.nextBool()) {
    return <AppRoute>[_skillsRoute, form];
  }
  return <AppRoute>[_skillsRoute, const NewSkillRoute(), form];
}

Future<void> _leaveForm(WidgetTester tester, Random random) async {
  if (random.nextBool()) {
    await pressBackLink(tester);
    return;
  }
  await pressShownButton(tester, cancelSkillLabel);
  await pumpFrames(tester);
}

void main() {
  testWidgets('test_skill_form_screen_build_property_a_new_skill_form_'
      'leaves_to_the_skills_list_its_back_link_names', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(5310901);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewSkillRoutes(random),
      );
      final String backLabel = readBackLinkLabel(tester);

      await _leaveForm(tester, random);

      expect(tester.takeException(), isNull);
      expect(backLabel, AppSection.skills.label);
      expect(scene.navigation.routes, const <AppRoute>[_skillsRoute]);
      expect(find.byType(SkillsScreen), findsOneWidget);
    }
  });

  testWidgets('test_skill_form_screen_build_property_an_edit_leaves_to_the_'
      'skill_it_names', (WidgetTester tester) async {
    final Random random = seededRandom(5310902);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = buildGalleryDependencies().skillRepository
          .listSkills();
      final Skill skill = pickOne(random, skills);
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: <AppRoute>[
          _skillsRoute,
          SkillDetailRoute(skill.id),
          EditSkillRoute(skill.id),
        ],
      );
      final String backLabel = readBackLinkLabel(tester);

      await _leaveForm(tester, random);

      expect(backLabel, skill.name);
      expect(scene.navigation.routes, <AppRoute>[
        _skillsRoute,
        SkillDetailRoute(skill.id),
      ]);
    }
  });

  testWidgets('test_skill_form_screen_build_property_leaving_stores_'
      'nothing', (WidgetTester tester) async {
    final Random random = seededRandom(5310903);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final FormLeavingScene scene = await openFormInApp(
        tester,
        random: random,
        routes: _randomNewSkillRoutes(random),
      );
      final List<Skill> skillsBefore = scene.dependencies.skillRepository
          .listSkills();
      await enterFieldText(
        tester,
        label: skillNameLabel,
        text: 'typed-${random.nextInt(1000)}',
      );

      await _leaveForm(tester, random);

      expect(scene.dependencies.skillRepository.listSkills(), skillsBefore);
    }
  });
}
