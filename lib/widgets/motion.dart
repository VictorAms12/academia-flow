import 'package:flutter/material.dart';

abstract final class MotionSpec {
  static const micro = Duration(milliseconds: 140);
  static const fast = Duration(milliseconds: 190);
  static const normal = Duration(milliseconds: 260);
  static const emphasized = Duration(milliseconds: 380);
  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}

class MotionEntrance extends StatefulWidget {
  const MotionEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, .035),
    this.duration = MotionSpec.normal,
  });

  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.delay != Duration.zero) await Future<void>.delayed(widget.delay);
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) return widget.child;
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: widget.duration,
      curve: MotionSpec.curve,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : widget.offset,
        duration: widget.duration,
        curve: MotionSpec.curve,
        child: widget.child,
      ),
    );
  }
}

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    this.decimals = 0,
    this.suffix = '',
    this.prefix = '',
    this.style,
    this.duration = const Duration(milliseconds: 650),
  });

  final double value;
  final int decimals;
  final String suffix;
  final String prefix;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return Text('$prefix${value.toStringAsFixed(decimals)}$suffix', style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value),
      duration: duration,
      curve: MotionSpec.curve,
      builder: (_, v, __) => Text('$prefix${v.toStringAsFixed(decimals)}$suffix', style: style),
    );
  }
}

class MotionProgress extends StatelessWidget {
  const MotionProgress({
    super.key,
    required this.value,
    this.minHeight = 6,
    this.duration = const Duration(milliseconds: 520),
  });

  final double value;
  final double minHeight;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final target = value.clamp(0.0, 1.0).toDouble();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      return LinearProgressIndicator(value: target, minHeight: minHeight, borderRadius: BorderRadius.circular(20));
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: target),
      duration: duration,
      curve: MotionSpec.curve,
      builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: minHeight, borderRadius: BorderRadius.circular(20)),
    );
  }
}

Route<T> motionRoute<T>(Widget page, {RouteSettings? settings}) {
  return PageRouteBuilder<T>(
    settings: settings,
    transitionDuration: MotionSpec.normal,
    reverseTransitionDuration: MotionSpec.fast,
    pageBuilder: (_, animation, __) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return child;
      final curved = CurvedAnimation(parent: animation, curve: MotionSpec.curve, reverseCurve: Curves.easeInCubic);
      final fade = Tween<double>(begin: .35, end: 1).animate(curved);
      final slide = Tween<Offset>(begin: const Offset(.035, 0), end: Offset.zero).animate(curved);
      final scale = Tween<double>(begin: .992, end: 1).animate(curved);
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: slide,
          child: ScaleTransition(scale: scale, child: child),
        ),
      );
    },
  );
}
