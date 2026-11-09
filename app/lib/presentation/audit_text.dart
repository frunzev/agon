import 'package:agent_orchestration/presentation/count_text.dart';
import 'package:agent_orchestration/presentation/time_phrases.dart';

const String _entrySingular = 'entry';
const String _entryPlural = 'entries';

String describeAuditTime(DateTime at, DateTime now) {
  final bool isSameDay = countCalendarDaysBetween(at, now) == 0;

  if (isSameDay) {
    return formatClockTime(at);
  }
  return describeTimeSince(at, now);
}

String describeEntryCount(int count) {
  return describeCount(count, singular: _entrySingular, plural: _entryPlural);
}
