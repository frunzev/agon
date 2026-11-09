import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/skills/skill_form_screen.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/page_header.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'random_skills.dart';
import 'skill_form_probe.dart';
import 'skill_form_screen_page.dart';

Future<void> _tapButton(WidgetTester tester, String label) async {
  await pumpFrames(tester);
  await tapVisible(tester, findSkillFormButton(label));
  await pumpFrames(tester);
}

List<String> _readShownTexts(WidgetTester tester) {
  return <String>[
    for (final String label in <String>[
      skillNameLabel,
      skillSummaryLabel,
      skillInstructionsLabel,
    ])
      tester.widget<TextField>(findFieldInput(label)).controller!.text,
  ];
}

void main() {
  test('test_skill_form_screen_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(1121001);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppDependencies dependencies = buildGalleryDependencies();
      final List<Skill> skills = randomShownSkills(random);
      final Skill? existingSkill = random.nextBool()
          ? pickOne(random, skills)
          : null;
      final AppNavigation navigation = openSkillFormRoutes(existingSkill);

      final SkillFormScreen screen = SkillFormScreen(
        existingSkill: existingSkill,
        skillRepository: dependencies.skillRepository,
        workspaceRepository: dependencies.workspaceRepository,
        projectRepository: dependencies.projectRepository,
        navigation: navigation,
      );

      expect(screen.existingSkill, same(existingSkill));
      expect(screen.skillRepository, same(dependencies.skillRepository));
      expect(
        screen.workspaceRepository,
        same(dependencies.workspaceRepository),
      );
      expect(screen.projectRepository, same(dependencies.projectRepository));
      expect(screen.navigation, same(navigation));
    }
  });

  testWidgets('test_skill_form_screen_constructor_property_a_new_skill_'
      'starts_blank_and_everywhere', (WidgetTester tester) async {
    final Random random = seededRandom(1121002);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: null,
        storedSkills: randomShownSkills(random),
      );

      expect(_readShownTexts(tester), <String>['', '', '']);
      expect(find.text('All workspaces unless you add some.'), findsOneWidget);
      final ChoiceListField<SkillUsage> usage = tester
          .widget<ChoiceListField<SkillUsage>>(
            find.byType(ChoiceListField<SkillUsage>),
          );
      expect(usage.selected, SkillUsage.automatic);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_form_screen_constructor_property_cancel_leaves_'
      'without_saving', (WidgetTester tester) async {
    final Random random = seededRandom(1121003);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final Skill? existingSkill = random.nextBool()
          ? pickOne(random, skills)
          : null;
      final SkillFormScreenPage page = await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: existingSkill,
        storedSkills: skills,
      );
      final List<AppRoute> routes = page.navigation.routes;
      await enterFieldText(
        tester,
        label: skillSummaryLabel,
        text: 'Changed ${randomText(random)}',
      );

      final bool usesBackLink = random.nextBool();
      if (usesBackLink) {
        await tapVisible(tester, find.byType(BackLinkButton));
        await pumpFrames(tester);
      } else {
        await _tapButton(tester, cancelSkillLabel);
      }

      final List<AppRoute> expectedRoutes = existingSkill == null
          ? const <AppRoute>[skillsSectionRoute]
          : routes.sublist(0, routes.length - 1);
      expect(page.navigation.routes, expectedRoutes);
      expect(page.skillRepository.saveCount, 0);
    }
  });

  testWidgets('test_skill_form_screen_build_property_names_the_mode_at_any_'
      'size', (WidgetTester tester) async {
    final Random random = seededRandom(1121004);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final Skill? skill = random.nextBool() ? pickOne(random, skills) : null;
      await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: skill,
        storedSkills: skills,
      );

      final PageHeader header = tester.widget<PageHeader>(
        find.byType(PageHeader),
      );
      expect(header.title, skill == null ? 'New skill' : 'Edit skill');
      expect(header.backLink?.label, skill == null ? 'Skills' : skill.name);
      expect(findSkillFormButton(saveSkillLabel), findsOneWidget);
      expect(findSkillFormButton(cancelSkillLabel), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_skill_form_screen_build_property_an_edit_may_keep_its_'
      'own_name_but_not_take_another', (WidgetTester tester) async {
    final Random random = seededRandom(1121005);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final Skill edited = pickOne(random, skills);
      final List<Skill> others = <Skill>[
        for (final Skill skill in skills)
          if (skill.id != edited.id) skill,
      ];
      final bool takesAnother = others.isNotEmpty && random.nextBool();
      final SkillFormScreenPage page = await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: edited,
        storedSkills: skills,
      );
      if (takesAnother) {
        final Skill other = pickOne(random, others);
        await enterFieldText(tester, label: skillNameLabel, text: other.name);
      }

      await _tapButton(tester, saveSkillLabel);

      expect(page.skillRepository.saveCount, takesAnother ? 0 : 1);
      expect(readFieldProblem(tester, skillNameLabel) != null, takesAnother);
    }
  });

  testWidgets('test_skill_form_screen_build_property_a_new_skill_may_not_'
      'take_a_listed_name', (WidgetTester tester) async {
    final Random random = seededRandom(1121006);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final Skill listed = pickOne(random, skills);
      final SkillFormScreenPage page = await pumpSkillFormScreen(
        tester,
        random,
        existingSkill: null,
        storedSkills: skills,
      );
      await enterFieldText(tester, label: skillNameLabel, text: listed.name);
      await enterFieldText(tester, label: skillSummaryLabel, text: 'Summary');
      await enterFieldText(tester, label: skillInstructionsLabel, text: 'Do');

      await _tapButton(tester, saveSkillLabel);

      expect(
        readFieldProblem(tester, skillNameLabel),
        'A skill named ${listed.name} already exists',
      );
      expect(page.skillRepository.saveCount, 0);
      expect(page.navigation.currentRoute, isA<NewItemFormRoute>());
    }
  });
}
