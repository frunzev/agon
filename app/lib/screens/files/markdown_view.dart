import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as markdown;

import 'package:agent_orchestration/screens/files/markdown_spans.dart';
import 'package:agent_orchestration/screens/files/markdown_tables.dart';
import 'package:agent_orchestration/screens/files/text_lines.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';
import 'package:agent_orchestration/widgets/code_block.dart';
import 'package:agent_orchestration/widgets/gaps.dart';

const String _bulletMarker = '•';
const String _uncheckedMarker = '☐';
const String _checkedMarker = '☑';
const String _space = ' ';
const String _listStartAttribute = 'start';
const String _checkedAttribute = 'checked';
const int _firstListNumber = 1;
const int _topIndentDepth = 0;
const int _deepestIndentDepth = 6;
const String _titleTag = 'h1';
const Set<String> _subheadingTags = <String>{'h2', 'h3', 'h4', 'h5', 'h6'};
const String _paragraphTag = 'p';
const String _orderedListTag = 'ol';
const Set<String> _listTags = <String>{'ul', _orderedListTag};
const String _codeBlockTag = 'pre';
const String _quoteTag = 'blockquote';
const String _ruleTag = 'hr';
const String _tableTag = 'table';
const String _footnotesTag = 'section';
const String _checkboxTag = 'input';
const Set<String> _blockTags = <String>{
  _titleTag,
  ..._subheadingTags,
  _paragraphTag,
  ..._listTags,
  _codeBlockTag,
  _quoteTag,
  _ruleTag,
  _tableTag,
  _footnotesTag,
};

class MarkdownView extends StatelessWidget {
  const MarkdownView({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final List<markdown.Node> nodes = markdown.Document(
      encodeHtml: false,
      extensionSet: gitHubMarkdownSyntax,
    ).parse(text);

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AppSizes.measure),
        child: _buildFlow(nodes, _topIndentDepth),
      ),
    );
  }
}

Widget _buildFlow(List<markdown.Node> nodes, int indentDepth) {
  final List<Widget> blocks = <Widget>[];
  final List<markdown.Node> inlineRun = <markdown.Node>[];

  for (final markdown.Node node in nodes) {
    if (_isBlock(node)) {
      _addParagraph(inlineRun, blocks);
      blocks.add(_buildBlock(node as markdown.Element, indentDepth));
    } else {
      inlineRun.add(node);
    }
  }
  _addParagraph(inlineRun, blocks);

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: spaceVertically(blocks, AppSpacing.space3),
  );
}

bool _isBlock(markdown.Node node) {
  return node is markdown.Element && _blockTags.contains(node.tag);
}

void _addParagraph(List<markdown.Node> inlineRun, List<Widget> blocks) {
  if (inlineRun.isEmpty) {
    return;
  }
  blocks.add(buildMarkdownRichText(inlineRun, AppTextStyles.body));
  inlineRun.clear();
}

Widget _buildBlock(markdown.Element element, int indentDepth) {
  final String tag = element.tag;
  final List<markdown.Node> children =
      element.children ?? const <markdown.Node>[];
  final bool canIndent = indentDepth < _deepestIndentDepth;

  if (tag == _titleTag) {
    return Semantics(
      header: true,
      child: buildMarkdownRichText(children, AppTextStyles.heading),
    );
  }
  if (_subheadingTags.contains(tag)) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.space3),
      child: Semantics(
        header: true,
        child: buildMarkdownRichText(children, AppTextStyles.bodyBold),
      ),
    );
  }
  if (tag == _paragraphTag) {
    return buildMarkdownRichText(children, AppTextStyles.body);
  }
  if (_listTags.contains(tag)) {
    return _buildList(element, indentDepth);
  }
  if (tag == _codeBlockTag) {
    return _buildCodeBlock(element.textContent);
  }
  if (tag == _quoteTag && canIndent) {
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.space5),
      child: _buildFlow(children, indentDepth + 1),
    );
  }
  if (tag == _quoteTag || tag == _footnotesTag) {
    return _buildFlow(children, indentDepth);
  }
  if (tag == _ruleTag) {
    return Container(height: AppBorders.thin, color: AppColors.line);
  }
  if (tag == _tableTag) {
    return buildMarkdownTable(element);
  }
  return Text(element.textContent);
}

Widget _buildCodeBlock(String code) {
  return CodePanel(
    lines: <Widget>[
      for (final String line in splitTextLines(code))
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.space4),
          child: Text(line),
        ),
    ],
  );
}

Widget _buildList(markdown.Element list, int indentDepth) {
  final bool isOrdered = list.tag == _orderedListTag;
  final int firstNumber =
      int.tryParse(list.attributes[_listStartAttribute] ?? '') ??
      _firstListNumber;
  final List<markdown.Node> items = list.children ?? const <markdown.Node>[];
  final List<Widget> rows = <Widget>[];

  for (int index = 0; index < items.length; index += 1) {
    final markdown.Node item = items[index];
    final List<markdown.Node> content = item is markdown.Element
        ? item.children ?? const <markdown.Node>[]
        : <markdown.Node>[item];
    final String countedMarker = isOrdered
        ? '${firstNumber + index}.'
        : _bulletMarker;
    final String marker = _findTaskMarker(content) ?? countedMarker;
    rows.add(
      _buildListRow(
        marker: marker,
        content: content,
        indentDepth: indentDepth,
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: spaceVertically(rows, AppSpacing.space1),
  );
}

String? _findTaskMarker(List<markdown.Node> itemContent) {
  markdown.Node? first = itemContent.firstOrNull;
  if (first is markdown.Element && first.tag == _paragraphTag) {
    first = first.children?.firstOrNull;
  }
  if (first is! markdown.Element || first.tag != _checkboxTag) {
    return null;
  }
  if (first.attributes.containsKey(_checkedAttribute)) {
    return _checkedMarker;
  }
  return _uncheckedMarker;
}

Widget _buildListRow({
  required String marker,
  required List<markdown.Node> content,
  required int indentDepth,
}) {
  if (indentDepth >= _deepestIndentDepth) {
    return _buildFlow(_placeMarkerInline(marker, content), indentDepth);
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: AppSpacing.space5),
        child: Padding(
          padding: const EdgeInsets.only(right: AppSpacing.space1),
          child: Text(marker),
        ),
      ),
      Expanded(child: _buildFlow(content, indentDepth + 1)),
    ],
  );
}

List<markdown.Node> _placeMarkerInline(
  String marker,
  List<markdown.Node> content,
) {
  final markdown.Text markerText = markdown.Text('$marker$_space');
  final markdown.Node? first = content.firstOrNull;
  if (first is! markdown.Element || first.tag != _paragraphTag) {
    return <markdown.Node>[markerText, ...content];
  }

  final markdown.Element markedParagraph = markdown.Element(
    _paragraphTag,
    <markdown.Node>[markerText, ...?first.children],
  );
  return <markdown.Node>[markedParagraph, ...content.skip(1)];
}
