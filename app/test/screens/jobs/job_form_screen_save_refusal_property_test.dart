import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/app_dependencies.dart';
import 'package:agent_orchestration/data/fakes.dart';
import 'package:agent_orchestration/data/gallery/gallery_identifiers.dart';
import 'package:agent_orchestration/data/models/identifiers.dart';
import 'package:agent_orchestration/data/models/task.dart';
import 'package:agent_orchestration/data/repository/job_repository.dart';
import 'package:agent_orchestration/shell/app_navigation.dart';
import 'package:agent_orchestration/shell/app_route.dart';

import '../../support/app_harness.dart';
import '../support/planned_refusal.dart';
import '../support/refused_action_properties.dart';
import 'jobs_scene.dart';

const String _saveJobLabel = 'Save job';

final class _SaveRefusingJobRepository implements JobRepository {
  _SaveRefusingJobRepository({required this.stored, required this.refusal});

  final JobRepository stored;
  final PlannedRefusal refusal;

  @override
  void addListener(VoidCallback listener) => stored.addListener(listener);

  @override
  void removeListener(VoidCallback listener) {
    stored.removeListener(listener);
  }

  @override
  List<Task> listJobs() => stored.listJobs();

  @override
  Task findJob(TaskId jobId) => stored.findJob(jobId);

  @override
  Future<Task> createJob(JobDraft draft) {
    return refusal.refuseOr(() => stored.createJob(draft));
  }

  @override
  Future<Task> updateJob(TaskId jobId, JobDraft draft) {
    return refusal.refuseOr(() => stored.updateJob(jobId, draft));
  }

  @override
  Future<void> deleteJob(TaskId jobId) => stored.deleteJob(jobId);
}

RefusedActionCase _buildSaveJobCase() {
  late AppNavigation navigation;

  return RefusedActionCase(
    functionName: 'job_form_screen_save_job',
    actionLabel: _saveJobLabel,
    place: RefusalPlace.bannerOnPage,
    openPage: (tester, {required size, required refusal}) async {
      final AppDependencies gallery = buildGalleryDependencies();
      navigation = await pumpApp(
        tester,
        size: size,
        route: jobsRoute,
        dependencies: replaceRepositories(
          gallery,
          jobRepository: _SaveRefusingJobRepository(
            stored: gallery.jobRepository,
            refusal: refusal,
          ),
        ),
      );
      navigation.openRoute(
        const EditJobRoute(GalleryTaskIds.updateDependencies),
      );
      await pumpFrames(tester);
    },
    performAction: (tester) => tapButtonLabelled(tester, _saveJobLabel),
    expectSucceeded: (tester) {
      expect(navigation.routes, const <AppRoute>[jobsRoute]);
    },
  );
}

void main() {
  registerRefusedActionProperties(_buildSaveJobCase(), seed: 1021901);
}
