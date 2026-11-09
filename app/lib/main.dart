import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/shell/problem_messenger.dart';
import 'package:agent_orchestration/startup/app_startup_choice.dart';
import 'package:agent_orchestration/startup/node_startup.dart';
import 'package:agent_orchestration/startup/single_window_app.dart';
import 'package:agent_orchestration/windows/flutter_windowing/flutter_windowing_switch.dart';
import 'package:agent_orchestration/windows/run_several_windows.dart';
import 'package:agent_orchestration/windows/several_windows_support.dart';

const String _appDataEnvironmentName = 'APP_DATA';
const String _appDataChoice = String.fromEnvironment(_appDataEnvironmentName);

void main() {
  final bool hasSeveralWindows = supportsSeveralWindows(defaultTargetPlatform);
  if (hasSeveralWindows) {
    turnOnFlutterWindowing();
  }

  WidgetsFlutterBinding.ensureInitialized();
  final ProblemMessenger problemMessenger = ProblemMessenger();
  WidgetsBinding.instance.platformDispatcher.onError =
      problemMessenger.showProblem;

  final NodeStartup startup = chooseStartup(appDataChoice: _appDataChoice);
  startup.start();

  if (hasSeveralWindows) {
    runSeveralWindows(startup: startup, problemMessenger: problemMessenger);
    return;
  }

  final MessengerKey messengerKey = problemMessenger.addMessengerKey();
  runApp(buildSingleWindowGate(startup: startup, messengerKey: messengerKey));
}
