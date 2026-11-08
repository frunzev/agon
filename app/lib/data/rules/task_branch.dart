import 'package:agent_orchestration/data/models/identifiers.dart';

const String _branchPrefix = 'task/';
const String _fallbackSlug = 'task';
const String _slugSeparator = '-';
const String _runNumberMarker = '-run-';
const int _maximumSlugLength = 40;
final RegExp _nonAlphanumericRunPattern = RegExp('[^A-Za-z0-9]+');
final RegExp _leadingDashPattern = RegExp('^-+');
final RegExp _trailingDashPattern = RegExp(r'-+$');

String slugifyTaskTitle(String title) {
  final String dashed = title.replaceAll(
    _nonAlphanumericRunPattern,
    _slugSeparator,
  );
  final String lowered = dashed.toLowerCase();
  final String withoutLeadingDash = lowered.replaceFirst(
    _leadingDashPattern,
    '',
  );

  String shortened = withoutLeadingDash;
  if (shortened.length > _maximumSlugLength) {
    shortened = shortened.substring(0, _maximumSlugLength);
  }
  final String slug = shortened.replaceFirst(_trailingDashPattern, '');

  if (slug.isEmpty) {
    return _fallbackSlug;
  }
  return slug;
}

String _describeSimpleTaskId(TaskId taskId) {
  return taskId.value.replaceAll(_slugSeparator, '').toLowerCase();
}

String describeTaskBranch({required String title, required TaskId taskId}) {
  final String slug = slugifyTaskTitle(title);
  final String simpleTaskId = _describeSimpleTaskId(taskId);
  return '$_branchPrefix$slug$_slugSeparator$simpleTaskId';
}

String describeJobRunBranch({
  required String title,
  required TaskId taskId,
  required int runNumber,
}) {
  final String taskBranch = describeTaskBranch(title: title, taskId: taskId);
  return '$taskBranch$_runNumberMarker$runNumber';
}
