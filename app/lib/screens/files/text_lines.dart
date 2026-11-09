final RegExp _lineBreak = RegExp('\r\n|[\r\n\u0085\u2028\u2029]');
const String _verticalTab = '\u000B';
const String _formFeed = '\u000C';
const String _verticalTabMark = '\u240B';
const String _formFeedMark = '\u240C';

List<String> splitTextLines(String text) {
  if (text.isEmpty) {
    return const <String>[];
  }

  final String textWithTabMarks = text.replaceAll(
    _verticalTab,
    _verticalTabMark,
  );
  final String shownText = textWithTabMarks.replaceAll(
    _formFeed,
    _formFeedMark,
  );
  final List<String> lines = shownText.split(_lineBreak);
  final bool endsWithLineBreak = lines.length > 1 && lines.last.isEmpty;
  if (endsWithLineBreak) {
    lines.removeLast();
  }

  return List<String>.unmodifiable(lines);
}
