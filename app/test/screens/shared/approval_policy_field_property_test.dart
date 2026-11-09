import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/shared/approval_policy_field.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';

import '../../support/form_finders.dart';
import '../../support/random_inputs.dart';
import '../../support/widget_harness.dart';

const int _largestKeyNumber = 1000;
const List<ApprovalPolicy?> _selections = <ApprovalPolicy?>[
  null,
  ...ApprovalPolicy.values,
];

List<Object?> _describeChoice<T>(ChoiceOption<T> choice) {
  return <Object?>[choice.value, choice.title, choice.detail];
}

final class _FieldProbe {
  _FieldProbe(Random random)
    : fallback = pickOne(random, ApprovalPolicyFallback.values),
      selected = pickOne(random, _selections);

  final ApprovalPolicyFallback fallback;
  final ApprovalPolicy? selected;
  final List<ApprovalPolicy?> changes = <ApprovalPolicy?>[];

  ApprovalPolicyField build() {
    return ApprovalPolicyField(
      fallback: fallback,
      selected: selected,
      onChanged: changes.add,
    );
  }
}

Future<_FieldProbe> _pumpField(WidgetTester tester, Random random) async {
  final _FieldProbe probe = _FieldProbe(random);
  await pumpScrollableAtWidth(
    tester,
    width: randomWidth(random, least: narrowestWidth, most: widestWidth),
    child: probe.build(),
  );
  return probe;
}

void main() {
  test('test_build_approval_policy_choices_property_every_policy_once', () {
    final List<ApprovalPolicy> values = <ApprovalPolicy>[
      for (final ChoiceOption<ApprovalPolicy> choice
          in buildApprovalPolicyChoices())
        choice.value,
    ];

    expect(values.toSet(), ApprovalPolicy.values.toSet());
    expect(values, hasLength(ApprovalPolicy.values.length));
  });

  test('test_build_approval_policy_choices_property_texts_match_the_'
      'policy', () {
    for (final ChoiceOption<ApprovalPolicy> choice
        in buildApprovalPolicyChoices()) {
      expect(choice.title, describeApprovalPolicyTitle(choice.value));
      expect(choice.detail, describeApprovalPolicyDetail(choice.value));
    }
  });

  test('test_build_approval_policy_choices_property_titles_are_distinct_'
      'and_stable', () {
    final List<ChoiceOption<ApprovalPolicy>> first =
        buildApprovalPolicyChoices();
    final List<ChoiceOption<ApprovalPolicy>> second =
        buildApprovalPolicyChoices();
    final Set<String> titles = <String>{
      for (final ChoiceOption<ApprovalPolicy> choice in first) choice.title,
    };

    expect(titles, hasLength(first.length));
    expect(
      second.map(_describeChoice<ApprovalPolicy>).toList(),
      first.map(_describeChoice<ApprovalPolicy>).toList(),
    );
  });

  test('test_build_inheritable_approval_policy_choices_property_fallback_'
      'then_every_policy', () {
    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      final List<ChoiceOption<ApprovalPolicy?>> choices =
          buildInheritableApprovalPolicyChoices(fallback);

      expect(_describeChoice(choices.first), <Object?>[
        null,
        fallback.title,
        fallback.detail,
      ]);
      expect(
        choices.skip(1).map(_describeChoice<ApprovalPolicy?>).toList(),
        buildApprovalPolicyChoices().map(_describeChoice<ApprovalPolicy>),
      );
    }
  });

  test('test_build_inheritable_approval_policy_choices_property_one_'
      'choice_per_value', () {
    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      final List<ApprovalPolicy?> values = <ApprovalPolicy?>[
        for (final ChoiceOption<ApprovalPolicy?> choice
            in buildInheritableApprovalPolicyChoices(fallback))
          choice.value,
      ];

      expect(values.toSet(), _selections.toSet());
      expect(values, hasLength(_selections.length));
    }
  });

  test('test_build_inheritable_approval_policy_choices_property_fallback_'
      'title_is_unique', () {
    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      final List<String> titles = <String>[
        for (final ChoiceOption<ApprovalPolicy?> choice
            in buildInheritableApprovalPolicyChoices(fallback))
          choice.title,
      ];

      expect(titles.toSet(), hasLength(titles.length));
    }
  });

  test('test_approval_policy_field_constructor_property_keeps_every_'
      'field', () {
    final Random random = seededRandom(111401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _FieldProbe probe = _FieldProbe(random);
      final Key key = ValueKey<int>(random.nextInt(_largestKeyNumber));

      final ApprovalPolicyField field = ApprovalPolicyField(
        fallback: probe.fallback,
        selected: probe.selected,
        onChanged: probe.changes.add,
        key: key,
      );

      expect(field.fallback, probe.fallback);
      expect(field.selected, probe.selected);
      expect(field.key, key);
    }
  });

  test('test_approval_policy_field_constructor_property_reports_through_'
      'the_given_callback', () {
    final Random random = seededRandom(111402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _FieldProbe probe = _FieldProbe(random);
      final ApprovalPolicy? reported = pickOne(random, _selections);

      probe.build().onChanged(reported);

      expect(probe.changes, <ApprovalPolicy?>[reported]);
    }
  });

  test('test_approval_policy_field_constructor_property_changes_'
      'nothing_by_itself', () {
    final Random random = seededRandom(111403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final _FieldProbe probe = _FieldProbe(random);

      probe.build();

      expect(probe.changes, isEmpty);
    }
  });

  testWidgets('test_approval_policy_field_build_property_shows_every_'
      'choice_at_any_width', (WidgetTester tester) async {
    final Random random = seededRandom(111404);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _FieldProbe probe = await _pumpField(tester, random);

      expect(tester.takeException(), isNull);
      expect(find.text(approvalPolicyLabel), findsOneWidget);
      for (final ChoiceOption<ApprovalPolicy?> choice
          in buildInheritableApprovalPolicyChoices(probe.fallback)) {
        expect(find.text(choice.title), findsOneWidget);
        expect(find.text(choice.detail), findsOneWidget);
      }
    }
  });

  testWidgets('test_approval_policy_field_build_property_marks_the_'
      'selected_choice', (WidgetTester tester) async {
    final Random random = seededRandom(111405);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _FieldProbe probe = await _pumpField(tester, random);

      final ChoiceListField<ApprovalPolicy?> list = tester
          .widget<ChoiceListField<ApprovalPolicy?>>(
            find.byType(ChoiceListField<ApprovalPolicy?>),
          );

      expect(list.selected, probe.selected);
      expect(probe.changes, isEmpty);
    }
  });

  testWidgets('test_approval_policy_field_build_property_each_tap_reports_'
      'its_choice', (WidgetTester tester) async {
    final Random random = seededRandom(111406);

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final _FieldProbe probe = await _pumpField(tester, random);
      final ChoiceOption<ApprovalPolicy?> tapped = pickOne(
        random,
        buildInheritableApprovalPolicyChoices(probe.fallback),
      );

      await tapVisible(tester, find.text(tapped.title));
      await tester.pump();

      expect(probe.changes, <ApprovalPolicy?>[tapped.value]);
    }
  });
}
