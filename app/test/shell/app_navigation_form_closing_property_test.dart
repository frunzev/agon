import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';
import 'package:agent_orchestration/shell/app_section.dart';

import '../support/random_inputs.dart';
import 'app_navigation_form_stacks.dart';

void main() {
  test('test_close_form_property_lands_where_the_new_page_was_opened', () {
    final Random random = seededRandom(5310401);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack stack = randomFormStack(random);
      final AppNavigation navigation = openFormStack(stack);

      navigation.closeForm();

      expect(navigation.routes, stack.below, reason: '$stack');
      expect(navigation.currentRoute, stack.below.last);
    }
  });

  test('test_close_form_property_notifies_listeners_once', () {
    final Random random = seededRandom(5310402);

    for (int i = 0; i < propertyIterations; i += 1) {
      final AppNavigation navigation = openFormStack(randomFormStack(random));
      final NotificationCounter counter = listenForNotifications(navigation);

      navigation.closeForm();

      expect(counter.count, 1);
    }
  });

  test('test_close_form_property_never_closes_the_only_page', () {
    final Random random = seededRandom(5310403);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack stack = randomFormStack(random);
      final AppRoute onlyPage = pickOne(random, listFormStackRoutes(stack));
      final AppNavigation navigation = AppNavigation(initialRoute: onlyPage);
      final NotificationCounter counter = listenForNotifications(navigation);

      expect(navigation.closeForm, throwsStateError);

      expect(navigation.routes, <AppRoute>[onlyPage]);
      expect(counter.count, 0);
    }
  });

  test('test_close_saved_form_property_closes_like_cancel_while_shown', () {
    final Random random = seededRandom(5310404);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack stack = randomFormStack(random);
      final AppNavigation saving = openFormStack(stack);
      final AppNavigation cancelling = openFormStack(stack);
      final NotificationCounter counter = listenForNotifications(saving);

      saving.closeSavedForm(savedForm: stack.form);
      cancelling.closeForm();

      expect(saving.routes, cancelling.routes);
      expect(saving.routes, stack.below);
      expect(counter.count, 1);
    }
  });

  test('test_close_saved_form_property_a_person_who_moved_on_stays', () {
    final Random random = seededRandom(5310405);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack stack = randomFormStack(random);
      final AppNavigation navigation = openFormStack(stack);
      moveOnFromForm(random, navigation);
      final List<AppRoute> wentTo = navigation.routes;
      final NotificationCounter counter = listenForNotifications(navigation);

      navigation.closeSavedForm(savedForm: stack.form);

      expect(navigation.routes, wentTo, reason: '$stack');
      expect(counter.count, 0);
    }
  });

  test('test_close_saved_form_property_late_saves_never_empty_the_stack', () {
    final Random random = seededRandom(5310406);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack stack = randomFormStack(random);
      final AppNavigation navigation = openFormStack(stack);
      final int lateSaveCount = 1 + random.nextInt(4);
      if (random.nextBool()) {
        moveOnFromForm(random, navigation);
      }

      for (int save = 0; save < lateSaveCount; save += 1) {
        navigation.closeSavedForm(savedForm: stack.form);
      }

      expect(navigation.routes, isNotEmpty);
      expect(navigation.routes.first, isA<SectionRoute>());
    }
  });

  test('test_replace_saved_form_property_shows_the_destination_above', () {
    final Random random = seededRandom(5310407);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack stack = randomFormStack(random);
      final AppNavigation navigation = openFormStack(stack);
      final AppRoute destination = randomPageBelowForm(random);

      navigation.replaceSavedForm(
        savedForm: stack.form,
        destination: destination,
      );

      expect(navigation.routes, <AppRoute>[...stack.below, destination]);
    }
  });

  test('test_replace_saved_form_property_a_person_who_moved_on_stays', () {
    final Random random = seededRandom(5310408);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack stack = randomFormStack(random);
      final AppNavigation navigation = openFormStack(stack);
      moveOnFromForm(random, navigation);
      final List<AppRoute> wentTo = navigation.routes;
      final NotificationCounter counter = listenForNotifications(navigation);

      navigation.replaceSavedForm(
        savedForm: stack.form,
        destination: randomPageBelowForm(random),
      );

      expect(navigation.routes, wentTo);
      expect(counter.count, 0);
    }
  });

  test('test_replace_saved_form_property_run_windows_refuse_other_pages', () {
    final Random random = seededRandom(5310409);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId runId = RunId('run-${random.nextInt(9)}');
      final AppNavigation navigation = AppNavigation.limitedToRunPages(
        runId: runId,
      );
      final AppRoute destination = SectionRoute(
        pickOne(random, AppSection.values),
      );

      expect(
        () => navigation.replaceSavedForm(
          savedForm: navigation.currentRoute,
          destination: destination,
        ),
        throwsStateError,
      );
      expect(navigation.routes, <AppRoute>[TaskRunRoute(runId)]);
    }
  });

  test('test_open_section_after_saved_form_property_shows_only_it', () {
    final Random random = seededRandom(5310410);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack stack = randomFormStack(random);
      final AppNavigation navigation = openFormStack(stack);
      final SectionRoute section = SectionRoute(
        pickOne(random, AppSection.values),
      );
      final NotificationCounter counter = listenForNotifications(navigation);

      navigation.openSectionAfterSavedForm(
        savedForm: stack.form,
        sectionRoute: section,
      );

      expect(navigation.routes, <AppRoute>[section]);
      expect(counter.count, 1);
    }
  });

  test('test_open_section_after_saved_form_property_moved_on_stays', () {
    final Random random = seededRandom(5310411);

    for (int i = 0; i < propertyIterations; i += 1) {
      final FormStack stack = randomFormStack(random);
      final AppNavigation navigation = openFormStack(stack);
      moveOnFromForm(random, navigation);
      final List<AppRoute> wentTo = navigation.routes;
      final NotificationCounter counter = listenForNotifications(navigation);

      navigation.openSectionAfterSavedForm(
        savedForm: stack.form,
        sectionRoute: SectionRoute(pickOne(random, AppSection.values)),
      );

      expect(navigation.routes, wentTo);
      expect(counter.count, 0);
    }
  });

  test('test_open_section_after_saved_form_property_run_windows_refuse', () {
    final Random random = seededRandom(5310412);

    for (int i = 0; i < propertyIterations; i += 1) {
      final RunId runId = RunId('run-${random.nextInt(9)}');
      final AppNavigation navigation = AppNavigation.limitedToRunPages(
        runId: runId,
      );

      expect(
        () => navigation.openSectionAfterSavedForm(
          savedForm: navigation.currentRoute,
          sectionRoute: SectionRoute(pickOne(random, AppSection.values)),
        ),
        throwsStateError,
      );
      expect(navigation.routes, <AppRoute>[TaskRunRoute(runId)]);
    }
  });
}
