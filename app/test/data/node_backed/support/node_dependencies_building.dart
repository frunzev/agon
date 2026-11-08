import 'dart:math';

import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/bridge/node/node_command_channel.dart';
import 'package:agent_orchestration/data/clock.dart';
import 'package:agent_orchestration/data/node_backed.dart';

import '../../../support/fixed_folder_picker.dart';
import '../../../support/fixed_qr_code_scanner.dart';
import '../../../support/memory_workspace_choice_store.dart';
import '../../../support/random_inputs.dart';
import '../../../support/recording_runner_presence.dart';

typedef DependencyCollaborators = ({
  Clock clock,
  FixedQrCodeScanner qrCodeScanner,
  FixedFolderPicker folderPicker,
  RunnerPresence? runnerPresence,
});

DependencyCollaborators randomDependencyCollaborators(Random random) {
  final RunnerPresence? runnerPresence = random.nextBool()
      ? RecordedRunnerPresence(isStartAtLoginChosen: random.nextBool())
            .presence
      : null;
  return (
    clock: FixedClock(randomUtcMoment(random)),
    qrCodeScanner: FixedQrCodeScanner(null),
    folderPicker: FixedFolderPicker(null),
    runnerPresence: runnerPresence,
  );
}

NodeDependencies buildDependenciesWith(
  NodeCommandChannel channel,
  DependencyCollaborators collaborators,
) {
  return buildNodeDependencies(
    channel: channel,
    clock: collaborators.clock,
    qrCodeScanner: collaborators.qrCodeScanner,
    folderPicker: collaborators.folderPicker,
    workspaceChoiceStore: MemoryWorkspaceChoiceStore(chosenWorkspaceId: null),
    runnerPresence: collaborators.runnerPresence,
  );
}
