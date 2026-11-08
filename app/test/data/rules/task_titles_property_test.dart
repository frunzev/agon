import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/rules/task_titles.dart';

import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';

const String _nodeBlankTitleProblem = 'the task title cannot be empty';

Matcher _describeVerdict({required bool isBlank}) {
  if (isBlank) {
    return throwsStateError;
  }
  return returnsNormally;
}

bool _isBlankAfterNodeTrim(RuleTitleWhiteSpaceTable table, String title) {
  return table.trimByModel(title).isEmpty;
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('test_require_task_title_property_refuses_exactly_the_titles_the_'
      'node_trims_to_nothing', () {
    final Random random = seededRandom(90311);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = table.randomExoticTitle(random);
      final bool isBlank = _isBlankAfterNodeTrim(table, title);

      expect(
        () => requireTaskTitle(title),
        _describeVerdict(isBlank: isBlank),
        reason: '${title.runes}',
      );
    }
  });

  test('test_require_task_title_property_white_space_padding_never_changes_'
      'the_verdict', () {
    final Random random = seededRandom(90312);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String title = table.randomExoticTitle(random);
      final String padded =
          '${table.randomWhiteSpaceRun(random)}$title'
          '${table.randomWhiteSpaceRun(random)}';

      final bool isTitleBlank = _isBlankAfterNodeTrim(table, title);

      expect(
        () => requireTaskTitle(padded),
        _describeVerdict(isBlank: isTitleBlank),
        reason: '${title.runes}',
      );
    }
  });

  test('test_require_task_title_property_refusal_carries_the_node_'
      'problem', () {
    final Random random = seededRandom(90313);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String blankTitle = table.randomWhiteSpaceRun(random);

      expect(
        () => requireTaskTitle(blankTitle),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            _nodeBlankTitleProblem,
          ),
        ),
      );
    }
  });
}
