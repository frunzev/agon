import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/item_draft.dart';
import 'package:agent_orchestration/screens/new_items/new_item_texts.dart';
import 'package:agent_orchestration/shell/draft_kind_sections.dart';

import '../../bridge/support/hostile_texts.dart';
import '../../presentation/support/plain_shown_text.dart';
import '../../support/random_inputs.dart';

const String _designFolder = '../docs/design';

const Map<String, String> _designPageOfText = <String, String>{
  newItemHint: 'task-new-chat',
  draftingSummary: 'task-drafting',
  askedSectionTitle: 'task-drafting',
  stopDraftingLabel: 'task-drafting',
  reviewSummary: 'task-review',
  changeHint: 'task-review',
  changeFieldLabel: 'task-review',
  approveLabel: 'task-review',
  cancelReviewLabel: 'task-review',
  sendChangeLabel: 'task-review',
  draftProblemsTitle: 'task-review-problem',
  draftProblemsNote: 'task-review-problem',
  backToWordsLabel: 'task-drafting-failed',
  fillInFormLabel: 'task-new-chat-no-runner',
  noRunnerTitle: 'task-new-chat-no-runner',
  noRunnerText: 'task-new-chat-no-runner',
};

const List<String> _labels = <String>[
  draftingSummary,
  startingDraftText,
  askedSectionTitle,
  changeFieldLabel,
  draftProblemsTitle,
  approveLabel,
  cancelReviewLabel,
  sendChangeLabel,
  stopDraftingLabel,
  fillInFormLabel,
  backToWordsLabel,
  backToDraftLabel,
  approvalFailedTitle,
  noRunnerTitle,
];

const List<String> _sentences = <String>[
  newItemHint,
  reviewSummary,
  changeHint,
  draftProblemsNote,
  emptyWishProblem,
  unexplainedDraftProblem,
  noRunnerText,
];

String _readDesignMarkup(String pageName) {
  return File('$_designFolder/$pageName.html').readAsStringSync();
}

NewItemTexts _randomTexts(Random random) {
  return NewItemTexts(
    kindName: randomHostileText(random),
    sectionLabel: randomHostileText(random),
    question: randomHostileText(random),
    changeExample: randomHostileText(random),
  );
}

void main() {
  test('test_describe_new_item_property_matches_the_design_pages', () {
    for (final DraftKind kind in DraftKind.values) {
      final NewItemTexts texts = describeNewItem(kind);
      final String requestPage = readDesignPageText('${kind.name}-new-chat');
      final String reviewMarkup = _readDesignMarkup('${kind.name}-review');

      expect(requestPage, contains(' ${texts.sectionLabel} '));
      expect(requestPage, contains(' ${texts.pageTitle} '));
      expect(requestPage, contains(' ${texts.question} '));
      expect(requestPage, contains(' ${texts.draftLabel} '));
      expect(reviewMarkup, contains('placeholder="${texts.changeExample}"'));
    }
  });

  test('test_describe_new_item_property_kinds_never_share_texts', () {
    final List<NewItemTexts> described = <NewItemTexts>[
      for (final DraftKind kind in DraftKind.values) describeNewItem(kind),
    ];
    final int kindCount = DraftKind.values.length;

    expect(
      described.map((NewItemTexts t) => t.kindName).toSet(),
      hasLength(kindCount),
    );
    expect(
      described.map((NewItemTexts t) => t.sectionLabel).toSet(),
      hasLength(kindCount),
    );
    expect(
      described.map((NewItemTexts t) => t.question).toSet(),
      hasLength(kindCount),
    );
    expect(
      described.map((NewItemTexts t) => t.changeExample).toSet(),
      hasLength(kindCount),
    );
  });

  test('test_describe_new_item_property_is_total_and_stable', () {
    final Random random = seededRandom(11401);
    for (int i = 0; i < propertyIterations; i += 1) {
      final DraftKind kind = pickOne(random, DraftKind.values);

      final NewItemTexts first = describeNewItem(kind);
      final NewItemTexts second = describeNewItem(kind);

      expect(first.kindName, kind.name);
      expect(first.sectionLabel, findDraftKindSection(kind).label);
      expect(second.question, first.question);
      expect(second.changeExample, first.changeExample);
      expect(first.question, endsWith('?'));
    }
  });

  test('test_new_item_texts_constructor_property_keeps_every_field', () {
    final Random random = seededRandom(11402);
    for (int i = 0; i < propertyIterations; i += 1) {
      final String kindName = randomHostileText(random);
      final String sectionLabel = randomHostileText(random);
      final String question = randomHostileText(random);
      final String changeExample = randomHostileText(random);

      final NewItemTexts texts = NewItemTexts(
        kindName: kindName,
        sectionLabel: sectionLabel,
        question: question,
        changeExample: changeExample,
      );

      expect(texts.kindName, kindName);
      expect(texts.sectionLabel, sectionLabel);
      expect(texts.question, question);
      expect(texts.changeExample, changeExample);
    }
  });

  test('test_new_item_texts_constructor_property_copies_round_trip', () {
    for (final DraftKind kind in DraftKind.values) {
      final NewItemTexts described = describeNewItem(kind);

      final NewItemTexts copy = NewItemTexts(
        kindName: described.kindName,
        sectionLabel: described.sectionLabel,
        question: described.question,
        changeExample: described.changeExample,
      );

      expect(copy.pageTitle, described.pageTitle);
      expect(copy.draftLabel, described.draftLabel);
      expect(copy.question, described.question);
      expect(copy.changeExample, described.changeExample);
    }
  });

  test('test_new_item_texts_constructor_property_fields_stay_independent', () {
    final Random random = seededRandom(11403);
    for (int i = 0; i < propertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);
      final NewItemTexts other = _randomTexts(random);

      final NewItemTexts mixed = NewItemTexts(
        kindName: texts.kindName,
        sectionLabel: other.sectionLabel,
        question: other.question,
        changeExample: other.changeExample,
      );

      expect(mixed.pageTitle, texts.pageTitle);
      expect(mixed.draftLabel, texts.draftLabel);
      expect(mixed.question, other.question);
    }
  });

  test('test_page_title_property_is_new_and_the_kind_name', () {
    final Random random = seededRandom(11404);
    for (int i = 0; i < propertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);

      expect(texts.pageTitle, 'New ${texts.kindName}');
      expect(texts.pageTitle, endsWith(texts.kindName));
      expect(texts.pageTitle.length, texts.kindName.length + 4);
    }
  });

  test('test_page_title_property_heads_every_design_page_of_the_kind', () {
    for (final DraftKind kind in DraftKind.values) {
      final String pageTitle = describeNewItem(kind).pageTitle;

      for (final String page in <String>['new-chat', 'review']) {
        final String pageText = readDesignPageText('${kind.name}-$page');
        expect(pageText, contains(' $pageTitle '), reason: page);
      }
    }
  });

  test('test_page_title_property_reads_as_a_plain_label', () {
    for (final DraftKind kind in DraftKind.values) {
      final NewItemTexts texts = describeNewItem(kind);

      expectPlainLabel(texts.pageTitle);
      expect(texts.pageTitle, isNot(texts.draftLabel));
    }
  });

  test('test_draft_label_property_is_draft_and_the_kind_name', () {
    final Random random = seededRandom(11405);
    for (int i = 0; i < propertyIterations; i += 1) {
      final NewItemTexts texts = _randomTexts(random);

      expect(texts.draftLabel, 'Draft ${texts.kindName}');
      expect(texts.draftLabel, endsWith(texts.kindName));
      expect(texts.draftLabel, isNot(texts.pageTitle));
    }
  });

  test('test_draft_label_property_is_the_design_button', () {
    for (final DraftKind kind in DraftKind.values) {
      final String markup = readDesignPageText('${kind.name}-new-chat');

      expect(markup, contains(' ${describeNewItem(kind).draftLabel} '));
    }
  });

  test('test_draft_label_property_reads_as_a_plain_label', () {
    for (final DraftKind kind in DraftKind.values) {
      final NewItemTexts texts = describeNewItem(kind);

      expectPlainLabel(texts.draftLabel);
      expect(texts.draftLabel.split(' '), hasLength(2));
    }
  });

  test('test_new_item_texts_property_design_wording_is_kept', () {
    for (final MapEntry<String, String> entry in _designPageOfText.entries) {
      final String pageText = readDesignPageText(entry.value);

      expect(pageText, contains(' ${entry.key} '), reason: entry.value);
    }
  });

  test('test_new_item_texts_property_labels_and_sentences_read_plainly', () {
    for (final String label in _labels) {
      expectPlainLabel(label);
    }
    for (final String sentence in _sentences) {
      expectPlainSentences(sentence);
    }
  });

  test('test_new_item_texts_property_every_text_is_distinct', () {
    final List<String> texts = <String>[..._labels, ..._sentences];

    expect(texts.toSet(), hasLength(texts.length));
    expect(_designPageOfText.keys.toSet().difference(texts.toSet()), isEmpty);
  });
}
