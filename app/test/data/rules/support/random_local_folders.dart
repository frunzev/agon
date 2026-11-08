import 'dart:math';

import '../../../support/random_inputs.dart';

const String _deviceIdCharacters = 'abcdefghijklmnopqrstuvwxyz0123456789-';
const int _largestDeviceIdLength = 32;
const int _largestPartCount = 4;
const List<String> folderParts = <String>[
  'projects',
  'acme',
  'My Projects',
  'a.b',
  '...',
  '.hidden',
  'x_1',
  'café',
  'a:b',
  '\uFEFFodd',
];
const List<String> _separators = <String>['/', '\\'];
const List<String> _driveLetters = <String>['C', 'd', 'Z'];
const List<String> trailingFolderNoise = <String>[
  '',
  '/',
  '\\',
  ' ',
  '//',
  '/ \t',
  '\u3000/',
  '\u0085',
];

String randomDeviceIdText(Random random) {
  final int length = 1 + random.nextInt(_largestDeviceIdLength);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < length; i += 1) {
    buffer.write(pickOne(random, _deviceIdCharacters.split('')));
  }
  return buffer.toString();
}

List<String> randomFolderParts(Random random) {
  final int count = 1 + random.nextInt(_largestPartCount);
  return <String>[
    for (int i = 0; i < count; i += 1) pickOne(random, folderParts),
  ];
}

String randomFolderRoot(Random random) {
  if (random.nextBool()) {
    return '/';
  }
  final String driveLetter = pickOne(random, _driveLetters);
  return '$driveLetter:${pickOne(random, _separators)}';
}

String joinFolderParts(Random random, List<String> parts) {
  final StringBuffer buffer = StringBuffer(parts.first);
  for (final String part in parts.skip(1)) {
    buffer.write('${pickOne(random, _separators)}$part');
  }
  return buffer.toString();
}

String randomNormalFolderPath(Random random) {
  final String root = randomFolderRoot(random);
  return '$root${joinFolderParts(random, randomFolderParts(random))}';
}
