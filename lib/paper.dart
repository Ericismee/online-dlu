import 'package:flutter/material.dart';

import 'cache.dart';

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
  /// Bóng khối đổ chéo như codex-resets.com (--shadow: 4px 4px 0 ink).
  static List<BoxShadow> shadow([double d = 4]) => [
    BoxShadow(color: ink, offset: Offset(d, d)),
  ];

  /// Nhịp chuyển động lấy từ codex-resets.com.
  /// Bấm 80ms cho dứt khoát, hiện ra 260ms nảy nhẹ.
  static const pressDur = Duration(milliseconds: 80);
  static const popDur = Duration(milliseconds: 260);

  /// cubic-bezier(.34, 1.56, .64, 1) — nảy quá đà một chút rồi về.
  static const popCurve = Cubic(0.34, 1.56, 0.64, 1);

  /// cubic-bezier(.22, 1, .36, 1) — ra nhanh, dừng êm.
  static const easeOut = Cubic(0.22, 1, 0.36, 1);

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

  Widget _box(bool down) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Paper.border,
      borderRadius: const BorderRadius.all(Paper.radius),
      boxShadow: Paper.shadow(down ? 0 : 4),
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) =>
      onTap == null ? _box(false) : Pressable(onTap: onTap!, builder: _box);
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
    this.fontSize,
  });
  final String label;
  final VoidCallback onPressed;
  final Color color;
  final Color onColor;

  /// Nhãn dài thì truyền cỡ chữ nhỏ hơn cho khỏi vỡ hàng.
  final double? fontSize;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  @override
  Widget build(BuildContext context) => Pressable(
    onTap: widget.onPressed,
    shift: 3,
    builder: (down) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: widget.color,
        border: Paper.border,
        borderRadius: BorderRadius.circular(999),
        boxShadow: Paper.shadow(down ? 0 : 4),
      ),
      child: Text(
        widget.label,
        style: TextStyle(
          fontFamily: 'Baloo',
          fontWeight: FontWeight.w800,
          fontSize: widget.fontSize,
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

/// Mẩu giấy xám nhấp nháy nhẹ, dùng làm chỗ chờ khi API chưa về.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = 8,
    this.ink = false,
  });
  final double? width;
  final double height, radius;

  /// true = có viền mực, dùng cho các ô to như ô lịch.
  final bool ink;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _a.drive(Tween(begin: 0.45, end: 0.9)),
    child: Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFE7DCC4),
        border: widget.ink ? Paper.border : null,
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

/// Nút chọn kiểu giấy dán: nhãn + mũi tên xuống.
class Choice extends StatelessWidget {
  const Choice({
    super.key,
    required this.label,
    required this.onTap,
    this.color = Paper.sun,
  });
  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    builder: (down) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color,
        border: Paper.border,
        borderRadius: BorderRadius.circular(12),
        boxShadow: Paper.shadow(down ? 0 : 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Baloo',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Paper.ink,
            ),
          ),
          const Icon(Icons.expand_more_rounded, size: 18, color: Paper.ink2),
        ],
      ),
    ),
  );
}

/// Hộp thoại chọn một trong mấy lựa chọn ngắn.
Future<String?> chooseOption(
  BuildContext context,
  List<String> options,
  String current,
) => showDialog<String>(
  context: context,
  builder: (_) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Paper.paper,
        border: Paper.border,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Paper.shadow(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context, o),
                child: Container(
                  width: double.infinity,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: o == current ? Paper.sun : Paper.card,
                    border: Paper.border,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: Paper.shadow(2),
                  ),
                  child: Text(
                    o,
                    style: const TextStyle(
                      fontFamily: 'Baloo',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: Paper.ink,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  ),
);

/// Kéo xuống làm mới: gọi portal thật, data cũ vẫn nằm đó tới khi có data mới.
class PullRefresh extends StatelessWidget {
  const PullRefresh({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: Paper.ink,
    backgroundColor: Paper.sun,
    onRefresh: Cache.refreshAll,
    child: child,
  );
}

/// State tự nạp lại khi người dùng kéo xuống.
mixin Reloadable<T extends StatefulWidget> on State<T> {
  Future<void> reload();

  @override
  void initState() {
    super.initState();
    Cache.refreshers.add(reload);
  }

  @override
  void dispose() {
    Cache.refreshers.remove(reload);
    super.dispose();
  }
}

/// Bấm vào là lún xuống đúng chỗ bóng đang đổ, thả ra bật lại.
/// Cách codex-resets.com làm: translate(2px, 2px) + bỏ bóng.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.builder,
    this.shift = 2,
  });
  final VoidCallback onTap;

  /// [down] = đang giữ, để vẽ bóng ngắn lại cho khớp.
  final Widget Function(bool down) builder;
  final double shift;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) => setState(() => _down = v);

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => _set(true),
    onTapCancel: () => _set(false),
    onTapUp: (_) {
      _set(false);
      widget.onTap();
    },
    child: AnimatedSlide(
      duration: Paper.pressDur,
      offset: _down
          ? Offset(widget.shift / 24, widget.shift / 24)
          : Offset.zero,
      child: widget.builder(_down),
    ),
  );
}

/// Hiện ra kiểu pop-in của codex-resets.com: mờ + nhỏ hơn rồi nảy về.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Paper.popDur + delay,
    curve: Interval(
      delay.inMilliseconds / (Paper.popDur + delay).inMilliseconds,
      1,
      curve: Paper.popCurve,
    ),
    builder: (_, t, child) => Opacity(
      opacity: t.clamp(0, 1),
      child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
    ),
    child: child,
  );
}
