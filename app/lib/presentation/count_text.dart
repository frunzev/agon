const int _digitGroupSize = 3;
const String _digitGroupSeparator = ',';

String _groupDigits(int count) {
  final String digits = count.toString();
  final StringBuffer grouped = StringBuffer();

  for (int index = 0; index < digits.length; index += 1) {
    final int digitsLeft = digits.length - index;
    final bool startsGroup = index > 0 && digitsLeft % _digitGroupSize == 0;
    if (startsGroup) {
      grouped.write(_digitGroupSeparator);
    }
    grouped.write(digits[index]);
  }

  return grouped.toString();
}

String describeCount(
  int count, {
  required String singular,
  required String plural,
}) {
  if (count < 0) {
    throw ArgumentError.value(count, 'count', 'Counts cannot be negative');
  }

  final String noun = count == 1 ? singular : plural;
  return '${_groupDigits(count)} $noun';
}
