import 'support/all_command_member_rows.dart';
import 'support/command_member_properties.dart';

const int _firstSeed = 9470000;
const int _seedsPerRow = 3;

void main() {
  for (int i = 0; i < allCommandMemberRows.length; i += 1) {
    testCommandConstructorProperties(
      allCommandMemberRows[i],
      _firstSeed + i * _seedsPerRow,
    );
  }
}
