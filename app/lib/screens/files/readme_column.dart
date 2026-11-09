import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/data/models/repository_files.dart';
import 'package:agent_orchestration/presentation/problem_text.dart';
import 'package:agent_orchestration/screens/files/file_tree_controller.dart';
import 'package:agent_orchestration/screens/files/files_page_parts.dart';
import 'package:agent_orchestration/screens/files/readme_section.dart';

const String _rootFolder = '';

class ReadmeColumn extends StatefulWidget {
  const ReadmeColumn({
    required this.tree,
    required this.repositoryPath,
    super.key,
  });

  final FileTreeController tree;
  final String repositoryPath;

  @override
  State<ReadmeColumn> createState() => _ReadmeColumnState();
}

class _ReadmeColumnState extends State<ReadmeColumn> {
  RepositoryFile? _readme;
  String? _problem;
  bool _hasAskedForReadme = false;

  @override
  void initState() {
    super.initState();
    widget.tree.addListener(_readReadmeOnceListed);
    _readReadmeOnceListed();
  }

  @override
  void didUpdateWidget(ReadmeColumn oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.tree, widget.tree)) {
      return;
    }

    oldWidget.tree.removeListener(_readReadmeOnceListed);
    widget.tree.addListener(_readReadmeOnceListed);
    _readme = null;
    _problem = null;
    _hasAskedForReadme = false;
    _readReadmeOnceListed();
  }

  @override
  void dispose() {
    widget.tree.removeListener(_readReadmeOnceListed);
    super.dispose();
  }

  void _readReadmeOnceListed() {
    final List<RepositoryEntry>? rootEntries = widget.tree.entriesOf(
      _rootFolder,
    );
    if (rootEntries == null || _hasAskedForReadme) {
      return;
    }

    _hasAskedForReadme = true;
    final RepositoryEntry? readmeEntry = findReadmeEntry(rootEntries);
    if (readmeEntry != null) {
      unawaited(_readReadme(readmeEntry));
    }
  }

  Future<void> _readReadme(RepositoryEntry readmeEntry) async {
    final FileTreeController tree = widget.tree;
    final RepositoryFile readme;
    try {
      readme = await tree.fileRepository.readFile(
        location: tree.location,
        path: readmeEntry.name,
      );
    } on Object catch (problem) {
      final String? explanation = describeProblemForPeople(problem);
      if (explanation == null) {
        rethrow;
      }
      if (_isStillShowing(tree)) {
        setState(() => _problem = explanation);
      }
      return;
    }

    if (_isStillShowing(tree)) {
      setState(() => _readme = readme);
    }
  }

  bool _isStillShowing(FileTreeController tree) {
    return mounted && identical(tree, widget.tree);
  }

  @override
  Widget build(BuildContext context) {
    final String? problem = _problem;
    final RepositoryFile? readme = _readme;

    if (problem != null) {
      return FilesProblem(text: problem);
    }
    if (readme == null) {
      return const SizedBox.shrink();
    }
    return ReadmeSection(
      readme: readme,
      repositoryPath: widget.repositoryPath,
    );
  }
}
