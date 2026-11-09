import 'package:flutter/widgets.dart';
import 'package:markdown/markdown.dart' as markdown;

import 'package:agent_orchestration/screens/files/markdown_spans.dart';
import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

const String _headerCellTag = 'th';
const EdgeInsets _tableCellPadding = EdgeInsets.symmetric(
  horizontal: AppSpacing.space2,
  vertical: AppSpacing.space1,
);

final markdown.ExtensionSet gitHubMarkdownSyntax = markdown.ExtensionSet(
  <markdown.BlockSyntax>[
    for (final markdown.BlockSyntax syntax
        in markdown.ExtensionSet.gitHubFlavored.blockSyntaxes)
      if (syntax is markdown.TableSyntax)
        const ParagraphFallbackTableSyntax()
      else
        syntax,
  ],
  markdown.ExtensionSet.gitHubFlavored.inlineSyntaxes,
);

final class ParagraphFallbackTableSyntax extends markdown.TableSyntax {
  const ParagraphFallbackTableSyntax();

  @override
  markdown.Node? parse(markdown.BlockParser parser) {
    final markdown.Node? table = super.parse(parser);
    if (table != null) {
      return table;
    }
    return const markdown.ParagraphSyntax().parse(parser);
  }
}

Widget buildMarkdownTable(markdown.Element table) {
  final List<TableRow> rows = <TableRow>[
    for (final markdown.Node section in table.children!)
      for (final markdown.Node row in (section as markdown.Element).children!)
        TableRow(
          children: <Widget>[
            for (final markdown.Node cell
                in (row as markdown.Element).children!)
              _buildTableCell(cell as markdown.Element),
          ],
        ),
  ];

  return Table(
    border: TableBorder.all(color: AppColors.line),
    children: rows,
  );
}

Widget _buildTableCell(markdown.Element cell) {
  final TextStyle style = cell.tag == _headerCellTag
      ? AppTextStyles.bodyBold
      : AppTextStyles.body;

  return Padding(
    padding: _tableCellPadding,
    child: buildMarkdownRichText(
      cell.children ?? const <markdown.Node>[],
      style,
    ),
  );
}
