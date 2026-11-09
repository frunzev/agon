const int _clockFieldWidth = 2;
const int _nightEndsBeforeHour = 6;
const int _weekAheadDays = 7;
const Duration _clockSkewTolerance = Duration(minutes: 5);
const String _justNowText = 'Just now';

const List<String> _weekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

const List<String> _monthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String _padClockField(int value) {
  return value.toString().padLeft(_clockFieldWidth, '0');
}

String formatClockTime(DateTime moment) {
  final DateTime localMoment = moment.toLocal();
  final String hour = _padClockField(localMoment.hour);
  final String minute = _padClockField(localMoment.minute);
  return '$hour:$minute';
}

String formatLogTime(DateTime moment) {
  final String second = _padClockField(moment.toLocal().second);
  return '${formatClockTime(moment)}:$second';
}

int countCalendarDaysBetween(DateTime earlier, DateTime later) {
  final DateTime localEarlier = earlier.toLocal();
  final DateTime localLater = later.toLocal();
  final DateTime earlierDay = DateTime.utc(
    localEarlier.year,
    localEarlier.month,
    localEarlier.day,
  );
  final DateTime laterDay = DateTime.utc(
    localLater.year,
    localLater.month,
    localLater.day,
  );

  return laterDay.difference(earlierDay).inDays;
}

String _describeMomentAhead(DateTime moment, DateTime now) {
  final String clock = formatClockTime(moment);
  final int daysAhead = countCalendarDaysBetween(now, moment);
  if (daysAhead != 0) {
    return '${formatCalendarDate(moment)} $clock';
  }

  final Duration ahead = moment.difference(now);
  if (ahead < _clockSkewTolerance) {
    return _justNowText;
  }
  return 'Today $clock';
}

String describeTimeSince(DateTime moment, DateTime now) {
  final Duration age = now.difference(moment);
  if (age.isNegative) {
    return _describeMomentAhead(moment, now);
  }
  if (age.inMinutes < 1) {
    return _justNowText;
  }
  if (age.inMinutes < Duration.minutesPerHour) {
    return '${age.inMinutes} min ago';
  }

  final int daysAgo = countCalendarDaysBetween(moment, now);
  if (daysAgo == 0) {
    return '${age.inHours} h ago';
  }
  if (daysAgo == 1) {
    return 'Yesterday ${formatClockTime(moment)}';
  }
  return '$daysAgo days ago';
}

String describeUpcomingTime(DateTime moment, DateTime now) {
  final DateTime localMoment = moment.toLocal();
  final String clock = formatClockTime(localMoment);
  final int daysAhead = countCalendarDaysBetween(now, moment);

  if (daysAhead <= 0) {
    return 'Today $clock';
  }
  if (daysAhead == 1 && localMoment.hour < _nightEndsBeforeHour) {
    return 'Tonight $clock';
  }
  if (daysAhead == 1) {
    return 'Tomorrow $clock';
  }
  if (daysAhead < _weekAheadDays) {
    return '${_weekdayNames[localMoment.weekday - 1]} $clock';
  }
  final String month = _monthNames[localMoment.month - 1];
  return '${localMoment.day} $month $clock';
}

String formatCalendarDate(DateTime moment) {
  final DateTime localMoment = moment.toLocal();
  final String month = _monthNames[localMoment.month - 1];
  return '${localMoment.day} $month ${localMoment.year}';
}

String describeStepDuration(Duration duration) {
  final Duration shownDuration = duration.isNegative
      ? Duration.zero
      : duration;
  final int minutes = shownDuration.inMinutes;
  final int seconds = shownDuration.inSeconds % Duration.secondsPerMinute;

  if (minutes == 0) {
    return '$seconds s';
  }
  if (seconds == 0) {
    return '$minutes min';
  }
  return '$minutes min $seconds s';
}

String describeWholeMinutes(Duration duration) {
  final int minutes = duration.inMinutes < 1 ? 1 : duration.inMinutes;

  return '$minutes min';
}
