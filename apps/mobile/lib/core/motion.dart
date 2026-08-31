import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Motion system (subF-23, design "Анімації"): calm and fluid — control, not anxiety.
abstract final class Motion {
  /// M3 emphasized — screen/page transitions.
  static const emphasized = Cubic(0.2, 0, 0, 1);

  /// Springy deceleration — share card slide-in.
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);

  static const pageForward = Duration(milliseconds: 300);
  static const pageBack = Duration(milliseconds: 250);
  static const countUp = Duration(milliseconds: 1200);
  static const cardEntrance = Duration(milliseconds: 350);
  static const cardStagger = Duration(milliseconds: 60);

  static bool reduced(BuildContext context) => MediaQuery.of(context).disableAnimations;
}

/// Count-up number: races ahead then brakes hard (easeOutExpo) — the "being counted"
/// feel. Plays once (caller keys it); optional light haptic when it lands.
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.format,
    this.style,
    this.delay = Duration.zero,
    this.haptic = false,
    this.play = true,
  });

  final int value;
  final String Function(int) format;
  final TextStyle? style;
  final Duration delay;
  final bool haptic;
  final bool play;

  @override
  Widget build(BuildContext context) {
    if (!play || Motion.reduced(context)) return Text(format(value), style: style);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.countUp + delay,
      curve: Interval(delay.inMilliseconds / (Motion.countUp + delay).inMilliseconds, 1, curve: Curves.easeOutExpo),
      onEnd: haptic ? HapticFeedback.lightImpact : null,
      builder: (context, t, _) => Text(format((value * t).round()), style: style),
    );
  }
}

/// Cascade entrance for list items: fade + 24dp slide-up, staggered by index.
class CascadeIn extends StatefulWidget {
  const CascadeIn({super.key, required this.index, required this.play, required this.child});
  final int index;
  final bool play;
  final Widget child;

  @override
  State<CascadeIn> createState() => _CascadeInState();
}

class _CascadeInState extends State<CascadeIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.cardEntrance);
  late final CurvedAnimation _a = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    if (widget.play) {
      Future<void>.delayed(Motion.cardStagger * widget.index, () {
        if (mounted) _c.forward();
      });
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return widget.child;
    return FadeTransition(
      opacity: _a,
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, child) => Transform.translate(offset: Offset(0, 24 * (1 - _a.value)), child: child),
        child: widget.child,
      ),
    );
  }
}

/// Tap micro-interaction: quick 0.96 squeeze with a selection click on press.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        setState(() => _down = true);
      },
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: Duration(milliseconds: _down ? 100 : 150),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}
