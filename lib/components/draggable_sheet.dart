import 'package:flutter/material.dart';

/// Bottom sheet yang bisa ditutup dengan menarik ke bawah dari area mana pun,
/// gaya komentar Instagram.
///
/// - Kalau [scrollable] true (isi punya ScrollView), tarik ke bawah hanya
///   menggerakkan sheet saat konten sudah di posisi paling atas (overscroll).
/// - Area di luar ScrollView (handle, padding) selalu bisa dipakai tarik.
class DraggableSheet extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;
  final bool scrollable;

  const DraggableSheet({
    super.key,
    required this.child,
    required this.onDismiss,
    this.scrollable = false,
  });

  @override
  State<DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<DraggableSheet>
    with SingleTickerProviderStateMixin {
  static const _maxDrag = 420.0;
  static const _dismissThreshold = 140.0;

  late final AnimationController _ctrl;
  double _dy = 0;
  double _lastVel = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      value: 1,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double get _offset => (1 - _ctrl.value) * _maxDrag;

  void _update(double delta) {
    _dy = (_dy + delta).clamp(0.0, _maxDrag);
    _ctrl.value = 1 - (_dy / _maxDrag);
  }

  void _settle(double velocity) {
    if (_dy > _dismissThreshold || velocity > 700) {
      _ctrl
          .animateTo(0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInCubic)
          .whenComplete(() {
        if (mounted) widget.onDismiss();
      });
      return;
    }
    _dy = 0;
    _lastVel = 0;
    _ctrl.animateBack(1, curve: Curves.easeOutCubic);
  }

  bool _handleScrollNotification(ScrollNotification n) {
    if (n is OverscrollNotification) {
      final atTop = n.metrics.pixels <= 0 && n.metrics.extentBefore <= 0;
      if (atTop && n.overscroll < 0 && n.dragDetails != null) {
        _lastVel = n.velocity;
        _update(-n.overscroll);
      }
      return true;
    }
    if (n is ScrollEndNotification) {
      if (_dy > 0) _settle(_lastVel);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    Widget content = widget.child;
    if (widget.scrollable) {
      content = NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: content,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragStart: (_) {},
      onVerticalDragUpdate: (d) => _update(d.delta.dy),
      onVerticalDragEnd: (d) => _settle(d.primaryVelocity ?? 0),
      onVerticalDragCancel: () => _settle(0),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) => Transform.translate(
          offset: Offset(0, _offset),
          child: content,
        ),
      ),
    );
  }
}
