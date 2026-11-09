import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/presentation/step_round_text.dart';

const int _mostCountsChecked = 60;

typedef _ToggleLabel = ({
  String functionName,
  String Function(int count) describe,
  String verb,
});

final List<_ToggleLabel> _toggleLabels = <_ToggleLabel>[
  (
    functionName: 'describe_show_earlier_rounds',
    describe: describeShowEarlierRounds,
    verb: 'Show',
  ),
  (
    functionName: 'describe_hide_earlier_rounds',
    describe: describeHideEarlierRounds,
    verb: 'Hide',
  ),
];

void main() {
  for (final _ToggleLabel label in _toggleLabels) {
    test('test_${label.functionName}_property_verb_then_count', () {
      for (int count = 0; count < _mostCountsChecked; count += 1) {
        expect(label.describe(count), startsWith('${label.verb} $count '));
      }
    });

    test('test_${label.functionName}_property_singular_only_for_one', () {
      for (int count = 0; count < _mostCountsChecked; count += 1) {
        final String text = label.describe(count);

        expect(text.endsWith(' earlier round'), count == 1);
        expect(text.endsWith(' earlier rounds'), count != 1);
      }
    });

    test('test_${label.functionName}_property_distinct_counts_differ', () {
      final Set<String> texts = <String>{
        for (int count = 0; count < _mostCountsChecked; count += 1)
          label.describe(count),
      };

      expect(texts, hasLength(_mostCountsChecked));
    });
  }

  test('test_describe_round_count_property_same_count_for_both_verbs', () {
    for (int count = 0; count < _mostCountsChecked; count += 1) {
      final String shown = describeShowEarlierRounds(count);
      final String hidden = describeHideEarlierRounds(count);

      expect(shown.substring('Show'.length), hidden.substring('Hide'.length));
    }
  });

  test('test_describe_round_count_property_count_in_plain_digits', () {
    for (int count = 0; count < _mostCountsChecked; count += 1) {
      final List<String> words = describeShowEarlierRounds(count).split(' ');

      expect(words[1], '$count');
      expect(words.length, 4);
    }
  });

  test('test_describe_round_count_property_boundary_at_one_and_two', () {
    expect(describeShowEarlierRounds(1), 'Show 1 earlier round');
    expect(describeShowEarlierRounds(2), 'Show 2 earlier rounds');
    expect(describeHideEarlierRounds(1), 'Hide 1 earlier round');
    expect(describeHideEarlierRounds(0), 'Hide 0 earlier rounds');
  });
}
