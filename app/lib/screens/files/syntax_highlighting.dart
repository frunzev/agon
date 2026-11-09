import 'package:agent_orchestration/screens/files/syntax_languages.dart';

enum SyntaxKind { plain, keyword, string, function }

final class SyntaxToken {
  const SyntaxToken(this.text, this.kind);

  final String text;
  final SyntaxKind kind;
}

final class _OpenSpan {
  const _OpenSpan({
    required this.opening,
    required this.closing,
    required this.kind,
  });

  final String opening;
  final String closing;
  final SyntaxKind kind;
}

typedef _HighlightedLine = ({List<SyntaxToken> tokens, _OpenSpan? endSpan});

const String _escapeCharacter = r'\';
const String _callOpening = '(';
const String _slashLineComment = '//';
const String _hashLineComment = '#';
const String _blockCommentOpening = '/*';
const String _blockCommentClosing = '*/';
const _OpenSpan _blockComment = _OpenSpan(
  opening: _blockCommentOpening,
  closing: _blockCommentClosing,
  kind: SyntaxKind.plain,
);
final RegExp _identifierStart = RegExp(r'[\p{L}_$]', unicode: true);
final RegExp _identifierPart = RegExp(r'[\p{L}\p{M}\p{N}_$]', unicode: true);
final RegExp _whiteSpace = RegExp(r'\s');

List<SyntaxToken> highlightLine(String line, SyntaxLanguage language) {
  return highlightLines(<String>[line], language).single;
}

List<List<SyntaxToken>> highlightLines(
  List<String> lines,
  SyntaxLanguage language,
) {
  final List<List<SyntaxToken>> highlightedLines = <List<SyntaxToken>>[];
  _OpenSpan? openSpan;

  for (final String line in lines) {
    final _HighlightedLine highlighted = _highlightOneLine(
      line,
      language,
      openSpan,
    );
    highlightedLines.add(highlighted.tokens);
    openSpan = highlighted.endSpan;
  }

  return List<List<SyntaxToken>>.unmodifiable(highlightedLines);
}

_HighlightedLine _highlightOneLine(
  String line,
  SyntaxLanguage language,
  _OpenSpan? startSpan,
) {
  final List<SyntaxToken> tokens = <SyntaxToken>[];
  final StringBuffer plainText = StringBuffer();
  _OpenSpan? openSpan = startSpan;
  int index = 0;

  while (index < line.length) {
    final String character = line[index];
    final _OpenSpan? span = openSpan ?? _findOpenedSpan(line, index, language);

    if (span != null) {
      final int searchStart = openSpan == null
          ? index + span.opening.length
          : index;
      final int? closedEnd = _findSpanEnd(line, searchStart, span);
      final int end = closedEnd ?? line.length;
      _addText(line.substring(index, end), span.kind, plainText, tokens);
      openSpan = closedEnd == null ? span : null;
      index = end;
    } else if (_startsLineComment(line, index, language.comments)) {
      plainText.write(line.substring(index));
      index = line.length;
    } else if (language.stringDelimiters.contains(character)) {
      final int end = _findStringEnd(line, index);
      _addText(
        line.substring(index, end),
        SyntaxKind.string,
        plainText,
        tokens,
      );
      index = end;
    } else if (_identifierStart.hasMatch(character)) {
      final int end = _findIdentifierEnd(line, index);
      final String word = line.substring(index, end);
      final SyntaxKind kind = _classifyWord(word, line, end, language);
      _addText(word, kind, plainText, tokens);
      index = end;
    } else {
      plainText.write(character);
      index += 1;
    }
  }

  _addPlainText(plainText, tokens);
  return (tokens: List<SyntaxToken>.unmodifiable(tokens), endSpan: openSpan);
}

_OpenSpan? _findOpenedSpan(String line, int index, SyntaxLanguage language) {
  if (_startsBlockComment(line, index, language.comments)) {
    return _blockComment;
  }
  for (final String delimiter in language.multiLineStringDelimiters) {
    if (line.startsWith(delimiter, index)) {
      return _OpenSpan(
        opening: delimiter,
        closing: delimiter,
        kind: SyntaxKind.string,
      );
    }
  }
  return null;
}

int? _findSpanEnd(String line, int start, _OpenSpan span) {
  if (span.kind == SyntaxKind.string) {
    return _findStringClosingEnd(line, start, span.closing);
  }
  return _findCommentClosingEnd(line, start, span.closing);
}

int? _findCommentClosingEnd(String line, int start, String closing) {
  final int closingStart = line.indexOf(closing, start);
  if (closingStart < 0) {
    return null;
  }
  return closingStart + closing.length;
}

bool _startsBlockComment(String line, int index, CommentStyle comments) {
  final bool hasBlockComments = comments == CommentStyle.slashLinesAndBlocks;
  return hasBlockComments && line.startsWith(_blockCommentOpening, index);
}

bool _startsLineComment(String line, int index, CommentStyle comments) {
  switch (comments) {
    case CommentStyle.none:
      return false;
    case CommentStyle.slashLinesAndBlocks:
      return line.startsWith(_slashLineComment, index);
    case CommentStyle.hashAtWordStart:
      final bool isWordStart =
          index == 0 || _whiteSpace.hasMatch(line[index - 1]);
      return isWordStart && line.startsWith(_hashLineComment, index);
  }
}

int _findStringEnd(String line, int start) {
  final String delimiter = line[start];
  final int? closedEnd = _findStringClosingEnd(line, start + 1, delimiter);
  return closedEnd ?? line.length;
}

int? _findStringClosingEnd(String line, int start, String closing) {
  int index = start;

  while (index < line.length) {
    if (line[index] == _escapeCharacter) {
      index += 2;
    } else if (line.startsWith(closing, index)) {
      return index + closing.length;
    } else {
      index += 1;
    }
  }

  return null;
}

int _findIdentifierEnd(String line, int start) {
  int index = start + 1;

  while (index < line.length && _identifierPart.hasMatch(line[index])) {
    index += 1;
  }

  return index;
}

SyntaxKind _classifyWord(
  String word,
  String line,
  int end,
  SyntaxLanguage language,
) {
  if (language.keywords.contains(word)) {
    return SyntaxKind.keyword;
  }
  final bool isCalled = end < line.length && line[end] == _callOpening;
  if (isCalled) {
    return SyntaxKind.function;
  }
  return SyntaxKind.plain;
}

void _addText(
  String text,
  SyntaxKind kind,
  StringBuffer plainText,
  List<SyntaxToken> tokens,
) {
  if (kind == SyntaxKind.plain) {
    plainText.write(text);
    return;
  }
  _addPlainText(plainText, tokens);
  tokens.add(SyntaxToken(text, kind));
}

void _addPlainText(StringBuffer plainText, List<SyntaxToken> tokens) {
  if (plainText.isEmpty) {
    return;
  }
  tokens.add(SyntaxToken(plainText.toString(), SyntaxKind.plain));
  plainText.clear();
}
