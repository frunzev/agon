import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_library.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/workflow.dart';
import 'package:agent_orchestration/widgets/forms/check_field.dart';
import 'package:agent_orchestration/widgets/forms/tag_input_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import 'agent_settings_panel_scene.dart';

const SkillId _deletedSkillId = SkillId('deleted-skill');
List<SkillId> _randomSkillIds(Random random) {
  final List<SkillId> skillIds = <SkillId>[
    for (final Skill skill in gallerySkills)
      if (random.nextBool()) skill.id,
  ];
  if (random.nextBool()) {
    skillIds.insert(random.nextInt(skillIds.length + 1), _deletedSkillId);
  }
  return skillIds;
}

Future<AgentSettingsScene> _pumpWithSkills(
  WidgetTester tester,
  Random random,
  List<SkillId> skillIds,
) {
  return pumpAgentSettings(
    tester,
    random: random,
    agent: randomSettingsAgent(random).copyWith(skills: skillIds),
    canFillIn: false,
  );
}

TagInputField _readTags(WidgetTester tester) {
  return tester.widget(find.byType(TagInputField));
}

void main() {
  testWidgets('test_build_skills_field_property_tags_name_known_skills', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162301);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillId> skillIds = _randomSkillIds(random);

      await _pumpWithSkills(tester, random, skillIds);

      expect(_readTags(tester).tags, <String>[
        for (final Skill skill in gallerySkills)
          if (skillIds.contains(skill.id)) skill.name,
      ]);
    }
  });

  testWidgets('test_build_skills_field_property_suggests_every_skill', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162302);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      await _pumpWithSkills(tester, random, _randomSkillIds(random));

      expect(_readTags(tester).suggestions, <String>[
        for (final Skill skill in gallerySkills) skill.name,
      ]);
      expect(_readTags(tester).placeholder, 'Add a skill');
    }
  });

  testWidgets('test_build_skills_field_property_toggle_flips_only_it', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162303);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentSettingsScene scene = await _pumpWithSkills(
        tester,
        random,
        _randomSkillIds(random),
      );
      final WorkflowAgent agent = scene.shownAgent.value;
      final CheckField check = tester.widget(find.byType(CheckField));

      expect(check.label, automaticSkillsLabel);
      expect(check.value, agent.usesAutomaticSkills);
      check.onChanged(!agent.usesAutomaticSkills);

      expect(scene.changes, <WorkflowAgent>[
        agent.copyWith(usesAutomaticSkills: !agent.usesAutomaticSkills),
      ]);
    }
  });

  testWidgets('test_add_skill_property_typed_name_appends_its_id', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162307);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillId> skillIds = _randomSkillIds(random);
      final List<Skill> free = <Skill>[
        for (final Skill skill in gallerySkills)
          if (!skillIds.contains(skill.id)) skill,
      ];
      if (free.isEmpty) {
        continue;
      }
      final Skill added = pickOne(random, free);
      final AgentSettingsScene scene = await _pumpWithSkills(
        tester,
        random,
        skillIds,
      );

      await addFieldTag(tester, label: skillsFieldLabel, tag: added.name);

      expect(scene.changes.single.skills, <SkillId>[...skillIds, added.id]);
    }
  });

  testWidgets('test_add_skill_property_keeps_every_other_field', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162308);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentSettingsScene scene = await _pumpWithSkills(
        tester,
        random,
        const <SkillId>[_deletedSkillId],
      );
      final WorkflowAgent agent = scene.shownAgent.value;
      final Skill added = pickOne(random, gallerySkills);

      _readTags(tester).onTagAdded(added.name);

      expect(
        scene.changes.single,
        agent.copyWith(skills: <SkillId>[_deletedSkillId, added.id]),
      );
    }
  });

  testWidgets('test_add_skill_property_unknown_names_are_refused', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162309);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final AgentSettingsScene scene = await _pumpWithSkills(
        tester,
        random,
        _randomSkillIds(random),
      );

      await addFieldTag(
        tester,
        label: skillsFieldLabel,
        tag: 'not-a-skill-${randomText(random)}',
      );

      expect(tester.takeException(), isNull, reason: 'round $i');
      expect(scene.changes, isEmpty);
    }
  });

  testWidgets('test_remove_skill_property_drops_every_copy_only', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162310);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Skill removed = pickOne(random, gallerySkills);
      final List<SkillId> skillIds = <SkillId>[
        ..._randomSkillIds(random),
        removed.id,
        removed.id,
      ]..shuffle(random);
      final AgentSettingsScene scene = await _pumpWithSkills(
        tester,
        random,
        skillIds,
      );

      _readTags(tester).onTagRemoved(removed.name);

      expect(scene.changes.single.skills, <SkillId>[
        for (final SkillId skillId in skillIds)
          if (skillId != removed.id) skillId,
      ]);
    }
  });

  testWidgets('test_remove_skill_property_keeps_toggle_and_policy', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162311);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillId> skillIds = <SkillId>[
        for (final Skill skill in gallerySkills) skill.id,
      ];
      final AgentSettingsScene scene = await _pumpWithSkills(
        tester,
        random,
        skillIds,
      );
      final WorkflowAgent agent = scene.shownAgent.value;
      final Skill removed = pickOne(random, gallerySkills);

      _readTags(tester).onTagRemoved(removed.name);

      final WorkflowAgent changed = scene.changes.single;
      expect(changed.usesAutomaticSkills, agent.usesAutomaticSkills);
      expect(changed.approvalPolicy, agent.approvalPolicy);
      expect(changed.task, agent.task);
      expect(changed.kind, agent.kind);
    }
  });

  testWidgets('test_remove_skill_property_add_then_remove_round_trips', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(1162312);
    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<SkillId> skillIds = _randomSkillIds(random);
      final List<Skill> free = <Skill>[
        for (final Skill skill in gallerySkills)
          if (!skillIds.contains(skill.id)) skill,
      ];
      if (free.isEmpty) {
        continue;
      }
      final Skill toggled = pickOne(random, free);
      final AgentSettingsScene scene = await _pumpWithSkills(
        tester,
        random,
        skillIds,
      );

      _readTags(tester).onTagAdded(toggled.name);
      await tester.pump();
      _readTags(tester).onTagRemoved(toggled.name);

      expect(scene.changes.last.skills, skillIds);
    }
  });
}
