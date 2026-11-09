import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/presentation/identifier_text.dart';
import 'package:agent_orchestration/screens/projects/project_text.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/fact_list.dart';
import 'package:agent_orchestration/widgets/mixed_text.dart';

const String _removeRepositoryLabel = 'Remove repo';

Future<void> showRemoveRepositoryDialog({
  required BuildContext context,
  required Project project,
  required Repository repository,
  required ProjectRepository projectRepository,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext _) => RemoveRepositoryDialog(
      project: project,
      repository: repository,
      projectRepository: projectRepository,
    ),
  );
}

class RemoveRepositoryDialog extends StatefulWidget {
  const RemoveRepositoryDialog({
    required this.project,
    required this.repository,
    required this.projectRepository,
    super.key,
  });

  final Project project;
  final Repository repository;
  final ProjectRepository projectRepository;

  @override
  State<RemoveRepositoryDialog> createState() =>
      _RemoveRepositoryDialogState();
}

class _RemoveRepositoryDialogState extends State<RemoveRepositoryDialog> {
  bool _isRemoving = false;

  @override
  Widget build(BuildContext context) {
    final Repository repository = widget.repository;

    return AppDialog(
      title: describeRepositoryPath(repository.address),
      content: <Widget>[
        FactList(
          facts: <Fact>[
            Fact(
              term: 'Address',
              description: <TextSegment>[
                TextSegment.monospace(repository.address),
              ],
            ),
            Fact(
              term: 'Branch',
              description: <TextSegment>[
                TextSegment.monospace(repository.defaultBranch),
              ],
            ),
            Fact(
              term: 'Agents can',
              description: <TextSegment>[
                TextSegment(describeAgentAccess(repository.agentAccess)),
              ],
            ),
          ],
        ),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppButton.danger(
          label: _removeRepositoryLabel,
          onPressed: _isRemoving ? null : () => unawaited(_removeRepository()),
        ),
      ],
    );
  }

  Future<void> _removeRepository() async {
    final NavigatorState dialogNavigator = Navigator.of(context);
    final Repository repository = widget.repository;
    setState(() => _isRemoving = true);

    final ActionOutcome outcome = await runShowingRefusal(
      context: context,
      title: describeRepositoryPath(repository.address),
      actionLabel: _removeRepositoryLabel,
      action: () => widget.projectRepository.removeRepository(
        widget.project.id,
        repository.address,
      ),
    );

    if (outcome == ActionOutcome.refused && mounted) {
      setState(() => _isRemoving = false);
    }
    if (outcome == ActionOutcome.done && dialogNavigator.mounted) {
      dialogNavigator.pop();
    }
  }
}
