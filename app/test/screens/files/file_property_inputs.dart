import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:agent_orchestration/data/gallery/gallery_file_texts.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';
import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/code_point_order.dart';
import 'package:agent_orchestration/screens/files/repository_file_paths.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../support/random_inputs.dart';

const List<String> sampleFileExtensions = <String>[
  'ts',
  'TSX',
  'md',
  'MD',
  'markdown',
  'dart',
  'rs',
  'py',
  'json',
  'yaml',
  'png',
  'mp4',
  'MOV',
  'zip',
  'gz',
  'pdf',
  'txt',
  'bin',
  'Md',
  '',
];
const List<String> _hostileNamePieces = <String>[
  '\u0000',
  '\u0007',
  '\t',
  '\n',
  '\\',
  'C:\\Users',
  '\u202e',
  '\u{1F600}',
  'e\u0301',
  ' ',
  '..',
];
const String _pathSeparator = '/';
const String _foreignSeparator = '\\';
const int _largestLineCount = 40;
const int _largestImageSide = 5000;
const int _largestFileSizeBase = 1 << 30;
const int _largestFileSizeShift = 11;
const int _largestBranchCount = 5;

String randomHostileFileStem(Random random) {
  final String piece = pickOne(random, _hostileNamePieces);
  final String stem = 'f${randomHostileText(random)}$piece';
  return stem.replaceAll(_pathSeparator, _foreignSeparator);
}

String randomHostileFileName(Random random) {
  final String extension = pickOne(random, sampleFileExtensions);
  return '${randomHostileFileStem(random)}.$extension';
}

String randomFilePath(Random random) {
  final int depth = random.nextInt(4);
  final List<String> folders = <String>[
    for (int index = 0; index < depth; index += 1)
      randomHostileFileStem(random),
  ];
  return <String>[
    ...folders,
    randomHostileFileName(random),
  ].join(_pathSeparator);
}

String randomFileText(Random random) {
  final int lineCount = random.nextInt(_largestLineCount);
  final StringBuffer text = StringBuffer();
  for (int index = 0; index < lineCount; index += 1) {
    text.write(randomHostileText(random).replaceAll('\n', ' '));
    text.write(pickOne(random, <String>['\n', '\r\n']));
  }
  if (random.nextBool()) {
    text.write(randomText(random));
  }
  return text.toString();
}

FilePreview randomFilePreview(Random random) {
  return switch (random.nextInt(4)) {
    0 => TextFilePreview(randomFileText(random)),
    1 => ImageFilePreview(
      width: random.nextInt(_largestImageSide),
      height: random.nextInt(_largestImageSide),
      bytes: galleryIconBytes,
    ),
    2 => ImageFilePreview(
      width: random.nextInt(_largestImageSide),
      height: random.nextInt(_largestImageSide),
      bytes: Uint8List.fromList(<int>[random.nextInt(256), 0, 1]),
    ),
    _ => UnavailableFilePreview(
      pickOne(random, PreviewUnavailableReason.values),
    ),
  };
}

int randomFileSize(Random random) {
  final int base = random.nextInt(_largestFileSizeBase);
  return base << random.nextInt(_largestFileSizeShift);
}

RepositoryFile randomRepositoryFile(Random random) {
  return RepositoryFile(
    path: randomFilePath(random),
    size: randomFileSize(random),
    preview: randomFilePreview(random),
  );
}

List<String> randomDistinctBranches(Random random, String prefix) {
  final Set<String> branches = <String>{};
  final int count = random.nextInt(_largestBranchCount);
  for (int index = 0; index < count; index += 1) {
    branches.add('$prefix${randomHostileText(random)}$index');
  }
  return branches.toList();
}

FilesFromRunner randomFilesFromRunner(Random random) {
  return FilesFromRunner(
    runnerId: const DeviceId('runner'),
    runnerName: randomHostileText(random),
    branches: randomDistinctBranches(random, ''),
    taskBranches: randomDistinctBranches(random, 'task/'),
  );
}

const RepositoryBranchLocation sampleBranchLocation = RepositoryBranchLocation(
  projectId: ProjectId('project'),
  repositoryAddress: 'github.com/acme/app',
  runnerId: DeviceId('runner'),
  branch: 'main',
);
const int _largestFolderSize = 5;
const int _deepestFolder = 3;

typedef FolderTree = Map<String, List<RepositoryEntry>>;

String describeListingRefusal(String folder) {
  return 'the runner could not list $folder';
}

FolderTree randomFolderTree(Random random) {
  final FolderTree folders = <String, List<RepositoryEntry>>{};
  _fillFolder(random, folders: folders, folder: '', depth: 0);
  return folders;
}

void _fillFolder(
  Random random, {
  required FolderTree folders,
  required String folder,
  required int depth,
}) {
  final Set<String> names = <String>{};
  final int count = random.nextInt(_largestFolderSize);
  for (int index = 0; index < count; index += 1) {
    names.add(randomHostileFileStem(random));
  }
  final List<String> sortedNames = names.toList()..sort(compareCodePoints);
  final List<RepositoryEntry> entries = <RepositoryEntry>[];
  for (final String name in sortedNames) {
    final bool isFolder = depth < _deepestFolder && random.nextBool();
    final RepositoryEntryKind kind = isFolder
        ? RepositoryEntryKind.folder
        : pickOne(random, <RepositoryEntryKind>[
            RepositoryEntryKind.file,
            RepositoryEntryKind.link,
          ]);
    entries.add(
      RepositoryEntry(
        name: name,
        kind: kind,
        size: isFolder ? null : randomFileSize(random),
      ),
    );
    if (isFolder) {
      final String path = joinRepositoryPath(folder, name);
      _fillFolder(random, folders: folders, folder: path, depth: depth + 1);
    }
  }
  folders[folder] = List<RepositoryEntry>.unmodifiable(entries);
}

final class ScriptedFolderRepository implements FileRepository {
  ScriptedFolderRepository({required this.folders});

  final FolderTree folders;
  final Set<String> refusedFolders = <String>{};
  final List<String> askedFolders = <String>[];
  final List<String> repeatedPendingFolders = <String>[];
  final List<Completer<void>> heldAnswers = <Completer<void>>[];
  final Set<String> _pendingFolders = <String>{};
  bool isHoldingAnswers = false;
  Error? problemToThrow;

  @override
  Future<List<RepositoryEntry>> listFolder({
    required RepositoryBranchLocation location,
    required String folder,
  }) async {
    askedFolders.add(folder);
    if (!_pendingFolders.add(folder)) {
      repeatedPendingFolders.add(folder);
    }
    if (isHoldingAnswers) {
      final Completer<void> answer = Completer<void>();
      heldAnswers.add(answer);
      await answer.future;
    }
    _pendingFolders.remove(folder);
    return _answer(folder);
  }

  List<RepositoryEntry> _answer(String folder) {
    final Error? problem = problemToThrow;
    if (problem != null) {
      throw problem;
    }
    final List<RepositoryEntry>? entries = folders[folder];
    if (entries == null || refusedFolders.contains(folder)) {
      throw PeopleFacingRefusal(describeListingRefusal(folder));
    }
    return entries;
  }

  void releaseOneAnswer(Random random) {
    final int index = random.nextInt(heldAnswers.length);
    heldAnswers.removeAt(index).complete();
  }

  @override
  Future<RepositoryFileSource> openRepository({
    required ProjectId projectId,
    required String repositoryAddress,
    required DeviceId? preferredRunnerId,
  }) {
    throw UnsupportedError('the tree never opens a repository');
  }

  @override
  Future<RepositoryFile> readFile({
    required RepositoryBranchLocation location,
    required String path,
  }) {
    throw UnsupportedError('the tree never reads a file');
  }
}
