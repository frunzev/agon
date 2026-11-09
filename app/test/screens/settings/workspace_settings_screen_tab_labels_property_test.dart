import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/presentation/approval_policy_text.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/widgets/tab_strip.dart';

import '../../support/random_inputs.dart';
import 'support/settings_screen_harness.dart';

const List<String> _designTabLabels = <String>[
  'Server',
  'Commands and pushes',
  "Files agents can't read",
  'Audit log',
];
const String _protectedFilesTitle = "Files agents can't read";

void _registerSettingsTabProperties(SettingsTab tab, int position) {
  final String prefix = 'test_settings_tab_${tab.name}';

  test('${prefix}_constructor_property_keeps_the_design_label', () {
    expect(tab.label, _designTabLabels[position]);
  });

  test('${prefix}_constructor_property_name_and_index_round_trip', () {
    expect(SettingsTab.values.byName(tab.name), tab);
    expect(SettingsTab.values[tab.index], tab);
    expect(tab.index, position);
  });

  test('${prefix}_constructor_property_listed_exactly_once', () {
    final Iterable<SettingsTab> same = SettingsTab.values.where(
      (SettingsTab other) => other == tab,
    );
    expect(same.length, 1);
  });

  test('${prefix}_label_property_reads_as_plain_words', () {
    expect(tab.label, isNot(contains('_')));
    expect(tab.label[0], tab.label[0].toUpperCase());
    expect(tab.label, isNot(contains('  ')));
  });

  testWidgets('${prefix}_label_property_shown_at_its_index_in_the_strip', (
    WidgetTester tester,
  ) async {
    await pumpSettingsScreen(
      tester,
      size: randomWindowSize(seededRandom(311111 + position)),
      dependencies: buildGalleryDependencies(),
    );

    final TabStrip strip = tester.widget<TabStrip>(find.byType(TabStrip));
    expect(strip.labels[tab.index], tab.label);
  });

  test('${prefix}_label_property_is_unique_and_trimmed', () {
    final Iterable<SettingsTab> sameLabel = SettingsTab.values.where(
      (SettingsTab other) => other.label == tab.label,
    );
    expect(sameLabel, <SettingsTab>[tab]);
    expect(tab.label.trim(), tab.label);
    expect(tab.label, isNotEmpty);
  });
}

void main() {
  for (int position = 0; position < SettingsTab.values.length; position += 1) {
    _registerSettingsTabProperties(SettingsTab.values[position], position);
  }

  test('test_settings_tab_label_property_tab_labels_match_section_titles', () {
    expect(SettingsTab.commandsAndPushes.label, approvalPolicyLabel);
    expect(SettingsTab.protectedFiles.label, _protectedFilesTitle);
  });
}
