import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as markdown;

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const String _softLineBreak = '\n';
const String _space = ' ';
const String _inlineCodeTag = 'code';
const String _emphasisTag = 'em';
const String _strongTag = 'strong';
const String _strikethroughTag = 'del';
const String _linkTag = 'a';
const String _lineBreakTag = 'br';
const String _imageTag = 'img';
const String _imageAltAttribute = 'alt';
const TextStyle _inlineCodeStyle = TextStyle(
  fontFamily: AppFontFamilies.monospace,
  fontFamilyFallback: AppFontFamilies.monospaceFallback,
  fontSize: AppFontSizes.small,
  backgroundColor: AppColors.raised,
);
const TextStyle _emphasisStyle = TextStyle(fontStyle: FontStyle.italic);
const TextStyle _strongStyle = TextStyle(fontWeight: FontWeight.w700);
const TextStyle _strikethroughStyle = TextStyle(
  decoration: TextDecoration.lineThrough,
);
const TextStyle _linkStyle = TextStyle(decoration: TextDecoration.underline);

Text buildMarkdownRichText(List<markdown.Node> nodes, TextStyle style) {
  return Text.rich(
    TextSpan(
      children: <InlineSpan>[
        for (final markdown.Node node in nodes) _buildSpan(node),
      ],
    ),
    style: style,
  );
}

InlineSpan _buildSpan(markdown.Node node) {
  if (node is! markdown.Element) {
    return TextSpan(text: node.textContent.replaceAll(_softLineBreak, _space));
  }

  final List<InlineSpan> children = <InlineSpan>[
    for (final markdown.Node child in node.children ?? const <markdown.Node>[])
      _buildSpan(child),
  ];
  switch (node.tag) {
    case _inlineCodeTag:
      return TextSpan(text: node.textContent, style: _inlineCodeStyle);
    case _emphasisTag:
      return TextSpan(children: children, style: _emphasisStyle);
    case _strongTag:
      return TextSpan(children: children, style: _strongStyle);
    case _strikethroughTag:
      return TextSpan(children: children, style: _strikethroughStyle);
    case _linkTag:
      return TextSpan(children: children, style: _linkStyle);
    case _lineBreakTag:
      return const TextSpan(text: _softLineBreak);
    case _imageTag:
      return TextSpan(text: node.attributes[_imageAltAttribute]);
    default:
      return TextSpan(children: children);
  }
}
