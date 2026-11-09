import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:markdown/markdown.dart' as markdown;

import 'package:agent_orchestration/screens/files/markdown_tables.dart';

import '../../support/random_inputs.dart';

List<Type> _listSyntaxTypes(List<markdown.BlockSyntax> syntaxes) {
  return <Type>[
    for (final markdown.BlockSyntax syntax in syntaxes) syntax.runtimeType,
  ];
}

void main() {
  test('test_paragraph_fallback_table_syntax_new_property_is_a_table_'
      'syntax', () {
    final Random random = seededRandom(106201);

    for (int i = 0; i < propertyIterations; i += 1) {
      final markdown.BlockSyntax syntax = pickOne(
        random,
        <markdown.BlockSyntax>[
          const ParagraphFallbackTableSyntax(),
          ...gitHubMarkdownSyntax.blockSyntaxes,
        ],
      );

      final bool isFallback = syntax is ParagraphFallbackTableSyntax;
      expect(syntax is markdown.TableSyntax, isFallback);
    }
  });

  test('test_paragraph_fallback_table_syntax_new_property_replaces_only_'
      'the_table_syntax', () {
    final Random random = seededRandom(106202);
    final List<Type> gitHubTypes = _listSyntaxTypes(
      markdown.ExtensionSet.gitHubFlavored.blockSyntaxes,
    );
    final List<Type> shownTypes = _listSyntaxTypes(
      gitHubMarkdownSyntax.blockSyntaxes,
    );

    for (int i = 0; i < propertyIterations; i += 1) {
      final int index = random.nextInt(gitHubTypes.length);

      final Type expected = gitHubTypes[index] == markdown.TableSyntax
          ? ParagraphFallbackTableSyntax
          : gitHubTypes[index];
      expect(shownTypes[index], expected);
      expect(shownTypes, hasLength(gitHubTypes.length));
    }
  });

  test('test_paragraph_fallback_table_syntax_new_property_keeps_every_'
      'inline_syntax', () {
    final Random random = seededRandom(106203);
    final List<markdown.InlineSyntax> gitHubInline =
        markdown.ExtensionSet.gitHubFlavored.inlineSyntaxes;

    for (int i = 0; i < propertyIterations; i += 1) {
      final int index = random.nextInt(gitHubInline.length);

      expect(
        gitHubMarkdownSyntax.inlineSyntaxes[index].runtimeType,
        gitHubInline[index].runtimeType,
      );
      expect(
        identical(
          const ParagraphFallbackTableSyntax(),
          const ParagraphFallbackTableSyntax(),
        ),
        isTrue,
      );
    }
  });
}
