import 'dart:math';

int compareCodePoints(String first, String second) {
  final List<int> firstCodePoints = first.runes.toList();
  final List<int> secondCodePoints = second.runes.toList();
  final int sharedLength = min(
    firstCodePoints.length,
    secondCodePoints.length,
  );

  for (int i = 0; i < sharedLength; i += 1) {
    final int difference = firstCodePoints[i] - secondCodePoints[i];
    if (difference != 0) {
      return difference;
    }
  }
  return firstCodePoints.length - secondCodePoints.length;
}
