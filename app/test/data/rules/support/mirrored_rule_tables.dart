import 'dart:convert';
import 'dart:io';

const String _fixtureFolder =
    '../rust/crates/orchestration-core/tests/fixtures/';
const String _namingCasesFile = 'naming_cases.json';
const String _answerCasesFile = 'person_answer_cases.json';
const String _folderCasesFile = 'local_folder_address_cases.json';

typedef JsonObject = Map<String, Object?>;

final class SharedNamingCase {
  const SharedNamingCase({
    required this.name,
    required this.problem,
    required this.projectName,
  });

  final String name;
  final String? problem;
  final String projectName;
}

final class SharedAnswerCase {
  const SharedAnswerCase({
    required this.answer,
    required this.choices,
    required this.choice,
    required this.isBlank,
  });

  final String answer;
  final List<String> choices;
  final String? choice;
  final bool isBlank;
}

final class SharedFolderAddressCase {
  const SharedFolderAddressCase({
    required this.address,
    required this.deviceId,
    required this.path,
    required this.canonical,
  });

  final String address;
  final String? deviceId;
  final String? path;
  final String? canonical;
}

final class SharedFolderRenderingCase {
  const SharedFolderRenderingCase({
    required this.deviceId,
    required this.path,
    required this.address,
  });

  final String deviceId;
  final String path;
  final String? address;
}

Object? _readFixture(String fileName) {
  final String text = File('$_fixtureFolder$fileName').readAsStringSync();
  return jsonDecode(text);
}

List<JsonObject> _readObjects(Object? entries) {
  if (entries is! List<Object?>) {
    throw FormatException('a shared rule table is not a list: $entries');
  }
  final List<JsonObject> objects = <JsonObject>[];
  for (final Object? entry in entries) {
    if (entry is! JsonObject) {
      throw FormatException('a shared rule case is not an object: $entry');
    }
    objects.add(entry);
  }
  return objects;
}

T _readField<T>(JsonObject entry, String field) {
  final Object? fieldValue = entry[field];
  if (fieldValue is! T) {
    throw FormatException('the shared case field $field is wrong', entry);
  }
  return fieldValue;
}

List<JsonObject> _readCaseList(String fileName) {
  return _readObjects(_readFixture(fileName));
}

List<String> _readTexts(JsonObject entry, String field) {
  final List<Object?> texts = _readField<List<Object?>>(entry, field);
  return <String>[for (final Object? text in texts) text! as String];
}

List<SharedNamingCase> readSharedNamingCases() {
  return <SharedNamingCase>[
    for (final JsonObject entry in _readCaseList(_namingCasesFile))
      SharedNamingCase(
        name: _readField<String>(entry, 'name'),
        problem: _readField<String?>(entry, 'problem'),
        projectName: _readField<String>(entry, 'project_name'),
      ),
  ];
}

List<SharedAnswerCase> readSharedAnswerCases() {
  return <SharedAnswerCase>[
    for (final JsonObject entry in _readCaseList(_answerCasesFile))
      SharedAnswerCase(
        answer: _readField<String>(entry, 'answer'),
        choices: _readTexts(entry, 'choices'),
        choice: _readField<String?>(entry, 'choice'),
        isBlank: _readField<bool>(entry, 'is_blank'),
      ),
  ];
}

JsonObject _readFolderTable() {
  final Object? table = _readFixture(_folderCasesFile);
  if (table is! JsonObject) {
    throw FormatException('the shared folder table is not an object: $table');
  }
  return table;
}

List<SharedFolderAddressCase> readSharedFolderAddressCases() {
  final Object? entries = _readFolderTable()['addresses'];
  return <SharedFolderAddressCase>[
    for (final JsonObject entry in _readObjects(entries))
      SharedFolderAddressCase(
        address: _readField<String>(entry, 'address'),
        deviceId: _readField<String?>(entry, 'device_id'),
        path: _readField<String?>(entry, 'path'),
        canonical: _readField<String?>(entry, 'canonical'),
      ),
  ];
}

List<SharedFolderRenderingCase> readSharedFolderRenderingCases() {
  final Object? entries = _readFolderTable()['renderings'];
  return <SharedFolderRenderingCase>[
    for (final JsonObject entry in _readObjects(entries))
      SharedFolderRenderingCase(
        deviceId: _readField<String>(entry, 'device_id'),
        path: _readField<String>(entry, 'path'),
        address: _readField<String?>(entry, 'address'),
      ),
  ];
}
