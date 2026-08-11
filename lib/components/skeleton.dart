import 'package:flutter/material.dart';

/// Skeleton loading: pulsing rounded box.
/// Use while data is loading (e.g. first fetch of transactions).
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = dark ? const Color(0xFF2A2725) : const Color(0xFFEDE7E0);
    final highlight = dark ? const Color(0xFF373330) : const Color(0xFFF6F2ED);

    return FadeTransition(
      opacity: Tween(
        begin: 0.55,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            colors: [base, highlight, base],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
      ),
    );
  }
}

/// Convenience: a full-width transaction row skeleton.
class SkeletonTransactionRow extends StatelessWidget {
  const SkeletonTransactionRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          const SkeletonBox(width: 42, height: 42, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 140, height: 13),
                SizedBox(height: 6),
                SkeletonBox(width: 90, height: 11),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const SkeletonBox(width: 72, height: 14),
        ],
      ),
    );
  }
}

/// Convenience: dashboard skeleton (balance card + a few rows).
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: const [
        SkeletonBox(height: 24, radius: 10),
        SizedBox(height: 16),
        SkeletonBox(height: 150, radius: 20),
        SizedBox(height: 24),
        SkeletonBox(width: 120, height: 14),
        SizedBox(height: 12),
        SkeletonTransactionRow(),
        SkeletonTransactionRow(),
        SkeletonTransactionRow(),
        SkeletonTransactionRow(),
      ],
    );
  }
}

/// Convenience: transactions/reports list skeleton.
class SkeletonList extends StatelessWidget {
  final int rows;

  const SkeletonList({super.key, this.rows = 6});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        SkeletonBox(width: 140, height: 14),
        const SizedBox(height: 16),
        for (var i = 0; i < rows; i++) const SkeletonTransactionRow(),
      ],
    );
  }
}
