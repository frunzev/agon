import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/models/audit.dart';
import 'package:agent_orchestration/data/repository/audit_repository.dart';

import '../../support/random_inputs.dart';
import '../node_backed/support/node_backed_audit_rig.dart';
import 'support/contract_step_failures.dart';

const String _typePrefix = 'test_audit_repository';
const int _chainIterations = 60;
const int _largestAppendRounds = 4;

typedef _NamedAuditRepository = ({String name, AuditRepository repository});

typedef _EntryProjection = ({int index, String previousHash, String hash});

typedef _SummaryProjection = ({int entryCount, String headHash});

enum _Tampering { previousHash, oldestPreviousHash, renumber }

const List<_Tampering> _singleEntryTamperings = <_Tampering>[
  _Tampering.previousHash,
  _Tampering.oldestPreviousHash,
];

Future<List<_NamedAuditRepository>> _buildBoth(
  Random random, {
  required bool isTampered,
}) async {
  final AuditRig rig = AuditRig();
  final int rounds = random.nextInt(_largestAppendRounds);
  for (int i = 0; i < rounds; i += 1) {
    rig.appendLinkedEntries(random);
  }
  if (isTampered) {
    rig.node.appendAuditEntry(random);
    _tamperNodeChain(random, rig);
  }
  await rig.repository.load();

  return <_NamedAuditRepository>[
    (
      name: 'fake',
      repository: FakeAuditRepository(entries: rig.repository.listEntries()),
    ),
    (name: 'node backed', repository: rig.repository),
  ];
}

void _tamperNodeChain(Random random, AuditRig rig) {
  final List<Map<String, Object?>> chain = rig.node.auditChain;
  final int position = random.nextInt(chain.length);
  final Map<String, Object?> entry = chain[position];
  final List<_Tampering> tamperings = chain.length == 1
      ? _singleEntryTamperings
      : _Tampering.values;
  switch (pickOne(random, tamperings)) {
    case _Tampering.previousHash:
      entry['previous_hash'] = 'tampered-${random.nextInt(1 << 30)}';
    case _Tampering.oldestPreviousHash:
      chain.first['previous_hash'] = 'tampered-${random.nextInt(1 << 30)}';
    case _Tampering.renumber:
      entry['index'] = chain.length + random.nextInt(4);
  }
  rig.node.isAuditIntact = false;
}

List<_EntryProjection> _projectEntries(List<AuditEntry> entries) {
  final List<_EntryProjection> projections = <_EntryProjection>[];
  for (final AuditEntry entry in entries) {
    projections.add((
      index: entry.index,
      previousHash: entry.previousHash,
      hash: entry.hash,
    ));
  }
  return projections;
}

_SummaryProjection _projectSummary(ChainSummary summary) {
  return (entryCount: summary.entryCount, headHash: summary.headHash);
}

void main() {
  test('${_typePrefix}_list_entries_property_every_implementation_lists_'
      'the_same_chain', () async {
    final Random random = seededRandom(84301);
    for (int i = 0; i < _chainIterations; i += 1) {
      final List<_NamedAuditRepository> implementations = await _buildBoth(
        random,
        isTampered: random.nextBool(),
      );
      final List<_EntryProjection> expected = _projectEntries(
        implementations.last.repository.listEntries(),
      );

      for (final _NamedAuditRepository implementation in implementations) {
        expect(
          _projectEntries(implementation.repository.listEntries()),
          orderedEquals(expected),
          reason: implementation.name,
        );
      }
    }
  });

  test('${_typePrefix}_list_entries_property_an_intact_chain_is_listed_'
      'newest_first_and_linked', () async {
    final Random random = seededRandom(84302);
    for (int i = 0; i < _chainIterations; i += 1) {
      final List<_NamedAuditRepository> implementations = await _buildBoth(
        random,
        isTampered: false,
      );

      for (final _NamedAuditRepository implementation in implementations) {
        final List<AuditEntry> entries = implementation.repository
            .listEntries();
        for (int position = 1; position < entries.length; position += 1) {
          final AuditEntry newer = entries[position - 1];
          final AuditEntry older = entries[position];
          expect(newer.index, older.index + 1, reason: implementation.name);
          expect(newer.previousHash, older.hash, reason: implementation.name);
        }
        if (entries.isNotEmpty) {
          expect(entries.last.index, 0, reason: implementation.name);
          expect(entries.last.previousHash, genesisHash);
        }
      }
    }
  });

  test('${_typePrefix}_list_entries_property_callers_cannot_change_the_'
      'stored_chain', () async {
    final Random random = seededRandom(84303);
    for (int i = 0; i < _chainIterations; i += 1) {
      final List<_NamedAuditRepository> implementations = await _buildBoth(
        random,
        isTampered: random.nextBool(),
      );

      for (final _NamedAuditRepository implementation in implementations) {
        final List<AuditEntry> listed = implementation.repository
            .listEntries();
        final List<_EntryProjection> before = _projectEntries(listed);

        final Object? failure = await findStepFailure(() async {
          listed.clear();
        });

        expect(failure, isA<UnsupportedError>(), reason: implementation.name);
        expect(
          _projectEntries(implementation.repository.listEntries()),
          orderedEquals(before),
        );
      }
    }
  });

  test('${_typePrefix}_verify_chain_property_an_intact_chain_counts_every_'
      'listed_entry_and_ends_at_the_head', () async {
    final Random random = seededRandom(84304);
    for (int i = 0; i < _chainIterations; i += 1) {
      final List<_NamedAuditRepository> implementations = await _buildBoth(
        random,
        isTampered: false,
      );

      for (final _NamedAuditRepository implementation in implementations) {
        final ChainSummary summary = await implementation.repository
            .verifyChain();
        final List<AuditEntry> entries = implementation.repository
            .listEntries();

        expect(
          summary.entryCount,
          entries.length,
          reason: implementation.name,
        );
        final String expectedHead = entries.isEmpty
            ? genesisHash
            : entries.first.hash;
        expect(summary.headHash, expectedHead, reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_verify_chain_property_every_implementation_refuses_'
      'a_tampered_chain', () async {
    final Random random = seededRandom(84305);
    for (int i = 0; i < _chainIterations; i += 1) {
      final List<_NamedAuditRepository> implementations = await _buildBoth(
        random,
        isTampered: true,
      );

      for (final _NamedAuditRepository implementation in implementations) {
        final Object? failure = await findStepFailure(
          implementation.repository.verifyChain,
        );

        expect(failure, isA<StateError>(), reason: implementation.name);
      }
    }
  });

  test('${_typePrefix}_verify_chain_property_verifying_twice_agrees_and_'
      'keeps_the_chain', () async {
    final Random random = seededRandom(84306);
    for (int i = 0; i < _chainIterations; i += 1) {
      final List<_NamedAuditRepository> implementations = await _buildBoth(
        random,
        isTampered: false,
      );
      final List<_SummaryProjection> firstSummaries = <_SummaryProjection>[];

      for (final _NamedAuditRepository implementation in implementations) {
        final AuditRepository repository = implementation.repository;
        final List<_EntryProjection> before = _projectEntries(
          repository.listEntries(),
        );
        final ChainSummary first = await repository.verifyChain();
        final ChainSummary second = await repository.verifyChain();

        expect(_projectSummary(second), _projectSummary(first));
        expect(_projectEntries(repository.listEntries()), before);
        firstSummaries.add(_projectSummary(first));
      }

      expect(firstSummaries.toSet(), hasLength(1));
    }
  });
}
