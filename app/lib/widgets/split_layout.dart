import 'package:flutter/widgets.dart';

import 'package:agent_orchestration/theme/app_spacing.dart';
import 'package:agent_orchestration/theme/layout_size.dart';

enum SplitProportion {
  narrowStart(2, 3),
  wideStart(3, 2);

  const SplitProportion(this.startFlex, this.endFlex);

  final int startFlex;
  final int endFlex;
}

class SplitLayout extends StatefulWidget {
  const SplitLayout({
    required this.start,
    required this.end,
    super.key,
    this.proportion = SplitProportion.narrowStart,
  });

  final Widget start;
  final Widget end;
  final SplitProportion proportion;

  @override
  State<SplitLayout> createState() => _SplitLayoutState();
}

class _SplitLayoutState extends State<SplitLayout> {
  final GlobalKey _startKey = GlobalKey();
  final GlobalKey _endKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final Widget start = KeyedSubtree(key: _startKey, child: widget.start);
    final Widget end = KeyedSubtree(key: _endKey, child: widget.end);

    if (!LayoutSize.of(context).isLarge) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          start,
          const SizedBox(height: AppSpacing.space6),
          end,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: widget.proportion.startFlex, child: start),
        const SizedBox(width: AppSpacing.space6),
        Expanded(flex: widget.proportion.endFlex, child: end),
      ],
    );
  }
}
