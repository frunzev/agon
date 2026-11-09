import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/icons/app_icon_kind.dart';
import 'package:agent_orchestration/presentation/skill_text.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/lists/list_row_main.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';
import 'package:agent_orchestration/widgets/status_label.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'random_skills.dart';
import 'skill_form_screen_page.dart';
import 'skills_screen_page.dart';

const String _newSkillLabel = 'New skill';

List<Skill> _randomListedOrNone(Random random) {
  if (random.nextBool()) {
    return const <Skill>[];
  }
  return randomShownSkills(random);
}

typedef _RowBand = ({double top, double bottom});

const double _bandTolerance = 16;

Finder _findTitleOf(Skill skill) {
  return find.byWidgetPredicate(
    (Widget widget) => widget is ListRowMain && widget.title == skill.name,
  );
}

_RowBand _readBandOf(WidgetTester tester, List<Skill> skills, Skill skill) {
  final double top = tester.getTopLeft(_findTitleOf(skill)).dy;
  double bottom = double.infinity;
  for (final Skill other in skills) {
    final double otherTop = tester.getTopLeft(_findTitleOf(other)).dy;
    if (otherTop > top && otherTop < bottom) {
      bottom = otherTop;
    }
  }
  return (top: top - _bandTolerance, bottom: bottom - _bandTolerance);
}

List<Element> _findInBand(WidgetTester tester, _RowBand band, Finder found) {
  final List<Element> inBand = <Element>[];
  for (final Element element in found.evaluate()) {
    final double middle = tester.getCenter(find.byWidget(element.widget)).dy;
    if (middle >= band.top && middle < band.bottom) {
      inBand.add(element);
    }
  }
  return inBand;
}

void main() {
  testWidgets('test_build_new_skill_button_property_opens_the_new_skill_'
      'page_from_both_states', (WidgetTester tester) async {
    final Random random = seededRandom(1121701);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillsPage page = await openSkillsPage(
        tester,
        random,
        skills: _randomListedOrNone(random),
      );

      await tapVisible(tester, find.text(_newSkillLabel));
      await pumpFrames(tester);

      expect(page.navigation.routes, const <AppRoute>[
        skillsSectionRoute,
        NewSkillRoute(),
      ]);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_build_new_skill_button_property_one_primary_plus_'
      'button', (WidgetTester tester) async {
    final Random random = seededRandom(1121702);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await openSkillsPage(
        tester,
        random,
        skills: _randomListedOrNone(random),
      );

      final Finder button = find.widgetWithText(AppButton, _newSkillLabel);
      expect(button, findsOneWidget);
      final AppButton shown = tester.widget<AppButton>(button);
      expect(shown.icon, AppIconKind.plus);
      expect(shown.tone, ButtonTone.primary);
    }
  });

  testWidgets('test_build_new_skill_button_property_a_second_tap_opens_'
      'nothing_more', (WidgetTester tester) async {
    final Random random = seededRandom(1121703);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final SkillsPage page = await openSkillsPage(
        tester,
        random,
        skills: _randomListedOrNone(random),
      );
      final AppButton button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, _newSkillLabel),
      );

      button.onPressed!();
      button.onPressed!();
      await pumpFrames(tester);

      expect(page.navigation.routes, const <AppRoute>[
        skillsSectionRoute,
        NewSkillRoute(),
      ]);
    }
  });

  testWidgets('test_skills_screen_build_row_property_shows_reach_users_'
      'and_use', (WidgetTester tester) async {
    final Random random = seededRandom(1121704);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final SkillsPage page = await openSkillsPage(
        tester,
        random,
        skills: skills,
      );

      for (final Skill skill in skills) {
        final String users = describeSkillUsers(
          skillId: skill.id,
          workflows: page.dependencies.workflowRepository.listWorkflows(),
          jobs: page.dependencies.jobRepository.listJobs(),
          tasks: page.dependencies.taskRepository.listTasks(),
        );
        final ListRowMain main = tester.widget<ListRowMain>(
          _findTitleOf(skill),
        );
        final String subtitle = <String>[
          for (final TextSegment segment in main.subtitle) segment.text,
        ].join();
        final _RowBand band = _readBandOf(tester, skills, skill);
        final Finder reach = find.text(modelSkillReach(skill));
        expect(main.titleFace, TextFace.monospace);
        expect(subtitle, skill.summary);
        expect(_findInBand(tester, band, reach), hasLength(1));
        expect(_findInBand(tester, band, find.text(users)), hasLength(1));
      }
    }
  });

  testWidgets('test_skills_screen_build_row_property_only_automatic_'
      'skills_stand_out', (WidgetTester tester) async {
    final Random random = seededRandom(1121705);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      await openSkillsPage(tester, random, skills: skills);

      for (final Skill skill in skills) {
        final _RowBand band = _readBandOf(tester, skills, skill);
        final List<Element> statuses = _findInBand(
          tester,
          band,
          find.byType(StatusLabel),
        );
        expect(statuses, hasLength(1), reason: skill.name);
        final StatusLabel status = statuses.single.widget as StatusLabel;
        final StatusTone expectedTone = skill.usage == SkillUsage.automatic
            ? StatusTone.normal
            : StatusTone.muted;
        expect(status.text, skill.usage.label);
        expect(status.tone, expectedTone);
      }
    }
  });

  testWidgets('test_skills_screen_build_row_property_a_tap_opens_that_'
      'skill', (WidgetTester tester) async {
    final Random random = seededRandom(1121706);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Skill> skills = randomShownSkills(random);
      final SkillsPage page = await openSkillsPage(
        tester,
        random,
        skills: skills,
      );
      final Skill tapped = pickOne(random, skills);

      await tapVisible(tester, find.text(tapped.name));
      await pumpFrames(tester);

      expect(page.navigation.routes, <AppRoute>[
        skillsSectionRoute,
        SkillDetailRoute(tapped.id),
      ]);
      expect(tester.takeException(), isNull);
    }
  });
}
