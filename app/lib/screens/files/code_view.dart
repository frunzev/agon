import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/screens/files/syntax_highlighting.dart';
import 'package:agent_orchestration/screens/files/syntax_languages.dart';
import 'package:agent_orchestration/screens/files/text_lines.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/widgets/code_block.dart';

const TextStyle _lineNumberStyle = TextStyle(color: AppColors.inkMuted);
const TextStyle _keywordStyle = TextStyle(color: AppColors.action);
const TextStyle _stringStyle = TextStyle(color: AppColors.attention);
const TextStyle _functionStyle = TextStyle(fontWeight: FontWeight.w700);

class CodeView extends StatelessWidget {
  const CodeView({required this.text, required this.language, super.key});

  final String text;
  final SyntaxLanguage? language;

  @override
  Widget build(BuildContext context) {
    final List<String> lines = splitTextLines(text);
    final List<List<InlineSpan>> spansByLine = _buildSpans(lines);
    final int numberDigitCount = '${lines.length}'.length;

    return CodePanel(
      lines: <Widget>[
        for (int index = 0; index < lines.length; index += 1)
          _buildLine(
            '${index + 1}'.padLeft(numberDigitCount),
            spansByLine[index],
          ),
      ],
    );
  }

  Widget _buildLine(String lineNumberText, List<InlineSpan> spans) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
      child: Row(
        children: <Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: AppSpacing.space6),
            child: Text(
              lineNumberText,
              textAlign: TextAlign.end,
              style: _lineNumberStyle,
            ),
          ),
          const SizedBox(width: AppSpacing.space4),
          Text.rich(TextSpan(children: spans)),
        ],
      ),
    );
  }

  List<List<InlineSpan>> _buildSpans(List<String> lines) {
    final SyntaxLanguage? highlightedLanguage = language;
    if (highlightedLanguage == null) {
      return <List<InlineSpan>>[
        for (final String line in lines) <InlineSpan>[TextSpan(text: line)],
      ];
    }

    return <List<InlineSpan>>[
      for (final List<SyntaxToken> tokens in highlightLines(
        lines,
        highlightedLanguage,
      ))
        <InlineSpan>[
          for (final SyntaxToken token in tokens)
            TextSpan(text: token.text, style: _styleFor(token.kind)),
        ],
    ];
  }

  TextStyle? _styleFor(SyntaxKind kind) {
    return switch (kind) {
      SyntaxKind.keyword => _keywordStyle,
      SyntaxKind.string => _stringStyle,
      SyntaxKind.function => _functionStyle,
      SyntaxKind.plain => null,
    };
  }
}
