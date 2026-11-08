import 'dart:math';

import 'package:agent_orchestration/data/rules/naming.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

const String _peerScheme = 'peer';
const Set<String> _serverSchemes = <String>{'https', 'http', _peerScheme};
const String _schemeEnd = ':';
const String _webServerPart = 'server name';
const String _peerServerPart = 'server key';
const String _peerHostLabel = 'peer link';
const int _shownPeerKeyLength = 8;
const int _pairingCodeLength = 6;
const String _localHostSuffix = '.local';
const String _fallbackDeviceName = 'new-device';
const String _nameSeparator = '-';
final RegExp _pairingCodeSeparator = RegExp(
  '^(?:$unicodeWhiteSpaceCharacter|-)\$',
);
final RegExp _pairingCodeSymbol = RegExp(
  r'^[0-9a-tv-z]$',
  caseSensitive: false,
);
final RegExp _characterOutsideNames = RegExp('[^a-z0-9]+');
final RegExp _edgeSeparators = RegExp(r'^-+|-+$');

Uri? _parseServerAddress(String address) {
  final Uri? parsed = Uri.tryParse(address.trim());
  if (parsed == null || !_serverSchemes.contains(parsed.scheme)) {
    return null;
  }
  if (parsed.host.isEmpty) {
    return null;
  }
  return parsed;
}

String? _readKnownScheme(String address) {
  final int schemeEnd = address.indexOf(_schemeEnd);
  if (schemeEnd < 0) {
    return null;
  }
  final String scheme = address.substring(0, schemeEnd).toLowerCase();
  if (!_serverSchemes.contains(scheme)) {
    return null;
  }
  return scheme;
}

String _nameServerPart(String scheme) {
  if (scheme == _peerScheme) {
    return _peerServerPart;
  }
  return _webServerPart;
}

String? describeServerAddressProblem(String address) {
  final String trimmedAddress = address.trim();
  if (trimmedAddress.isEmpty) {
    return 'Enter the app server address';
  }
  if (_parseServerAddress(trimmedAddress) != null) {
    return null;
  }

  final String? scheme = _readKnownScheme(trimmedAddress);
  if (scheme == null) {
    return 'Start the address with https://, http:// or peer://';
  }
  if (Uri.tryParse(trimmedAddress) == null) {
    return 'Check the address after $scheme://';
  }
  return 'Add the ${_nameServerPart(scheme)} after $scheme://';
}

String describeServerHost(String address) {
  final Uri? parsed = _parseServerAddress(address);
  if (parsed == null) {
    return address;
  }
  if (parsed.scheme != _peerScheme) {
    return parsed.replace(userInfo: '').authority;
  }
  final String key = parsed.host;
  final int shownLength = min(key.length, _shownPeerKeyLength);
  return '$_peerHostLabel ${key.substring(0, shownLength)}';
}

String? describePairingCodeProblem(String code) {
  int symbolCount = 0;
  for (final int rune in code.runes) {
    final String character = String.fromCharCode(rune);
    if (_pairingCodeSeparator.hasMatch(character)) {
      continue;
    }
    if (!_pairingCodeSymbol.hasMatch(character)) {
      return 'A pairing code cannot contain "$character"';
    }
    symbolCount += 1;
  }

  if (symbolCount != _pairingCodeLength) {
    return 'A pairing code has six characters';
  }
  return null;
}

String? describeJoinInputProblem({
  required String? serverAddress,
  required String code,
}) {
  final String? codeProblem = describePairingCodeProblem(code);
  if (codeProblem != null || serverAddress == null) {
    return codeProblem;
  }
  return describeServerAddressProblem(serverAddress);
}

void refuseBadJoinInput({
  required String? serverAddress,
  required String code,
  required String deviceName,
}) {
  final String? inputProblem = describeJoinInputProblem(
    serverAddress: serverAddress,
    code: code,
  );
  if (inputProblem != null) {
    throw FormatException(inputProblem, code);
  }
  final String? nameProblem = describeNameProblem(deviceName);
  if (nameProblem != null) {
    throw ArgumentError(nameProblem);
  }
}

void refuseBadHostedAccountNames({
  required String workspaceName,
  required String deviceName,
}) {
  final String? problem =
      describeNameProblem(deviceName) ?? describeNameProblem(workspaceName);
  if (problem != null) {
    throw ArgumentError(problem);
  }
}

String suggestDeviceName(String hostName) {
  final String lowercase = hostName.trim().toLowerCase();
  final String withoutSuffix = lowercase.endsWith(_localHostSuffix)
      ? lowercase.substring(0, lowercase.length - _localHostSuffix.length)
      : lowercase;
  final String dashed = withoutSuffix
      .replaceAll(_characterOutsideNames, _nameSeparator)
      .replaceAll(_edgeSeparators, '');
  final String shortened = dashed.length > nameMaximumLength
      ? dashed.substring(0, nameMaximumLength).replaceAll(_edgeSeparators, '')
      : dashed;

  if (shortened.isEmpty) {
    return _fallbackDeviceName;
  }
  return shortened;
}
