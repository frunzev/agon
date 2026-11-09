import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_colors.dart';
import 'package:agent_orchestration/theme/app_typography.dart';

final TextStyle _problemStyle = AppTextStyles.small.copyWith(
  color: AppColors.danger,
);

class FieldProblemText extends StatelessWidget {
  const FieldProblemText({required this.problem, super.key});

  final String problem;

  @override
  Widget build(BuildContext context) {
    return Text(problem, style: _problemStyle);
  }
}
