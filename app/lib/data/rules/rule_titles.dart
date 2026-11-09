import 'package:agent_orchestration/data/repository/people_facing_refusal.dart';
import 'package:agent_orchestration/data/rules/unicode_white_space.dart';

void requireRuleTitle(String title) {
  if (trimUnicodeWhiteSpace(title).isEmpty) {
    throw PeopleFacingRefusal('Write the rule');
  }
}
