import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/rules/rule_form.dart';
import 'package:agent_orchestration/screens/skills/skill_form.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/forms/form_action.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/random_nowhere_scopes.dart';
import '../../support/sample_scopes.dart';
import '../../support/widget_harness.dart';
import '../new_items/draft_record_fields.dart';

const String _nowhereHintStart = 'Nowhere: ';
const String _ruleSubmitLabel = 'Save rule';
const String _skillSubmitLabel = 'Save skill';

typedef _BuildScopedForm = Widget Function(
  Scope scope,
  List<Scope> submittedScopes,
  List<Scope> reportedScopes,
);

final class _ScopedFormCase {
  const _ScopedFormCase({
    required this.functionName,
    required this.submitLabel,
    required this.editedFieldLabel,
    required this.buildForm,
  });

  final String functionName;
  final String submitLabel;
  final String editedFieldLabel;
  final _BuildScopedForm buildForm;
}

Widget _buildRuleForm(
  Scope scope,
  List<Scope> submittedScopes,
  List<Scope> reportedScopes,
) {
  return RuleForm(
    key: UniqueKey(),
    initialRule: RuleDraft(
      title: 'Keep tests green',
      details: '',
      scope: scope,
    ),
    catalog: galleryCatalog,
    onChanged: (RuleDraft draft) => reportedScopes.add(draft.scope),
    actions: <FormAction<RuleDraft>>[
      SubmitFormAction<RuleDraft>(
        label: _ruleSubmitLabel,
        tone: ButtonTone.primary,
        onSubmitted: (RuleDraft draft) async =>
            submittedScopes.add(draft.scope),
      ),
    ],
  );
}

Widget _buildSkillForm(
  Scope scope,
  List<Scope> submittedScopes,
  List<Scope> reportedScopes,
) {
  return SkillForm(
    key: UniqueKey(),
    initialSkill: SkillDraft(
      name: 'notes-writer',
      summary: 'Writes release notes',
      instructions: 'Read the commits and write the notes.',
      scope: scope,
      usage: SkillUsage.automatic,
      improvement: SkillImprovement.never,
    ),
    otherSkills: const <Skill>[],
    catalog: galleryCatalog,
    onChanged: (SkillDraft draft) => reportedScopes.add(draft.scope),
    actions: <FormAction<SkillDraft>>[
      SubmitFormAction<SkillDraft>(
        label: _skillSubmitLabel,
        tone: ButtonTone.primary,
        onSubmitted: (SkillDraft draft) async =>
            submittedScopes.add(draft.scope),
      ),
    ],
  );
}

const List<_ScopedFormCase> _scopedFormCases = <_ScopedFormCase>[
  _ScopedFormCase(
    functionName: 'rule_form_read_rule',
    submitLabel: _ruleSubmitLabel,
    editedFieldLabel: 'Details',
    buildForm: _buildRuleForm,
  ),
  _ScopedFormCase(
    functionName: 'skill_form_read_skill',
    submitLabel: _skillSubmitLabel,
    editedFieldLabel: 'Instructions',
    buildForm: _buildSkillForm,
  ),
];

Future<void> _pumpForm(WidgetTester tester, Random random, Widget form) async {
  final double width = randomWidth(
    random,
    least: narrowestWidth,
    most: widestWidth,
  );
  await pumpScrollableAtWidth(tester, width: width, child: form);
}

void _registerScopedFormProperties(_ScopedFormCase formCase, int seed) {
  final String prefix = 'test_${formCase.functionName}_property';

  testWidgets('${prefix}_saving_untouched_keeps_an_empty_scope', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Scope scope = randomScopeListingNoPlace(random);
      final List<Scope> submitted = <Scope>[];
      final Widget form = formCase.buildForm(scope, submitted, <Scope>[]);
      await _pumpForm(tester, random, form);

      await tapVisible(tester, find.text(formCase.submitLabel));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(submitted, hasLength(1));
      expect(
        describeScopeFields(submitted.single),
        describeScopeFields(scope),
      );
    }
  });

  testWidgets('${prefix}_reported_drafts_keep_an_empty_scope', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed + 1);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final Scope scope = randomScopeListingNoPlace(random);
      final List<Scope> reported = <Scope>[];
      final Widget form = formCase.buildForm(scope, <Scope>[], reported);
      await _pumpForm(tester, random, form);

      await enterFieldText(
        tester,
        label: formCase.editedFieldLabel,
        text: 'x${randomText(random)}',
      );

      expect(reported, isNotEmpty);
      expect(describeScopeFields(reported.last), describeScopeFields(scope));
    }
  });

  testWidgets('${prefix}_an_empty_scope_reads_as_nowhere', (
    WidgetTester tester,
  ) async {
    final Random random = seededRandom(seed + 2);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final bool isNowhere = random.nextBool();
      final Scope scope = isNowhere
          ? randomScopeListingNoPlace(random)
          : const Scope.everywhere();
      final Widget form = formCase.buildForm(scope, <Scope>[], <Scope>[]);
      await _pumpForm(tester, random, form);

      final Finder nowhereHint = find.textContaining(_nowhereHintStart);
      expect(tester.takeException(), isNull);
      expect(nowhereHint, isNowhere ? findsWidgets : findsNothing);
    }
  });
}

void main() {
  int seed = 51501;
  for (final _ScopedFormCase formCase in _scopedFormCases) {
    _registerScopedFormProperties(formCase, seed);
    seed += 10;
  }
}
