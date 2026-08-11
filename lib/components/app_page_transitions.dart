import 'package:flutter/material.dart';

/// Transisi route horizontal slide (gaya iOS) untuk semua halaman push.
/// Halaman baru meluncur masuk dari kanan, halaman lama bergeser ke kiri + fade.
class AppPageTransitionsBuilder extends PageTransitionsBuilder {
  const AppPageTransitionsBuilder();

  static const _forwardDuration = Duration(milliseconds: 320);
  static const _backDuration = Duration(milliseconds: 260);

  @override
  Duration get transitionDuration => _forwardDuration;
  @override
  Duration get reverseTransitionDuration => _backDuration;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    final inSlide = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(curved);

    final inFade = Tween<double>(begin: 0.4, end: 1).animate(curved);

    final secondaryCurved = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    final outSlide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-0.25, 0),
    ).animate(secondaryCurved);
    final outFade = Tween<double>(begin: 1, end: 0.7).animate(secondaryCurved);

    return SlideTransition(
      position: outSlide,
      child: FadeTransition(
        opacity: outFade,
        child: SlideTransition(
          position: inSlide,
          child: FadeTransition(
            opacity: inFade,
            child: child,
          ),
        ),
      ),
    );
  }
}
