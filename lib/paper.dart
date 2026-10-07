import 'dart:async';
import 'dart:math' show max, pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

/// Chừa chỗ cho thanh điều hướng nổi ở đáy: thanh cao cỡ 100 kể cả bóng cứng
/// và lề của nó, nên nội dung cuộn hết cỡ vẫn còn một khoảng thở chứ không
/// dính vào thanh.
// ponytail: số đo tay theo thanh hiện tại; đổi cỡ thanh thì đổi cả số này.
const chuaThanhDuoi = 136.0;

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

/// Vòng tiến độ kiểu giấy cắt: một rãnh giấy kem viền mực, trên đó dán một dải
/// giấy màu có bóng cứng đổ xuống — cùng ngôn ngữ với [Pill] và [PaperBox], chứ
/// không phải vòng tròn trơn kiểu Material. Dải màu chạy từ 0 lên mỗi lần số
/// đổi, kiểu kim đồng hồ quay tới chỗ của nó.
class PaperRing extends StatelessWidget {
  const PaperRing({
    super.key,
    required this.value,
    required this.center,
    required this.label,
    this.duoi,
    this.color = Paper.sun,
    this.size = 92,
    this.duration = const Duration(milliseconds: 900),
  });

  /// 0..1; ngoài khoảng đó thì kẹp lại cho vòng khỏi vẽ quá một lượt.
  final double value;

  /// Số nằm giữa vòng, chú thích nhỏ ngay dưới số, và nhãn dưới vòng.
  final String center;
  final String? duoi;
  final String label;
  final Color color;
  final double size;

  /// Thời gian dải giấy bò tới [value] mới. Để [Duration.zero] khi vòng đã
  /// được điều khiển từ ngoài (giữ ngón tay), không thì nó bò sau ngón tay.
  final Duration duration;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: size,
        height: size,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value.clamp(0, 1)),
          duration: duration,
          // Nhảy qua đích rồi lùi về một chút: dải giấy có đà, không phải
          // thanh tiến trình trượt đều.
          curve: Paper.popCurve,
          builder: (_, v, con) =>
              CustomPaint(painter: _RingPainter(v, color), child: con),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                center,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Baloo',
                  fontWeight: FontWeight.w800,
                  height: 1,
                  // Nhãn giữa vòng dài ngắn khác nhau ('3.21' với '18/42'), cỡ
                  // chữ theo đường kính để cái dài không chạm vào vòng.
                  fontSize: size * (center.length > 4 ? 0.2 : 0.25),
                  color: Paper.ink,
                ),
              ),
              if (duoi != null) ...[
                const SizedBox(height: 3),
                Text(
                  duoi!,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: size * 0.1,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: Paper.ink3,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Paper.ink2,
        ),
      ),
    ],
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.color);
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Chừa chỗ cho bóng cứng đổ xuống phải, y như [Paper.shadow] nhưng ngắn
    // hơn vì vòng nhỏ.
    const bong = Offset(2.5, 2.5);
    final day = size.width * 0.16;
    final giua = (size.width - bong.dx) / 2 - 1 - day / 2;
    final tam = size.center(Offset.zero) - bong / 2;
    final o = Rect.fromCircle(center: tam, radius: giua);
    final net = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = day
      ..strokeCap = StrokeCap.butt;
    final vien = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = Paper.ink;

    // Bóng cứng của cả cái vòng, vẽ trước nên nằm dưới.
    canvas.drawCircle(tam + bong, giua, net..color = Paper.ink);
    // Rãnh trống là giấy kem chứ không phải xám: vòng nằm trên thẻ trắng nên
    // phải thấy được nó là một miếng giấy khác màu.
    canvas.drawCircle(tam, giua, net..color = Paper.paper);
    canvas.drawCircle(tam, giua + day / 2, vien);
    canvas.drawCircle(tam, giua - day / 2, vien);

    if (value <= 0) return;
    // Dải giấy màu dán đè lên rãnh, từ 12 giờ chạy theo chiều kim đồng hồ.
    // Vẽ dày hơn bằng mực trước rồi đè màu lên: viền ôm trọn cả hai đầu dải,
    // khỏi phải tự dựng path cho hai cái đầu bo tròn.
    final goc = 2 * pi * value;
    canvas.drawArc(
      o,
      -pi / 2,
      goc,
      false,
      net
        ..color = Paper.ink
        ..strokeWidth = day + 3.2
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      o,
      -pi / 2,
      goc,
      false,
      net
        ..color = color
        ..strokeWidth = day,
    );
    // Vệt sáng mảnh men theo mép trong dải màu — giấy màu bắt sáng, đủ để vòng
    // không phẳng lì mà vẫn không có gradient.
    canvas.drawArc(
      Rect.fromCircle(center: tam, radius: giua - day / 2 + 2.6),
      -pi / 2 + 0.12,
      max(goc - 0.24, 0),
      false,
      net
        ..color = Colors.white.withValues(alpha: 0.5)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
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
      // Huy hiệu luôn một dòng. Nhãn dài (tên giảng viên) thì đặt trong
      // Flexible để nó còn chỗ mà cắt, chứ trong Wrap là tràn qua mép.
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
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
    // Mực trên cam đo được 4.9:1, kem trên cam chỉ 3.03:1 — chữ nhãn 14 đậm
    // vẫn phải đạt 4.5:1 nên mặc định là mực.
    this.onColor = Paper.ink,
    this.fontSize,
  });
  final String label;

  /// null là đang tắt: bạc màu, không bóng, không nhận chạm.
  final VoidCallback? onPressed;
  final Color color;
  final Color onColor;

  /// Nhãn dài thì truyền cỡ chữ nhỏ hơn cho khỏi vỡ hàng.
  final double? fontSize;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  Widget _than(bool down) {
    final tat = widget.onPressed == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: tat ? Paper.card : widget.color,
        border: Paper.border,
        borderRadius: BorderRadius.circular(999),
        // Nút tắt nằm bẹt xuống giấy: không bóng là thấy ngay nó không bấm
        // được, khỏi cần chữ mờ mới hiểu.
        boxShadow: Paper.shadow(tat || down ? 0 : 4),
      ),
      child: Text(
        widget.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Baloo',
          fontWeight: FontWeight.w800,
          fontSize: widget.fontSize,
          color: tat ? Paper.ink3 : widget.onColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    if (onPressed == null) return _than(false);
    return Pressable(onTap: onPressed, shift: 3, builder: _than);
  }
}

/// The dotted paper backdrop.
class DotBackground extends StatelessWidget {
  const DotBackground({super.key, required this.child});
  final Widget child;

  @override
  // RepaintBoundary: nội dung cuộn không kéo theo ~350 chấm vẽ lại mỗi frame.
  Widget build(BuildContext context) => CustomPaint(
    painter: _Dots(),
    isComplex: true,
    willChange: false,
    child: RepaintBoundary(child: child),
  );
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
    opacity: MediaQuery.disableAnimationsOf(context)
        ? const AlwaysStoppedAnimation(0.7)
        : _a.drive(Tween(begin: 0.45, end: 0.9)),
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
              child: Semantics(
                button: true,
                selected: o == current,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context, o),
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    // 12+12+chữ 15 ~ 45pt, đủ ngưỡng chạm 44pt.
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
            ),
        ],
      ),
    ),
  ),
);

/// Hỏi trước khi làm việc gì đó ra ngoài app. Trả về true nếu người dùng đồng ý.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String ok,
  IconData icon = Icons.event_available_rounded,
  Color color = Paper.sun,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => PaperDialog(
        title: title,
        icon: icon,
        color: color,
        children: [
          // Lời dẫn nằm trong thẻ giấy: chữ xám trên nền kem trơn
          // bị chìm, có viền với bóng thì đọc ra ngay.
          PaperBox(
            padding: const EdgeInsets.all(14),
            child: Text(
              body,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: Paper.ink2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PaperButton(
                  label: 'Huỷ',
                  color: Paper.card,
                  onColor: Paper.ink,
                  onPressed: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PaperButton(
                  label: ok,
                  onPressed: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    ) ??
    false;

/// Kéo xuống làm mới: gọi portal thật, data cũ vẫn nằm đó tới khi có data mới.
/// Đổi ý thì kéo ngược lên là vòng xoay tắt ngay, khỏi ngồi chờ server trường.
class PullRefresh extends StatefulWidget {
  const PullRefresh({super.key, required this.child});
  final Widget child;

  @override
  State<PullRefresh> createState() => _PullRefreshState();
}

class _PullRefreshState extends State<PullRefresh> {
  /// Lượt làm mới đang chạy; hoàn tất là vòng xoay biến mất.
  Completer<void>? _cho;

  Future<void> _lamMoi() {
    final cho = _cho = Completer<void>();
    // Không chờ nữa không có nghĩa là bỏ số: lượt gọi đang bay vẫn chạy nốt,
    // về tới nơi thì màn tự thay số như thường.
    unawaited(
      Cache.refreshAll().whenComplete(() {
        if (!cho.isCompleted) cho.complete();
      }),
    );
    return cho.future.whenComplete(() {
      if (identical(_cho, cho)) _cho = null;
    });
  }

  /// scrollDelta > 0 là ngón tay đang kéo ngược lên — người dùng đổi ý.
  bool _keoNguocLen(ScrollNotification n) {
    final cho = _cho;
    if (cho != null &&
        !cho.isCompleted &&
        n is ScrollUpdateNotification &&
        n.dragDetails != null &&
        (n.scrollDelta ?? 0) > 0) {
      cho.complete();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: _keoNguocLen,
        child: RefreshIndicator(
          color: Paper.ink,
          backgroundColor: Paper.sun,
          onRefresh: _lamMoi,
          child: widget.child,
        ),
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
  // MergeSemantics + button: VoiceOver/TalkBack đọc nguyên thẻ là một nút,
  // không thì nó đọc rời từng dòng chữ mà không biết bấm được.
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      button: true,
      onTap: widget.onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          HapticFeedback.selectionClick();
          _set(true);
        },
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
      ),
    ),
  );
}

/// Hiện ra kiểu pop-in của codex-resets.com: mờ + nhỏ hơn rồi nảy về.
class PopIn extends StatelessWidget {
  const PopIn({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    // Tắt hiệu ứng trong Cài đặt thì hiện thẳng, khỏi nảy.
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
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
}

/// Nhãn trên một ô nhập.
class PaperLabel extends StatelessWidget {
  const PaperLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
    ),
  );
}

/// Ô nhập kiểu giấy: viền mực dày, nền kem, viền đổi màu nhấn khi đang gõ.
class PaperField extends StatelessWidget {
  const PaperField({
    super.key,
    required this.nhan,
    required this.controller,
    required this.onSubmit,
    this.enabled = true,
    this.obscure = false,
    this.autofocus = false,
    this.suffix,
    this.keyboardType,
    this.autofillHints,
    this.action = TextInputAction.done,
  });

  /// Nhãn cho trình đọc màn hình. Ô nhập này cố tình không có labelText hay
  /// hintText (giữ hình), nên nếu không gắn nhãn thì VoiceOver/TalkBack chỉ
  /// đọc được "ô nhập, trống" — bắt buộc truyền, thường là chữ của
  /// [PaperLabel] đứng ngay trên.
  final String nhan;

  final TextEditingController controller;
  final VoidCallback onSubmit;
  final bool enabled;
  final bool obscure;
  final bool autofocus;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;

  /// Ô cuối là 'done' để gửi luôn, ô trên là 'next' để xuống ô kế.
  final TextInputAction action;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: c, width: 2),
    );
    return Semantics(
      label: nhan,
      textField: true,
      child: TextField(
        controller: controller,
        enabled: enabled,
        obscureText: obscure,
        autofocus: autofocus,
        keyboardType: keyboardType,
        autofillHints: autofillHints,
        textInputAction: action,
        onSubmitted: (_) => onSubmit(),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: Paper.paper,
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: border(Paper.ink),
          enabledBorder: border(Paper.ink),
          disabledBorder: border(Paper.ink3),
          focusedBorder: border(Paper.accent),
        ),
      ),
    );
  }
}

/// Vỏ hộp thoại kiểu giấy: huy hiệu + tiêu đề, phần thân do nơi gọi dựng.
/// [confirmDialog] và hộp đăng nhập LMS dùng chung cái này nên hai hộp thoại
/// không bao giờ lệch nhau một vài pixel.
class PaperDialog extends StatelessWidget {
  const PaperDialog({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.color = Paper.sun,
    this.maxWidth = 340,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Color color;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Paper.paper,
        border: Paper.border,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Paper.shadow(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Huy hiệu cùng kiểu với các ô trong app, để hộp thoại
              // trông như một thẻ giấy nữa chứ không phải popup hệ thống.
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color,
                  border: Paper.border,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: Paper.shadow(3),
                ),
                child: Icon(icon, size: 22, color: Paper.ink),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Baloo',
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    height: 1.15,
                    color: Paper.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    ),
  );
}

/// Ô tìm kiếm mặc kiểu giấy. Giữ chữ trong controller của chính nó,
/// nơi gọi chỉ cần nghe onChanged.
class SearchBox extends StatefulWidget {
  const SearchBox({super.key, required this.onChanged, this.hint = 'Tìm'});
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _set(String v) {
    widget.onChanged(v);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: Paper.card,
      border: Paper.border,
      borderRadius: BorderRadius.circular(999),
      boxShadow: Paper.shadow(3),
    ),
    child: Row(
      children: [
        const Icon(Icons.search_rounded, size: 20, color: Paper.ink3),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _c,
            onChanged: _set,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15, color: Paper.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: const TextStyle(color: Paper.ink2, fontSize: 15),
              // 12+20+12 = 44pt, đủ ngưỡng chạm mà không phình ô.
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (_c.text.isNotEmpty)
          Semantics(
            button: true,
            label: 'Xoá chữ tìm',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _c.clear();
                _set('');
              },
              child: const Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close_rounded, size: 18, color: Paper.ink2),
              ),
            ),
          ),
      ],
    ),
  );
}
