import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/new_items/draft_review.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/random_page_windows.dart';
import 'draft_record_fields.dart';

final class RecordedDraftCallbacks {
  final List<DraftedItem> changes = <DraftedItem>[];
  final List<DraftedItem> approvals = <DraftedItem>[];
  final TapCounter cancels = TapCounter();

  DraftFormCallbacks get callbacks {
    return DraftFormCallbacks(
      onChanged: changes.add,
      onApproved: _recordApproval,
      onCancelled: cancels.countTap,
    );
  }

  Future<void> _recordApproval(DraftedItem item) async {
    approvals.add(item);
  }
}

DraftFormCallbacks ignoringCallbacks() {
  return RecordedDraftCallbacks().callbacks;
}

AppNavigation newSkillsNavigation() {
  return AppNavigation(initialRoute: const SectionRoute(AppSection.skills));
}

AppNavigation newRulesNavigation() {
  return AppNavigation(initialRoute: const SectionRoute(AppSection.rules));
}

List<Object?> describeSkillDraft(SkillDraft skill) {
  return describeSkillFields(
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: skill.scope,
    usage: skill.usage,
    improvement: skill.improvement,
  );
}

List<Object?> describeSkill(Skill skill) {
  return describeSkillFields(
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: skill.scope,
    usage: skill.usage,
    improvement: skill.improvement,
  );
}

List<Object?> describeRuleDraft(RuleDraft rule) {
  return describeRuleFields(
    title: rule.title,
    details: rule.details,
    scope: rule.scope,
  );
}

List<Object?> describeRule(Rule rule) {
  return describeRuleFields(
    title: rule.title,
    details: rule.details,
    scope: rule.scope,
  );
}

SkillDraft scopeEverywhere(SkillDraft skill) {
  return SkillDraft(
    name: skill.name,
    summary: skill.summary,
    instructions: skill.instructions,
    scope: const Scope.everywhere(),
    usage: skill.usage,
    improvement: skill.improvement,
  );
}
