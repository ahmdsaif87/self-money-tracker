import 'package:flutter/material.dart';

/// Sheet drag-to-close helper — mirrors src/components/useSheetDrag.ts
/// Returns a GestureDetector-driven vertical drag that dismisses on strong
/// downward drag (threshold 140px or velocity > 0.7).
class SheetDrag {
  final void Function(double dy) onMove;
  final void Function() onDismiss;
  double _startY = 0;
  double _dy = 0;

  SheetDrag({required this.onMove, required this.onDismiss});

  /// Wire into a GestureDetector with these callbacks.
  void onPanStart(DragStartDetails d) {
    _startY = d.globalPosition.dy;
    _dy = 0;
  }

  void onPanUpdate(DragUpdateDetails d) {
    _dy = d.globalPosition.dy - _startY;
    if (_dy > 0) onMove(_dy);
  }

  void onPanEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    if (_dy > 140 || velocity > 700) {
      onDismiss();
    } else {
      onMove(0); // snap back
    }
  }

  void onPanCancel() {
    onMove(0);
  }
}

/// Widget wrapper that adds drag-to-dismiss behavior to a child (bottom sheet).
class DragToDismiss extends StatelessWidget {
  final Widget child;
  final ValueChanged<double> onDrag;
  final VoidCallback onDismiss;

  const DragToDismiss({
    super.key,
    required this.child,
    required this.onDrag,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final drag = SheetDrag(onMove: onDrag, onDismiss: onDismiss);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: drag.onPanStart,
      onPanUpdate: drag.onPanUpdate,
      onPanEnd: drag.onPanEnd,
      onPanCancel: drag.onPanCancel,
      child: child,
    );
  }
}

/// Helper to colorize a hex string with alpha (like hexA in RN).
Color hexA(String hex, double alpha) {
  final clean = hex.replaceFirst('#', '');
  final value = int.tryParse(clean, radix: 16) ?? 0xE06D53;
  return Color(value).withValues(alpha: alpha);
}

Color hexColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  final value = int.tryParse(clean, radix: 16) ?? 0xE06D53;
  return Color(0xFF000000 | value);
}
