import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/bridge/codecs/repository_file_values.dart'
    as node;
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/data/node_backed.dart';
import 'package:agent_orchestration/data/node_backed/mapping.dart';
import 'package:agent_orchestration/data/repository/file_repository.dart';

import '../../../bridge/support/random_file_json.dart';
import '../../../support/random_inputs.dart';
import '../../node_backed/support/simulated_node_replies.dart';
import 'contract_step_failures.dart';
import 'rust_repository_files_model.dart';

const List<String> fileContractAddresses = <String>[
  'github.com/acme/app',
  'github.com/acme/other',
];
const List<String> _segments = <String>[
  'src',
  'Src',
  'README.md',
  'a.ts',
  'B.ts',
  'café',
  'Ünïcødé',
  '\u{1F600}.txt',
  'with space',
  'bell\u0007',
  'back\\slash',
];
const int _largestFileCount = 10;
const int _largestDepth = 3;
const int _largestSize = 100000;

typedef NamedFileRepository = ({String name, FileRepository repository});

typedef FileContractWorld = ({
  List<NamedFileRepository> implementations,
  List<ModelFile> files,
});

FileContractWorld buildEveryFileRepository(Random random) {
  final List<ModelFile> files = _randomConsistentFiles(random);
  final Map<String, Map<String, Object?>> branchViews =
      <String, Map<String, Object?>>{
        for (final String address in fileContractAddresses)
          if (random.nextBool()) address: randomRepositoryBranchesJson(random),
      };
  final RustRepositoryFilesModel model = RustRepositoryFilesModel(
    files: files,
    branchViews: branchViews,
  );
  final FakeFileRepository fake = FakeFileRepository(
    sources: <String, RepositoryFileSource>{
      for (final MapEntry<String, Map<String, Object?>> view
          in branchViews.entries)
        view.key: mapRepositoryFileSourceFromNode(
          node.RepositoryBranchesView.fromJson(view.value),
        ),
    },
    files: <FakeRepositoryFile>[
      for (final ModelFile file in files)
        FakeRepositoryFile(
          repositoryAddress: file.address,
          path: file.path,
          size: file.size,
          preview: mapFilePreviewFromNode(
            node.FilePreview.fromJson(file.preview),
          ),
        ),
    ],
  );
  final List<NamedFileRepository> implementations = <NamedFileRepository>[
    (name: 'fake', repository: fake),
    (
      name: 'node backed',
      repository: NodeBackedFileRepository(
        channel: buildSimulatedChannel(model.answer),
      ),
    ),
  ];
  return (implementations: implementations, files: files);
}

List<ModelFile> _randomConsistentFiles(Random random) {
  final Map<String, ModelFile> byPath = <String, ModelFile>{};
  final int count = random.nextInt(_largestFileCount);
  for (int i = 0; i < count; i += 1) {
    final String address = pickOne(random, fileContractAddresses);
    final String path = _randomFilePath(random);
    byPath['$address:$path'] = (
      address: address,
      path: path,
      size: random.nextInt(_largestSize),
      preview: _randomPreviewJson(random),
    );
  }
  final List<ModelFile> files = byPath.values.toList();
  return <ModelFile>[
    for (final ModelFile file in files)
      if (!_isFolderOfAnother(file, files)) file,
  ];
}

bool _isFolderOfAnother(ModelFile file, List<ModelFile> files) {
  for (final ModelFile other in files) {
    final bool isSameRepository = other.address == file.address;
    if (isSameRepository && other.path.startsWith('${file.path}/')) {
      return true;
    }
  }
  return false;
}

String _randomFilePath(Random random) {
  final int depth = 1 + random.nextInt(_largestDepth);
  final List<String> segments = <String>[
    for (int i = 0; i < depth; i += 1) pickOne(random, _segments),
  ];
  return segments.join('/');
}

Map<String, Object?> _randomPreviewJson(Random random) {
  final List<Map<String, Object?>> previews = <Map<String, Object?>>[
    <String, Object?>{'kind': 'text', 'text': randomText(random)},
    <String, Object?>{'kind': 'too_large'},
    <String, Object?>{'kind': 'binary'},
    <String, Object?>{'kind': 'link'},
  ];
  return pickOne(random, previews);
}

RepositoryBranchLocation buildContractLocation(String address) {
  return RepositoryBranchLocation(
    projectId: const ProjectId('contract-project'),
    repositoryAddress: address,
    runnerId: const DeviceId('contract-runner'),
    branch: 'main',
  );
}

String describePreview(FilePreview preview) {
  return switch (preview) {
    TextFilePreview(:final String text) => 'text $text',
    ImageFilePreview(:final int width, :final int height) =>
      'image $width x $height',
    UnavailableFilePreview(:final PreviewUnavailableReason reason) =>
      'unavailable $reason',
  };
}

String describeSource(RepositoryFileSource source) {
  return switch (source) {
    FilesFromRunner() =>
      'runner ${source.runnerId.value} ${source.runnerName} '
          '${source.branches} ${source.taskBranches}',
    FilesWithoutRunner(:final List<RepositoryHolder> holders) =>
      'without runner ${_describeHolders(holders)}',
  };
}

const List<String> folderSpellings = <String>[
  '',
  '.',
  './',
  '/',
  '..',
  'src/..',
  'a\\b',
  'missing',
];

typedef EntryProjection = ({String name, RepositoryEntryKind kind, int? size});

typedef ReadOutcome = ({String name, Object? failure, String? described});

List<EntryProjection> projectEntries(List<RepositoryEntry> entries) {
  return <EntryProjection>[
    for (final RepositoryEntry entry in entries)
      (name: entry.name, kind: entry.kind, size: entry.size),
  ];
}

String randomFolderSpelling(Random random, FileContractWorld world) {
  if (world.files.isEmpty || random.nextInt(3) == 0) {
    return pickOne(random, folderSpellings);
  }
  final List<String> parts = pickOne(random, world.files).path.split('/');
  final int depth = random.nextInt(parts.length);
  final String folder = parts.sublist(0, depth).join('/');
  return pickOne(random, <String>[folder, './$folder', '$folder/', folder]);
}

String randomFilePathSpelling(Random random, FileContractWorld world) {
  if (world.files.isEmpty || random.nextInt(4) == 0) {
    return pickOne(random, folderSpellings);
  }
  final String path = pickOne(random, world.files).path;
  return pickOne(random, <String>[
    path,
    './$path',
    path.replaceAll('/', '//'),
  ]);
}

Future<ReadOutcome> readFileOn(
  NamedFileRepository implementation, {
  required String address,
  required String path,
}) async {
  String? described;
  final Object? failure = await findStepFailure(() async {
    final RepositoryFile file = await implementation.repository.readFile(
      location: buildContractLocation(address),
      path: path,
    );
    described = '${file.path} ${file.size} ${describePreview(file.preview)}';
  });
  return (name: implementation.name, failure: failure, described: described);
}

Future<List<EntryProjection>?> listFolderOn(
  FileRepository repository, {
  required String address,
  required String folder,
}) async {
  final StepOutcome<List<RepositoryEntry>> listing = await runContractStep(
    () => repository.listFolder(
      location: buildContractLocation(address),
      folder: folder,
    ),
  );
  final List<RepositoryEntry>? entries = listing.value;
  if (entries == null) {
    expect(isContractRefusal(listing.failure), isTrue);
    return null;
  }
  return projectEntries(entries);
}

List<String> _describeHolders(List<RepositoryHolder> holders) {
  return <String>[
    for (final RepositoryHolder holder in holders)
      '${holder.deviceId.value} ${holder.name} ${holder.lastSeen}',
  ];
}
