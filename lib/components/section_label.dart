import 'package:flutter/material.dart';

/// Section heading helper (uppercase label with tracking)
class SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const SectionLabel(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color,
      ),
    );
  }
}
