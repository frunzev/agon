import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/approval.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';

import '../support/random_inputs.dart';
import 'support/plain_shown_text.dart';

const String _settingsDesignPage = 'settings-commands';
const String _taskFormDesignPage = 'task-new';
const String _projectFormDesignPage = 'project-new';
const String _commandWord = 'command';
const String _pushWord = 'push';

const Map<ApprovalPolicyFallback, String> _fallbackDesignPages =
    <ApprovalPolicyFallback, String>{
      ApprovalPolicyFallback.project: _taskFormDesignPage,
      ApprovalPolicyFallback.workspace: _projectFormDesignPage,
    };

void main() {
  test('test_describe_approval_policy_title_property_is_a_plain_label_'
      'unique_per_policy', () {
    final Random random = seededRandom(91401);
    final Set<String> titles = <String>{};

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicy policy = pickOne(random, ApprovalPolicy.values);

      final String title = describeApprovalPolicyTitle(policy);

      expectPlainLabel(title);
      expect(describeApprovalPolicyTitle(policy), title);
      titles.add(title);
    }

    expect(titles.length, ApprovalPolicy.values.length);
  });

  test('test_describe_approval_policy_title_property_never_repeats_a_'
      'fallback_title', () {
    final List<String> pickerTitles = <String>[
      for (final ApprovalPolicy policy in ApprovalPolicy.values)
        describeApprovalPolicyTitle(policy),
      for (final ApprovalPolicyFallback fallback
          in ApprovalPolicyFallback.values)
        fallback.title,
    ];

    expect(pickerTitles.toSet().length, pickerTitles.length);
  });

  test('test_describe_approval_policy_title_property_matches_the_design', () {
    final String settingsText = readDesignPageText(_settingsDesignPage);
    final String taskFormText = readDesignPageText(_taskFormDesignPage);

    for (final ApprovalPolicy policy in ApprovalPolicy.values) {
      final String title = describeApprovalPolicyTitle(policy);

      expect(settingsText, contains(title));
      expect(taskFormText, contains(title));
    }
  });

  test('test_describe_approval_policy_detail_property_is_plain_sentences_'
      'apart_from_the_title', () {
    final Random random = seededRandom(91402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicy policy = pickOne(random, ApprovalPolicy.values);

      final String detail = describeApprovalPolicyDetail(policy);

      expectPlainSentences(detail);
      expect(detail, isNot(describeApprovalPolicyTitle(policy)));
      expect(describeApprovalPolicyDetail(policy), detail);
    }
  });

  test('test_describe_approval_policy_detail_property_follows_its_title_in_'
      'the_design', () {
    final String settingsText = readDesignPageText(_settingsDesignPage);
    final String taskFormText = readDesignPageText(_taskFormDesignPage);

    for (final ApprovalPolicy policy in ApprovalPolicy.values) {
      final String title = describeApprovalPolicyTitle(policy);
      final String detail = describeApprovalPolicyDetail(policy);

      expect(settingsText, contains('$title $detail'));
      expect(taskFormText, contains('$title $detail'));
    }
  });

  test('test_describe_approval_policy_detail_property_speaks_of_commands_'
      'and_pushes', () {
    for (final ApprovalPolicy policy in ApprovalPolicy.values) {
      final String detail = describeApprovalPolicyDetail(policy);
      final String lowerCaseDetail = detail.toLowerCase();

      expect(lowerCaseDetail, contains(_commandWord));
      expect(lowerCaseDetail, contains(_pushWord));
    }
  });

  test('test_approval_policy_choice_order_property_follows_the_design_'
      'order', () {
    final String settingsText = readDesignPageText(_settingsDesignPage);
    int previousPosition = -1;

    for (final ApprovalPolicy policy in approvalPolicyChoiceOrder) {
      final String title = describeApprovalPolicyTitle(policy);

      final int position = settingsText.indexOf(title, previousPosition + 1);

      expect(position, greaterThan(previousPosition), reason: title);
      previousPosition = position;
    }
  });

  test('test_approval_policy_choice_order_property_cannot_be_changed', () {
    final Random random = seededRandom(91403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicy policy = pickOne(random, ApprovalPolicy.values);

      expect(
        () => approvalPolicyChoiceOrder.add(policy),
        throwsUnsupportedError,
      );
      expect(approvalPolicyChoiceOrder.length, ApprovalPolicy.values.length);
    }
  });

  test('test_approval_policy_choice_order_property_shows_each_title_once', () {
    final List<String> titles = <String>[
      for (final ApprovalPolicy policy in approvalPolicyChoiceOrder)
        describeApprovalPolicyTitle(policy),
    ];

    expect(titles.toSet().length, titles.length);
    expect(titles.length, ApprovalPolicy.values.length);
  });

  test('test_approval_policy_fallback_constructor_property_names_survive_a_'
      'round_trip', () {
    final Random random = seededRandom(91404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final ApprovalPolicyFallback fallback = pickOne(
        random,
        ApprovalPolicyFallback.values,
      );

      final ApprovalPolicyFallback restored = ApprovalPolicyFallback.values
          .byName(fallback.name);

      expect(identical(restored, fallback), isTrue);
    }
  });

  test('test_approval_policy_fallback_constructor_property_keeps_distinct_'
      'texts', () {
    final Set<String> titles = <String>{};
    final Set<String> details = <String>{};

    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      expect(fallback.title, isNot(fallback.detail));
      titles.add(fallback.title);
      details.add(fallback.detail);
    }

    expect(titles.length, ApprovalPolicyFallback.values.length);
    expect(details.length, ApprovalPolicyFallback.values.length);
  });

  test('test_approval_policy_fallback_constructor_property_title_names_its_'
      'level', () {
    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      expect(fallback.title, endsWith(' ${fallback.name}'));
    }
  });

  test('test_approval_policy_fallback_title_property_is_a_plain_label', () {
    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      expectPlainLabel(fallback.title);
    }
  });

  test('test_approval_policy_fallback_title_property_matches_the_design', () {
    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      final String designPage = _fallbackDesignPages[fallback]!;

      final String designText = readDesignPageText(designPage);

      expect(designText, contains(fallback.title));
    }
  });

  test('test_approval_policy_fallback_title_property_never_names_a_'
      'policy', () {
    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      for (final ApprovalPolicy policy in ApprovalPolicy.values) {
        final String policyTitle = describeApprovalPolicyTitle(policy);

        expect(fallback.title, isNot(contains(policyTitle)));
      }
    }
  });

  test('test_approval_policy_fallback_detail_property_is_plain_sentences', () {
    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      expectPlainSentences(fallback.detail);
    }
  });

  test('test_approval_policy_fallback_detail_property_follows_its_title_in_'
      'the_design', () {
    for (final ApprovalPolicyFallback fallback
        in ApprovalPolicyFallback.values) {
      final String designPage = _fallbackDesignPages[fallback]!;

      final String designText = readDesignPageText(designPage);

      expect(designText, contains('${fallback.title} ${fallback.detail}'));
    }
  });

  test('test_approval_policy_fallback_detail_property_names_every_level_it_'
      'falls_back_to', () {
    const List<ApprovalPolicyFallback> levels = ApprovalPolicyFallback.values;

    for (int i = 0; i < levels.length; i += 1) {
      final String detail = levels[i].detail;

      for (int j = i; j < levels.length; j += 1) {
        expect(detail, contains(levels[j].name), reason: detail);
      }
    }
  });
}
