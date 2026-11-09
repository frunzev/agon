import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/gallery/gallery_moments.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/library.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/models/scope.dart';
import 'package:agent_orchestration/screens/rules/agents_markdown_preview.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';
import '../../support/rule_title_white_space_table.dart';
import 'agents_markdown_preview_model.dart';

const String _emptyAppText = 'No rules apply to app yet.';

String _randomLinesText(Random random) {
  final int partCount = random.nextInt(5);
  final StringBuffer text = StringBuffer();
  for (int index = 0; index < partCount; index += 1) {
    final List<String> parts = <String>[
      '\n',
      '\r\n',
      '',
      randomHostileText(random),
    ];
    text.write(pickOne(random, parts));
  }
  return text.toString();
}

String _joinAsMarkdown(List<String> codeLines) {
  final List<String> markdownLines = <String>[
    for (final String line in codeLines)
      if (line == blankCodeLine) '' else line,
  ];
  if (markdownLines.isEmpty) {
    return '';
  }
  return '${markdownLines.join('\n')}\n';
}

void main() {
  final RuleTitleWhiteSpaceTable table = readRuleTitleWhiteSpaceTable();

  test('test_split_markdown_lines_property_rebuilds_rendered_markdown', () {
    final Random random = seededRandom(107101);

    for (int i = 0; i < propertyIterations; i += 1) {
      final List<String> modelLines = modelAgentsMarkdownLines(
        rules: randomNearbyRules(random, table),
        table: table,
        workspaceId: shownWorkspaceId,
      );
      final String markdown = _joinAsMarkdown(modelLines);

      final List<CodeBlockLine> lines = splitMarkdownLines(markdown);

      final List<String> shown = readCodeLineTexts(lines);
      expect(shown, modelLines);
      expect(_joinAsMarkdown(shown), markdown);
    }
  });

  test('test_split_markdown_lines_property_lines_are_never_empty', () {
    final Random random = seededRandom(107102);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String text = _randomLinesText(random);

      final List<CodeBlockLine> lines = splitMarkdownLines(text);

      for (final CodeBlockLine line in lines) {
        expect(line.text, isNotEmpty);
        expect(line.text.contains('\n'), isFalse);
        expect(line.change, LineChange.unchanged);
      }
    }
  });

  test('test_split_markdown_lines_property_splits_across_a_break', () {
    final Random random = seededRandom(107103);

    for (int i = 0; i < propertyIterations; i += 1) {
      final String head = random.nextBool()
          ? ''
          : '${_randomLinesText(random)}\n';
      final String tail = _randomLinesText(random);

      final List<CodeBlockLine> joined = splitMarkdownLines(head + tail);

      expect(readCodeLineTexts(joined), <String>[
        ...readCodeLineTexts(splitMarkdownLines(head)),
        ...readCodeLineTexts(splitMarkdownLines(tail)),
      ]);
    }
  });

  testWidgets('test_agents_markdown_preview_build_property_agrees_with_'
      'the_shared_rust_table', (WidgetTester tester) async {
    final Random random = seededRandom(107104);
    final Project project = buildShownProject('app');

    for (final RuleTitleWhiteSpaceCase sharedCase in table.cases) {
      final Rule rule = Rule(
        id: const RuleId('shared'),
        title: sharedCase.title,
        details: sharedCase.details,
        scope: const Scope.everywhere(),
        enabled: true,
        addedAt: galleryNow,
      );
      await pumpPreviewAtRandomWidth(
        tester,
        random,
        rules: <Rule>[rule],
        project: project,
        workspaceId: shownWorkspaceId,
      );

      final List<String> expected = readCodeLineTexts(
        splitMarkdownLines(sharedCase.markdown),
      );
      final Matcher emptyShown = sharedCase.isBlank
          ? findsOneWidget
          : findsNothing;
      expect(readShownCodeLines(tester), expected);
      expect(find.text(_emptyAppText), emptyShown);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('test_agents_markdown_preview_build_property_skips_blank_'
      'titles_beside_kept_rules', (WidgetTester tester) async {
    final Random random = seededRandom(107110);
    final Project project = buildShownProject('app');

    for (int i = 0; i < widgetPropertyIterations; i += 1) {
      final List<Rule> rules = <Rule>[
        for (final RuleTitleWhiteSpaceCase sharedCase in table.cases)
          if (random.nextBool())
            Rule(
              id: const RuleId('shared'),
              title: sharedCase.title,
              details: sharedCase.details,
              scope: const Scope.everywhere(),
              enabled: true,
              addedAt: galleryNow,
            ),
      ];
      await pumpPreviewAtRandomWidth(
        tester,
        random,
        rules: rules,
        project: project,
        workspaceId: shownWorkspaceId,
      );

      final List<String> expected = modelAgentsMarkdownLines(
        rules: rules,
        table: table,
        workspaceId: shownWorkspaceId,
      );
      expect(readShownCodeLines(tester), expected);
    }
  });
}
