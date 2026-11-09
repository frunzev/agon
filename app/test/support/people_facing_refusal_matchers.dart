import 'package:flutter_test/flutter_test.dart';

import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';

final Matcher throwsPeopleFacingRefusal = throwsA(isA<PeopleFacingRefusal>());
