import 'dart:math';

const int largestDisplayedCount = 9223372036854775807;
const int _largestDigitCount = 18;
const int _decimalBase = 10;

int randomCountOfAnySize(Random random) {
  final int digitCount = 1 + random.nextInt(_largestDigitCount);
  int count = 0;

  for (int i = 0; i < digitCount; i += 1) {
    count = count * _decimalBase + random.nextInt(_decimalBase);
  }

  return count;
}
