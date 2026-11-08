import 'dart:math';
import 'dart:ui';

import '../../support/random_inputs.dart';
import 'icon_path_spelling.dart';

export 'icon_path_spelling.dart';

enum IconPathStep {
  move('M', 2),
  line('L', 2),
  horizontal('H', 1),
  vertical('V', 1),
  curve('C', 6),
  arc('A', 7),
  close('Z', 0);

  const IconPathStep(this.letter, this.numberCount);

  final String letter;
  final int numberCount;
}

enum IconPathRelativity { absolute, relative, mixed }

enum IconPathLetters { everyCommand, implicitRepeats }

final class IconPathCommand {
  const IconPathCommand({required this.step, required this.numbers});

  final IconPathStep step;
  final List<double> numbers;
}

const int _quarterSteps = 129;
const int _quarterStepsBelowZero = 16;
const double _quarter = 4;
const int _largestRadiusInQuarters = 48;
const int _largestRotation = 90;
const int _mostStepsAfterStart = 8;
const int _firstArcFlagIndex = 3;
const int _secondArcFlagIndex = 4;
const int _arcEndIndex = 5;
const List<String> _letterSeparators = <String>['', ' ', '\n', '\t'];

double randomGridNumber(Random random) {
  return (random.nextInt(_quarterSteps) - _quarterStepsBelowZero) / _quarter;
}

double _randomRadius(Random random) {
  return (1 + random.nextInt(_largestRadiusInQuarters)) / _quarter;
}

IconPathCommand randomIconPathCommand(Random random, IconPathStep step) {
  final List<double> numbers = <double>[];
  if (step == IconPathStep.arc) {
    numbers
      ..add(_randomRadius(random))
      ..add(_randomRadius(random))
      ..add(random.nextInt(_largestRotation).toDouble())
      ..add(random.nextInt(2).toDouble())
      ..add(random.nextInt(2).toDouble())
      ..add(randomGridNumber(random))
      ..add(randomGridNumber(random));
    return IconPathCommand(step: step, numbers: numbers);
  }
  for (int i = 0; i < step.numberCount; i += 1) {
    numbers.add(randomGridNumber(random));
  }
  return IconPathCommand(step: step, numbers: numbers);
}

List<IconPathCommand> randomIconPathCommands(Random random) {
  final List<IconPathCommand> commands = <IconPathCommand>[
    randomIconPathCommand(random, IconPathStep.move),
  ];
  final int stepCount = random.nextInt(_mostStepsAfterStart + 1);
  for (int i = 0; i < stepCount; i += 1) {
    final IconPathStep step = pickOne(random, IconPathStep.values);
    commands.add(randomIconPathCommand(random, step));
  }
  return commands;
}

Offset _pointAfter(IconPathCommand command, Offset current, Offset start) {
  final List<double> numbers = command.numbers;
  switch (command.step) {
    case IconPathStep.horizontal:
      return Offset(numbers[0], current.dy);
    case IconPathStep.vertical:
      return Offset(current.dx, numbers[0]);
    case IconPathStep.close:
      return start;
    case IconPathStep.move:
    case IconPathStep.line:
    case IconPathStep.curve:
    case IconPathStep.arc:
      return Offset(numbers[numbers.length - 2], numbers.last);
  }
}

void _drawModelStep(Path path, IconPathCommand command, Offset end) {
  final List<double> numbers = command.numbers;
  switch (command.step) {
    case IconPathStep.move:
      path.moveTo(end.dx, end.dy);
    case IconPathStep.line:
    case IconPathStep.horizontal:
    case IconPathStep.vertical:
      path.lineTo(end.dx, end.dy);
    case IconPathStep.curve:
      path.cubicTo(
        numbers[0],
        numbers[1],
        numbers[2],
        numbers[3],
        end.dx,
        end.dy,
      );
    case IconPathStep.arc:
      path.arcToPoint(
        end,
        radius: Radius.elliptical(numbers[0], numbers[1]),
        rotation: numbers[2],
        largeArc: numbers[_firstArcFlagIndex] != 0,
        clockwise: numbers[_secondArcFlagIndex] != 0,
      );
    case IconPathStep.close:
      path.close();
  }
}

Path buildModelIconPath(List<IconPathCommand> commands) {
  final Path path = Path();
  Offset current = Offset.zero;
  Offset subpathStart = Offset.zero;

  for (final IconPathCommand command in commands) {
    final Offset end = _pointAfter(command, current, subpathStart);
    _drawModelStep(path, command, end);
    if (command.step == IconPathStep.move) {
      subpathStart = end;
    }
    current = end;
  }
  return path;
}

List<double> _relativeNumbers(IconPathCommand command, Offset current) {
  final List<double> numbers = command.numbers;
  switch (command.step) {
    case IconPathStep.horizontal:
      return <double>[numbers[0] - current.dx];
    case IconPathStep.vertical:
      return <double>[numbers[0] - current.dy];
    case IconPathStep.arc:
      return <double>[
        ...numbers.sublist(0, _arcEndIndex),
        numbers[_arcEndIndex] - current.dx,
        numbers[_arcEndIndex + 1] - current.dy,
      ];
    case IconPathStep.move:
    case IconPathStep.line:
    case IconPathStep.curve:
    case IconPathStep.close:
      final List<double> shifted = <double>[];
      for (int i = 0; i < numbers.length; i += 1) {
        final double origin = i.isEven ? current.dx : current.dy;
        shifted.add(numbers[i] - origin);
      }
      return shifted;
  }
}

bool _choosesRelative(Random random, IconPathRelativity relativity) {
  switch (relativity) {
    case IconPathRelativity.absolute:
      return false;
    case IconPathRelativity.relative:
      return true;
    case IconPathRelativity.mixed:
      return random.nextBool();
  }
}

List<String> _spellNumbers(
  Random random,
  IconPathStep step,
  List<double> numbers,
) {
  final List<String> spelled = <String>[];
  for (int i = 0; i < numbers.length; i += 1) {
    final bool isArcFlag =
        step == IconPathStep.arc &&
        (i == _firstArcFlagIndex || i == _secondArcFlagIndex);
    if (isArcFlag) {
      spelled.add(numbers[i].toInt().toString());
    } else {
      spelled.add(spellIconPathNumber(random, numbers[i]));
    }
  }
  return spelled;
}

String? _implicitLetterAfter(String letter) {
  if (letter == 'M') {
    return 'L';
  }
  if (letter == 'm') {
    return 'l';
  }
  if (letter.toUpperCase() == IconPathStep.close.letter) {
    return null;
  }
  return letter;
}

String spellIconPath(
  Random random,
  List<IconPathCommand> commands, {
  required IconPathRelativity relativity,
  required IconPathLetters letters,
}) {
  final StringBuffer buffer = StringBuffer();
  Offset current = Offset.zero;
  Offset subpathStart = Offset.zero;
  String? implicitLetter;
  String? lastNumber;

  for (final IconPathCommand command in commands) {
    final bool isRelative = _choosesRelative(random, relativity);
    final String letter = isRelative
        ? command.step.letter.toLowerCase()
        : command.step.letter;
    final List<double> numbers = isRelative
        ? _relativeNumbers(command, current)
        : command.numbers;
    final List<String> spelled = _spellNumbers(random, command.step, numbers);
    final bool omitsLetter =
        letters == IconPathLetters.implicitRepeats &&
        letter == implicitLetter &&
        lastNumber != null &&
        random.nextBool();

    if (omitsLetter) {
      buffer.write(separateNumbers(random, lastNumber, spelled.first));
    } else {
      buffer
        ..write(pickOne(random, _letterSeparators))
        ..write(letter)
        ..write(pickOne(random, _letterSeparators));
    }
    buffer.write(joinIconPathNumbers(random, spelled));

    lastNumber = spelled.isEmpty ? null : spelled.last;
    implicitLetter = _implicitLetterAfter(letter);
    final Offset end = _pointAfter(command, current, subpathStart);
    if (command.step == IconPathStep.move) {
      subpathStart = end;
    }
    current = end;
  }
  return buffer.toString();
}
