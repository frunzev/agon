import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes/fake_workflow_checks.dart';

import '../../support/people_facing_refusal_matchers.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';


void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('test_require_workflow_description_property_refuses_exactly_what_the_'
      'node_trims_to_nothing', () {
    final Random random = seededRandom(91001);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String description = table.randomExoticTitle(random);
      final String trimmedByNode = table.trimByModel(description);

      if (trimmedByNode.isEmpty) {
        expect(
          () => requireWorkflowDescription(description),
          throwsPeopleFacingRefusal,
          reason: '${description.runes}',
        );
      } else {
        expect(
          requireWorkflowDescription(description),
          trimmedByNode,
          reason: '${description.runes}',
        );
      }
    }
  });

  test('test_require_workflow_description_property_hands_back_the_node_'
      'trimmed_words', () {
    final Random random = seededRandom(91002);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String description =
          '${table.randomWhiteSpaceRun(random)}D'
          '${table.randomExoticTitle(random)}'
          '${table.randomWhiteSpaceRun(random)}';

      expect(
        requireWorkflowDescription(description),
        table.trimByModel(description),
        reason: '${description.runes}',
      );
    }
  });

  test('test_require_workflow_description_property_is_idempotent', () {
    final Random random = seededRandom(91003);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String description = '${table.randomExoticTitle(random)}x';

      final String once = requireWorkflowDescription(description);

      expect(requireWorkflowDescription(once), once);
    }
  });

  test('test_require_change_request_property_matches_the_node_white_space_'
      'model', () {
    final Random random = seededRandom(91004);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String request = table.randomExoticTitle(random);
      final String trimmedByNode = table.trimByModel(request);

      if (trimmedByNode.isEmpty) {
        expect(
          () => requireChangeRequest(request),
          throwsPeopleFacingRefusal,
          reason: '${request.runes}',
        );
      } else {
        expect(
          requireChangeRequest(request),
          trimmedByNode,
          reason: '${request.runes}',
        );
      }
    }
  });
}
