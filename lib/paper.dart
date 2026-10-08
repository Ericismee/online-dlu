import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cache.dart';

/// Bảng màu và token lấy đúng theo neubrutalism.com: nền kem, mực đen tuyền,
/// viền dày, bóng cứng không nhoè, góc vuông.
class Paper {
  static Color paper = _sang.paper; // --bg
  static Color ink = _sang.ink; // --ink
  static Color ink2 = _sang.ink2;
  static Color ink3 = _sang.ink3;
  static Color card = _sang.card; // --surface
  static Color accent = _sang.accent; // --pink
  static Color sun = _sang.sun; // --yellow
  static Color rose = _sang.rose; // --red: hỏng, trượt, trùng giờ
  static Color sky = _sang.sky; // --blue
  static Color peach = _sang.peach; // --orange
  static Color mint = _sang.mint; // --green

  /// Nền ô lịch ngày nghỉ và nền khung xương lúc đang tải.
  static Color nghi = _sang.nghi;
  static Color xuong = _sang.xuong;

  /// Chế độ tối đang bật hay không. Dạng notifier để [App] vẽ lại cả cây
  /// ngay khi gạt công tắc, khỏi mở lại app.
  static final toiN = ValueNotifier(false);
  static bool get toi => toiN.value;

  /// Đổi bảng màu. Mực trong chế độ tối là kem chứ không phải đen, nên viền
  /// và bóng cứng cũng phải dựng lại theo.
  static void datToi(bool v) {
    final b = v ? _toi : _sang;
    paper = b.paper;
    ink = b.ink;
    ink2 = b.ink2;
    ink3 = b.ink3;
    card = b.card;
    accent = b.accent;
    sun = b.sun;
    rose = b.rose;
    sky = b.sky;
    peach = b.peach;
    mint = b.mint;
    nghi = b.nghi;
    xuong = b.xuong;
    border = Border.all(color: ink, width: 3);
    toiN.value = v;
  }

  /// 'monospace' resolves to nothing on macOS — name real families first.
  static const mono = TextStyle(
    fontFamilyFallback: ['Menlo', 'SF Mono', 'Consolas', 'monospace'],
    fontFeatures: [FontFeature.tabularFigures()],
  );

  /// Neubrutalism gốc để góc vuông, nhưng trên màn điện thoại nhìn gắt và khó
  /// chịu — bo 12 như mặc định của app SaaS, mọi thứ khác vẫn giữ nguyên chất.
  static const radius = Radius.circular(12);
  static Border border = Border.all(color: ink, width: 3);

  /// Bóng cứng, lệch hẳn, không nhoè — cả cái nhìn treo vào đây.
  /// Thang của neubrutalism.com: sm 3, md 5, lg 8, xl 12.
  static List<BoxShadow> shadow([double d = 5]) => [
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

  /// Hai bảng màu. Giấy màu trong chế độ tối chỉ còn là một thoáng sắc trên
  /// nền gần đen: giữ nguyên độ tươi thì mực kem đặt lên không đọc nổi, mà
  /// hạ nửa chừng thì ra màu bùn, nhìn như ảnh âm bản.
  static const _sang = (
    paper: Color(0xFFFFFDF5),
    ink: Color(0xFF000000),
    ink2: Color(0xFF444444),
    ink3: Color(0xFF666666),
    card: Color(0xFFFFFFFF),
    accent: Color(0xFFFF6B6B),
    sun: Color(0xFFFFD23F),
    rose: Color(0xFFFF4444),
    sky: Color(0xFF74B9FF),
    peach: Color(0xFFFFA552),
    mint: Color(0xFF88D498),
    nghi: Color(0xFFF2E7CE),
    xuong: Color(0xFFF5F0E8),
  );

  static const _toi = (
    paper: Color(0xFF121216),
    ink: Color(0xFFF2EDE3),
    ink2: Color(0xFFB0ABA3),
    ink3: Color(0xFF86817A),
    card: Color(0xFF1C1C23),
    accent: Color(0xFF2E1E20),
    sun: Color(0xFF2A2414),
    rose: Color(0xFF4A1A1A),
    sky: Color(0xFF18222F),
    peach: Color(0xFF2C2218),
    mint: Color(0xFF182A1E),
    nghi: Color(0xFF17171C),
    xuong: Color(0xFF24242C),
  );

  /// Giấy màu nguyên bản của [c]. Thẻ lớn trong chế độ tối chỉ còn sắc nhạt,
  /// nhưng huy hiệu và nút thì vẫn dùng màu tươi — mảng nhỏ nên không chói,
  /// mà thiếu nó thì cả màn xám ngoét.
  static Color tuoi(Color c) => toi ? (_tuoi[c] ?? c) : c;

  static final _tuoi = {
    _toi.accent: _sang.accent,
    _toi.sun: _sang.sun,
    _toi.rose: _sang.rose,
    _toi.sky: _sang.sky,
    _toi.peach: _sang.peach,
    _toi.mint: _sang.mint,
    _toi.card: _toi.card,
  };

  /// Mực đọc được trên nền [nen]: giấy màu tươi thì mực đen, nền tối thì mực
  /// sáng. Dùng cho mấy chỗ tự biết nền của mình (huy hiệu, nút).
  static Color tren(Color nen) =>
      nen.computeLuminance() > 0.4 ? const Color(0xFF000000) : ink;

  static ThemeData theme() {
    const display = 'Display';
    final base = toi
        ? ThemeData.dark(useMaterial3: true)
        : ThemeData.light(useMaterial3: true);
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
              fontWeight: FontWeight.w700,
              fontSize: 22,
              height: 1.15,
            ),
            titleMedium: const TextStyle(
              fontFamily: display,
              fontWeight: FontWeight.w700,
              fontSize: 16,
              height: 1.15,
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
    this.color,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final Color? color;
  Color get _color => color ?? Paper.card;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  Widget _box(bool down) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: _color,
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
    this.color,
    this.size = 92,
    this.duration = const Duration(milliseconds: 900),
  });

  /// 0..1; ngoài khoảng đó thì kẹp lại cho vòng khỏi vẽ quá một lượt.
  final double value;

  /// Số nằm giữa vòng, chú thích nhỏ ngay dưới số, và nhãn dưới vòng.
  final String center;
  final String? duoi;
  final String label;
  final Color? color;
  // Dải giấy của vòng là mảng nhỏ: giữ màu tươi để còn thấy nó chạy.
  Color get _color => Paper.tuoi(color ?? Paper.sun);
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
              CustomPaint(painter: _RingPainter(v, _color), child: con),
          // Đổi số giữa vòng (vd đổi thang điểm) thì nảy một cái cho biết là
          // vừa đổi, chứ chữ lặng lẽ thay thì tưởng mình bấm hụt.
          child: AnimatedSwitcher(
            duration: Paper.popDur,
            switchInCurve: Paper.popCurve,
            transitionBuilder: (w, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: a, child: w),
            ),
            child: Column(
              key: ValueKey('$center|$duoi'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  center,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Display',
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
      ),
      const SizedBox(height: 8),
      Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
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
        ..strokeCap = StrokeCap.butt,
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
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color;
}

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color, this.ink});
  final String label;
  final Color? color;
  Color get _color => Paper.tuoi(color ?? Paper.sun);
  final Color? ink;
  Color get _ink => ink ?? Paper.tren(_color);

  Pill withInk(Color c) => Pill(label, color: _color, ink: c);

  @override
  // .badge của neubrutalism.com: viền mảnh 2px, bóng cứng nhỏ, chữ giãn.
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _color,
      border: Border.all(color: Paper.ink, width: 2),
      borderRadius: BorderRadius.all(Paper.radius),
      boxShadow: Paper.shadow(3),
    ),
    child: Text(
      label,
      // Huy hiệu luôn một dòng. Nhãn dài (tên giảng viên) thì đặt trong
      // Flexible để nó còn chỗ mà cắt, chứ trong Wrap là tràn qua mép.
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: _ink,
      ),
    ),
  );
}

/// Chunky pressable button: shifts down onto its shadow when pressed.
class PaperButton extends StatefulWidget {
  const PaperButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color,
    // Mực trên cam đo được 4.9:1, kem trên cam chỉ 3.03:1 — chữ nhãn 14 đậm
    // vẫn phải đạt 4.5:1 nên mặc định là mực.
    this.onColor,
    this.fontSize,
  });
  final String label;

  /// null là đang tắt: bạc màu, không bóng, không nhận chạm.
  final VoidCallback? onPressed;
  final Color? color;
  Color get _color => Paper.tuoi(color ?? Paper.accent);
  final Color? onColor;
  Color get _onColor => onColor ?? Paper.tren(_color);

  /// Nhãn dài thì truyền cỡ chữ nhỏ hơn cho khỏi vỡ hàng.
  final double? fontSize;

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton> {
  Widget _than(bool down) {
    final tat = widget.onPressed == null;
    // .btn / .btn-small: nút nhỏ thì đệm hẹp và bóng nhỏ theo.
    final nho = (widget.fontSize ?? 16) <= 13;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: nho ? 16 : 24,
        vertical: nho ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: tat ? Paper.card : widget._color,
        border: Paper.border,
        borderRadius: BorderRadius.all(Paper.radius),
        // Nút tắt nằm bẹt xuống giấy: không bóng là thấy ngay nó không bấm
        // được, khỏi cần chữ mờ mới hiểu.
        boxShadow: Paper.shadow(tat || down ? 0 : (nho ? 3 : 5)),
      ),
      child: Text(
        widget.label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Display',
          fontWeight: FontWeight.w700,
          fontSize: widget.fontSize,
          color: tat ? Paper.ink3 : widget._onColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final onPressed = widget.onPressed;
    if (onPressed == null) return _than(false);
    return Pressable(onTap: onPressed, builder: _than);
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
  const Skeleton({super.key, this.width, this.height = 14, this.ink = false});
  final double? width;
  final double height;

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
        color: Paper.xuong,
        border: widget.ink ? Paper.border : null,
        borderRadius: BorderRadius.all(Paper.radius),
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
    this.color,
    this.chon,
  });
  final String label;
  final VoidCallback onTap;
  final Color? color;

  /// Null là nút mở bảng chọn (có mũi tên). Có giá trị thì nó là nút gạt:
  /// bật thì tô màu, tắt thì để trơn như giấy nền.
  final bool? chon;
  Color get _color => chon == false ? Paper.card : (color ?? Paper.sun);

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    builder: (down) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: _color,
        border: Paper.border,
        borderRadius: BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(down ? 0 : 3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Display',
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Paper.ink,
            ),
          ),
          if (chon == null)
            Icon(Icons.expand_more_rounded, size: 18, color: Paper.ink2),
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
        borderRadius: BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(8),
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
                      borderRadius: BorderRadius.all(Paper.radius),
                      boxShadow: Paper.shadow(3),
                    ),
                    child: Text(
                      o,
                      style: TextStyle(
                        fontFamily: 'Display',
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
  Color? color,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => PaperDialog(
        title: title,
        icon: icon,
        color: color,
        nut: [
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
        children: [
          // Lời dẫn nằm trong thẻ giấy: chữ xám trên nền kem trơn
          // bị chìm, có viền với bóng thì đọc ra ngay.
          PaperBox(
            padding: const EdgeInsets.all(14),
            child: Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w500,
                color: Paper.ink2,
              ),
            ),
          ),
        ],
      ),
    ) ??
    false;

/// Hộp thoại nhiều lựa chọn, trả chỉ số nút được bấm (null là huỷ). Dùng khi
/// câu hỏi không gói được vào có/không — vd xoá một buổi của mục lặp thì còn
/// phải biết là xoá buổi này hay cả chuỗi.
Future<int?> chonDialog(
  BuildContext context, {
  required String title,
  required String body,
  required List<String> lua,
  IconData icon = Icons.help_outline_rounded,
}) => showDialog<int>(
  context: context,
  builder: (_) => PaperDialog(
    title: title,
    icon: icon,
    nut: [
      for (final (n, l) in lua.indexed) ...[
        SizedBox(
          width: double.infinity,
          child: PaperButton(
            label: l,
            onPressed: () => Navigator.pop(context, n),
          ),
        ),
        const SizedBox(height: 8),
      ],
      SizedBox(
        width: double.infinity,
        child: PaperButton(
          label: 'Huỷ',
          color: Paper.card,
          onColor: Paper.ink,
          onPressed: () => Navigator.pop(context),
        ),
      ),
    ],
    children: [
      PaperBox(
        padding: const EdgeInsets.all(14),
        child: Text(
          body,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w500,
            color: Paper.ink2,
          ),
        ),
      ),
    ],
  ),
);

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
      borderRadius: BorderRadius.all(Paper.radius),
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
          focusedBorder: border(Paper.sky),
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
    this.nut = const [],
    this.color,
    this.maxWidth = 340,
    required this.children,
  });

  final String title;
  final IconData icon;

  /// Nút bấm, dán dưới đáy và không cuộn theo thân: thân dài mà nút cũng
  /// trôi theo thì phải cuộn mỏi tay mới thấy chỗ bấm.
  final List<Widget> nut;

  /// Thân hộp thoại. Dài hơn màn thì tự cuộn, nên cứ nhét thoải mái —
  /// changelog mười dòng trên máy nhỏ mà cỡ chữ hệ thống phóng to thì cái gì
  /// cũng dài hơn màn.
  final List<Widget> children;
  final Color? color;
  Color get _color => color ?? Paper.sun;
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
        borderRadius: BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(8),
      ),
      child: LayoutBuilder(
        builder: (context, con) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cuộn chứ không tràn: Column trần trong Dialog thì nội dung dài
            // hơn màn là vỡ khung ngay — mà máy nhỏ cộng cỡ chữ hệ thống
            // phóng to thì cái gì cũng dài hơn màn, kể cả cái tiêu đề.
            Flexible(
              child: SingleChildScrollView(
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
                            color: _color,
                            border: Paper.border,
                            borderRadius: BorderRadius.all(Paper.radius),
                            boxShadow: Paper.shadow(3),
                          ),
                          child: Icon(icon, size: 22, color: Paper.ink),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'Display',
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
            ),
            // Nút dán đáy, không cuộn theo thân. Chặn ở 40% chiều cao hộp
            // thoại phòng khi chính hàng nút cũng cao hơn màn (ba lựa chọn,
            // chữ phóng to hết cỡ): lúc đó nút tự cuộn trong phần của nó chứ
            // không đẩy cả hộp thoại tràn ra ngoài.
            if (nut.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: con.maxHeight * 0.4),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [const SizedBox(height: 16), ...nut],
                  ),
                ),
              ),
          ],
        ),
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
      borderRadius: BorderRadius.all(Paper.radius),
      boxShadow: Paper.shadow(3),
    ),
    child: Row(
      children: [
        Icon(Icons.search_rounded, size: 20, color: Paper.ink3),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _c,
            onChanged: _set,
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: 15, color: Paper.ink),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              hintText: widget.hint,
              hintStyle: TextStyle(color: Paper.ink2, fontSize: 15),
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
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Icon(Icons.close_rounded, size: 18, color: Paper.ink2),
              ),
            ),
          ),
      ],
    ),
  );
}
