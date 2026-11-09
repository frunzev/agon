import 'dart:async';

import 'package:flutter/material.dart';

import 'package:agent_orchestration/data/folder_picker.dart';
import 'package:agent_orchestration/data/models/project.dart';
import 'package:agent_orchestration/data/repository/device_repository.dart';
import 'package:agent_orchestration/data/repository/project_repository.dart';
import 'package:agent_orchestration/screens/projects.dart';
import 'package:agent_orchestration/screens/projects/folder_choice.dart';
import 'package:agent_orchestration/screens/projects/repository_entry.dart';
import 'package:agent_orchestration/screens/shared/action_refusal.dart';
import 'package:agent_orchestration/widgets/app_button.dart';
import 'package:agent_orchestration/widgets/app_dialog.dart';
import 'package:agent_orchestration/widgets/forms/choice_list_field.dart';
import 'package:agent_orchestration/widgets/forms/form_field_block.dart';

const String _computerAddressHint =
    'Paste a GitHub address or choose a folder on this computer.';
const String _phoneAddressHint = 'Paste a GitHub address.';
const String _addRepositoryLabel = 'Add repo';

Future<void> showAddRepositoryDialog({
  required BuildContext context,
  required Project project,
  required ProjectRepository projectRepository,
  required DeviceRepository deviceRepository,
  required FolderPicker? folderPicker,
}) {
  return showAppDialog<void>(
    context: context,
    builder: (BuildContext _) => AddRepositoryDialog(
      project: project,
      projectRepository: projectRepository,
      deviceRepository: deviceRepository,
      folderPicker: folderPicker,
    ),
  );
}

class AddRepositoryDialog extends StatefulWidget {
  const AddRepositoryDialog({
    required this.project,
    required this.projectRepository,
    required this.deviceRepository,
    required this.folderPicker,
    super.key,
  });

  final Project project;
  final ProjectRepository projectRepository;
  final DeviceRepository deviceRepository;
  final FolderPicker? folderPicker;

  @override
  State<AddRepositoryDialog> createState() => _AddRepositoryDialogState();
}

class _AddRepositoryDialogState extends State<AddRepositoryDialog> {
  final TextEditingController _addressController = TextEditingController();
  AgentAccess _access = AgentAccess.pushAfterApproval;
  String? _addressProblem;
  bool _isSaving = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final FolderPicker? folderPicker = widget.folderPicker;

    return AppDialog(
      title: _describeTitle(),
      content: <Widget>[
        FormFieldBlock(
          label: 'Address',
          hint: folderPicker == null
              ? _phoneAddressHint
              : _computerAddressHint,
          children: <Widget>[
            RepositoryEntryField(
              controller: _addressController,
              problem: _addressProblem,
              placeholder: folderPicker == null
                  ? phoneRepositoryPlaceholder
                  : computerRepositoryPlaceholder,
              onChanged: (String _) => setState(() => _addressProblem = null),
              onAdded: () => unawaited(_addTypedRepository()),
            ),
            if (folderPicker != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppButton.secondary(
                  label: chooseFolderLabel,
                  onPressed: () => unawaited(_chooseFolder(folderPicker)),
                ),
              ),
          ],
        ),
        FormFieldBlock(
          label: 'What agents can do',
          children: <Widget>[
            ChoiceListField<AgentAccess>(
              options: buildAgentAccessChoices(),
              selected: _access,
              onChanged: (AgentAccess access) =>
                  setState(() => _access = access),
            ),
          ],
        ),
      ],
      actions: <Widget>[
        AppButton.secondary(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  List<String> _listAddedAddresses() {
    return <String>[
      for (final Repository repository in widget.project.repositories)
        repository.address,
    ];
  }

  Future<void> _addTypedRepository() async {
    final FolderPicker? folderPicker = widget.folderPicker;
    final RepositoryEntry entry = await readTypedRepository(
      text: _addressController.text,
      checkFolder: folderPicker == null
          ? null
          : widget.deviceRepository.checkLocalFolder,
      listAddedAddresses: _listAddedAddresses,
    );
    await _saveEntry(entry);
  }

  Future<void> _chooseFolder(FolderPicker folderPicker) async {
    final String? path = await folderPicker.chooseFolder();
    if (path == null || !mounted) {
      return;
    }
    final RepositoryEntry entry = await readCheckedFolder(
      folderAnswer: widget.deviceRepository.checkLocalFolder(path),
      listAddedAddresses: _listAddedAddresses,
    );
    await _saveEntry(entry);
  }

  Future<void> _saveEntry(RepositoryEntry entry) async {
    if (!mounted) {
      return;
    }
    switch (entry) {
      case RefusedRepository(:final String problem):
        setState(() => _addressProblem = problem);
      case AcceptedRepository(:final RepositoryDraft repository):
        await _saveRepository(repository);
    }
  }

  Future<void> _saveRepository(RepositoryDraft repository) async {
    if (_isSaving) {
      return;
    }
    final NavigatorState dialogNavigator = Navigator.of(context);
    _isSaving = true;

    final ActionOutcome outcome = await runShowingRefusal(
      context: context,
      title: _describeTitle(),
      actionLabel: _addRepositoryLabel,
      action: () => widget.projectRepository.addRepository(
        widget.project.id,
        Repository(
          address: repository.address,
          defaultBranch: repository.defaultBranch,
          agentAccess: _access,
        ),
      ),
    );

    if (outcome == ActionOutcome.refused) {
      _isSaving = false;
      return;
    }
    if (dialogNavigator.mounted) {
      dialogNavigator.pop();
    }
  }

  String _describeTitle() => 'Add repo to ${widget.project.name}';
}
