import 'package:flutter/material.dart';

/// Palette lifted from codex-resets.com: cozy paper + hard ink borders.
class Paper {
  static const paper = Color(0xFFFFF4DD);
  static const ink = Color(0xFF26201A);
  static const ink2 = Color(0xFF5C5347);
  static const ink3 = Color(0xFF877B6B);
  static const card = Color(0xFFFFFDF7);
  static const accent = Color(0xFFFF5C2B);
  static const sun = Color(0xFFFFD84D);
  static const rose = Color(0xFFFFB9CC);
  static const sky = Color(0xFFA5DCFF);
  static const peach = Color(0xFFFFB07A);
  static const mint = Color(0xFFB9E6A6);

  /// 'monospace' resolves to nothing on macOS — name real families first.
  static const mono = TextStyle(
    fontFamilyFallback: ['Menlo', 'SF Mono', 'Consolas', 'monospace'],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const radius = Radius.circular(14);
  static final border = Border.all(color: ink, width: 2);

  /// Hard offset shadow, no blur — the whole look hangs on this.
  static List<BoxShadow> shadow([double dy = 4]) => [
    BoxShadow(color: ink, offset: Offset(0, dy)),
  ];

  static ThemeData theme() {
    const display = 'Baloo';
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: paper,
      colorScheme: base.colorScheme.copyWith(
        primary: accent,
        surface: card,
        onSurface: ink,
      ),
      textTheme: base.textTheme
          .apply(bodyColor: ink, displayColor: ink, fontFamily: display)
          .copyWith(
            titleLarge: const TextStyle(
              fontFamily: display,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
            titleMedium: const TextStyle(
              fontFamily: display,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
      dividerColor: ink,
    );
  }
}

/// Card with 2px ink border and a hard drop shadow.
class PaperBox extends StatelessWidget {
  const PaperBox({
    super.key,
    required this.child,
    this.color = Paper.card,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color color;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        border: Paper.border,
        borderRadius: const BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Paper.radius),
      child: box,
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(
    this.label, {
    super.key,
    this.color = Paper.sun,
    this.ink = Paper.ink,
  });
  final String label;
  final Color color;
  final Color ink;

  Pill withInk(Color c) => Pill(label, color: color, ink: c);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: Paper.ink, width: 1.5),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: ink),
    ),
  );
}

/// Chunky pressable button: shifts down onto its shadow when pressed.
class PaperButton extends StatefulWidget {
  const PaperButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = Paper.accent,
    this.onColor = Paper.card,
  });
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final Color onColor;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) {
      setState(() => _down = false);
      widget.onPressed();
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 70),
      transform: Matrix4.translationValues(0, _down ? 3 : 0, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.color,
        border: Paper.border,
        borderRadius: BorderRadius.circular(999),
        boxShadow: Paper.shadow(_down ? 1 : 4),
      ),
      child: Text(
        widget.label,
        style: TextStyle(
          fontFamily: 'Baloo',
          fontWeight: FontWeight.w800,
          color: widget.onColor,
        ),
      ),
    ),
  );
}

/// The dotted paper backdrop.
class DotBackground extends StatelessWidget {
  const DotBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _Dots(), child: child);
}

class _Dots extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Paper.ink.withValues(alpha: 0.10);
    const gap = 22.0;
    for (var y = gap / 2; y < size.height; y += gap) {
      for (var x = gap / 2; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Dots _) => false;
}
