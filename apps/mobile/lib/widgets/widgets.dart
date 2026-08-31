import 'package:flutter/material.dart';

/// The Subflow mark (design Етап 1): an S-flow stroke with coral + amber dots.
/// Geometry lifted verbatim from the approved SVG (88×88 viewBox).
class SubflowMark extends StatelessWidget {
  const SubflowMark({super.key, this.size = 28});
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _MarkPainter());
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 88;
    final stroke = Paint()
      ..color = const Color(0xFF6B5CE7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10 * k
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(30 * k, 24 * k)
      ..arcToPoint(Offset(45 * k, 39 * k), radius: Radius.circular(15 * k))
      ..arcToPoint(Offset(60 * k, 54 * k), radius: Radius.circular(15 * k), clockwise: false);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(Offset(30 * k, 24 * k), 7.5 * k, Paint()..color = const Color(0xFFFF7A59));
    canvas.drawCircle(Offset(60 * k, 63 * k), 7.5 * k, Paint()..color = const Color(0xFFFFC957));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Base component set (subF-13). Small on purpose — grows with real screens.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, this.onPressed, this.busy = false});

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
          : Text(label),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // design 03: white card on cream with a feather shadow; in dark — tone separation only
    final isLight = theme.brightness == Brightness.light;
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: isLight ? null : Border.all(color: theme.colorScheme.outline, width: 0.5),
        boxShadow: isLight
            ? const [BoxShadow(color: Color(0x0F2B2440), offset: Offset(0, 2), blurRadius: 8)]
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle!, style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Спробувати ще раз')),
            ],
          ],
        ),
      ),
    );
  }
}
