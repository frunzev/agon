import 'dart:math';

import '../../../support/random_inputs.dart';
import 'rust_local_folder_model.dart';
import 'white_space_inputs.dart';

const int folderPathsPerWorld = 8;
const int _largestPartCount = 4;
const List<String> _roots = <String>['/', 'C:\\', 'd:/', '', 'C:', '~/'];
const List<String> _parts = <String>[
  'home',
  'projects',
  'app',
  'Ünïcødé',
  '.',
  '..',
  '',
  'a b',
  'tab\there',
  'bom$byteOrderMark',
  byteOrderMark,
  '\u0085x',
];
const List<String> _separators = <String>['/', '\\'];
const List<String> folderNameInputs = <String>[
  'app',
  'new folder',
  '.',
  '..',
  '',
  ' padded',
  'padded\u3000',
  '${byteOrderMark}bom',
  'bom$byteOrderMark',
  'a/b',
  'a\\b',
  'bell\u0007',
  'café',
];

String randomFolderPathInput(Random random) {
  final StringBuffer path = StringBuffer(randomWhiteSpacePadding(random));
  path.write(pickOne(random, _roots));
  final int partCount = 1 + random.nextInt(_largestPartCount);
  for (int i = 0; i < partCount; i += 1) {
    if (i > 0) {
      path.write(pickOne(random, _separators));
    }
    path.write(pickOne(random, _parts));
  }
  if (random.nextBool()) {
    path.write(pickOne(random, _separators));
  }
  path.write(randomWhiteSpacePadding(random));
  return path.toString();
}

Set<String> randomGitlessFolderPaths(Random random) {
  final Set<String> gitless = <String>{};
  for (int i = 0; i < folderPathsPerWorld; i += 1) {
    try {
      gitless.add(normalizeRustFolderPath(randomFolderPathInput(random)));
    } on RustFolderRefusal {
      continue;
    }
  }
  return gitless;
}
