import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/background/login_item.dart';
import 'package:agent_orchestration/background/runner_presence.dart';
import 'package:agent_orchestration/background/start_at_login_choice_store.dart';
import 'package:agent_orchestration/screens/settings.dart';
import 'package:agent_orchestration/widgets/forms/switch_field.dart';

import '../../../support/app_harness.dart';
import '../../../support/random_inputs.dart';
import '../../../support/recording_runner_presence.dart';
import '../../../support/widget_harness.dart';

const String startAtLoginHint =
    'Opens when you log in so this computer can run tasks.';
const String thisComputerTitle = 'This computer';

Finder findStartAtLoginToggle() {
  return find.byWidgetPredicate(
    (Widget widget) =>
        widget is SwitchToggle && widget.semanticLabel == startAtLoginLabel,
  );
}

SwitchToggle readStartAtLoginToggle(WidgetTester tester) {
  return tester.widget<SwitchToggle>(findStartAtLoginToggle());
}

double randomStartAtLoginWidth(Random random) {
  return randomWidth(random, least: narrowestWidth, most: widestWidth);
}

Future<void> pumpStartAtLogin(
  WidgetTester tester, {
  required double width,
  required RunnerPresence presence,
}) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await pumpScrollableAtWidth(
    tester,
    width: width,
    child: StartAtLoginSection(runnerPresence: presence),
  );
  await tester.pump();
}

Future<void> tapStartAtLoginToggle(WidgetTester tester) async {
  await tester.ensureVisible(findStartAtLoginToggle());
  await tester.tap(findStartAtLoginToggle());
  await pumpFrames(tester);
}

RunnerPresence buildPresence({
  required LoginItem loginItem,
  required StartAtLoginChoiceStore store,
}) {
  return RunnerPresence(
    loginItem: loginItem,
    trayPresence: RecordingTrayPresence(),
    startAtLoginChoiceStore: store,
  );
}

final class CountingChoiceStore implements StartAtLoginChoiceStore {
  CountingChoiceStore({required this.isStartAtLoginChosen});

  bool isStartAtLoginChosen;
  int readCount = 0;
  Completer<void>? heldRead;

  @override
  Future<bool> readIsStartAtLoginChosen() async {
    readCount += 1;
    final Completer<void>? hold = heldRead;
    if (hold != null) {
      await hold.future;
    }
    return isStartAtLoginChosen;
  }

  @override
  Future<void> saveIsStartAtLoginChosen({required bool isChosen}) async {
    isStartAtLoginChosen = isChosen;
  }
}

final class StubbornChoiceStore implements StartAtLoginChoiceStore {
  StubbornChoiceStore({required this.isStartAtLoginChosen});

  final bool isStartAtLoginChosen;

  @override
  Future<bool> readIsStartAtLoginChosen() async => isStartAtLoginChosen;

  @override
  Future<void> saveIsStartAtLoginChosen({required bool isChosen}) async {}
}

final class HeldLoginItem implements LoginItem {
  bool isRegistered = false;
  int callCount = 0;
  final List<Completer<void>> heldCalls = <Completer<void>>[];

  @override
  Future<void> register() async {
    callCount += 1;
    await _hold();
    isRegistered = true;
  }

  @override
  Future<void> unregister() async {
    callCount += 1;
    await _hold();
    isRegistered = false;
  }

  void releaseCalls() {
    for (final Completer<void> heldCall in heldCalls) {
      heldCall.complete();
    }
    heldCalls.clear();
  }

  Future<void> _hold() {
    final Completer<void> heldCall = Completer<void>();
    heldCalls.add(heldCall);
    return heldCall.future;
  }
}

final class FailingLoginItem implements LoginItem {
  FailingLoginItem({required this.failure});

  final Object failure;

  @override
  Future<void> register() => Future<void>.error(failure);

  @override
  Future<void> unregister() => Future<void>.error(failure);
}
