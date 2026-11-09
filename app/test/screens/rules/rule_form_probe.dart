import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/screens/rules/rule_form.dart';
import 'package:agent_orchestration/screens/shared/scope_fields.dart';
import 'package:agent_orchestration/screens/shared/scope_selection.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';
import 'package:agent_orchestration/widgets/forms/removable_tag.dart';

import '../../support/app_harness.dart';
import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/rule_title_white_space_table.dart';
import '../../support/sample_records.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';

const String ruleTitleLabel = 'Rule';
const String ruleDetailsLabel = 'Details';
const String ruleSubmitLabel = 'Save rule';
const String ruleLeaveLabel = 'Cancel';
const String emptyRuleTitleProblem = 'Write the rule';

final class RuleFormProbe {
  RuleFormProbe({required this.initialRule});

  final RuleDraft initialRule;
  final List<RuleDraft> submitted = <RuleDraft>[];
  final List<RuleDraft> reported = <RuleDraft>[];
  int leaveTaps = 0;
  Object? plannedProblem;
  Completer<void>? pendingSave;

  Widget build() {
    return RuleForm(
      key: UniqueKey(),
      initialRule: initialRule,
      catalog: galleryCatalog,
      onChanged: reported.add,
      actions: <FormAction<RuleDraft>>[
        LeaveFormAction<RuleDraft>(label: ruleLeaveLabel, onPressed: _leave),
        SubmitFormAction<RuleDraft>(
          label: ruleSubmitLabel,
          tone: ButtonTone.primary,
          onSubmitted: _save,
        ),
      ],
    );
  }

  void _leave() {
    leaveTaps += 1;
  }

  Future<void> _save(RuleDraft draft) async {
    submitted.add(draft);
    final Completer<void>? pending = pendingSave;
    if (pending != null) {
      await pending.future;
    }
    final Object? problem = plannedProblem;
    if (problem != null) {
      await Future<void>.error(problem);
    }
  }
}

RuleDraft randomInitialRuleDraft(
  Random random,
  RuleTitleWhiteSpaceTable table,
) {
  return RuleDraft(
    title: table.randomExoticTitle(random),
    details: table.randomExoticTitle(random),
    scope: randomScopeOrNowhere(random),
  );
}

Future<RuleFormProbe> pumpRuleFormAtRandomWidth(
  WidgetTester tester,
  Random random, {
  required RuleDraft initialRule,
}) async {
  final RuleFormProbe probe = RuleFormProbe(initialRule: initialRule);
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: probe.build());
  return probe;
}

String readRuleField(WidgetTester tester, String label) {
  final TextField field = tester.widget<TextField>(findFieldInput(label));
  final TextEditingController? controller = field.controller;
  if (controller == null) {
    throw StateError('the $label field has no controller');
  }
  return controller.text;
}

Finder findRuleFormButton(String label) {
  return find.widgetWithText(AppButton, label);
}

Future<void> submitRuleForm(WidgetTester tester) async {
  await tester.pump(settleTime);
  await tapVisible(tester, findRuleFormButton(ruleSubmitLabel));
  await tester.pump();
}

List<String> readShownScopeTags(WidgetTester tester, String label) {
  final Finder block = find.byWidgetPredicate(
    (Widget widget) => widget is FormFieldBlock && widget.label == label,
  );
  final Finder tags = find.descendant(
    of: block,
    matching: find.byType(RemovableTag),
  );
  final List<String> labels = <String>[];
  for (final RemovableTag tag in tester.widgetList<RemovableTag>(tags)) {
    labels.add(tag.label);
  }
  return labels;
}

ScopeSelection randomScopeSelection(Random random) {
  return ScopeSelection(
    workspaceIds: pickSome(random, sampleWorkspaceIds),
    projectIds: pickSome(random, sampleProjectIds),
  );
}

Future<void> chooseRuleScope(
  WidgetTester tester,
  ScopeSelection selection,
) async {
  final ScopeFields fields = tester.widget<ScopeFields>(
    find.byType(ScopeFields),
  );
  fields.onChanged(selection);
  await tester.pump();
}
