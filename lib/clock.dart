import 'dart:async';

import 'package:flutter/widgets.dart';

/// Đồng hồ chung của app. Mọi chỗ cần giờ thực nghe chung một nguồn thay vì
/// mỗi màn một Timer, và nhịp được canh đúng đầu phút — nửa đêm là trang chủ
/// đổi sang hôm sau ngay tại 0h00, không lệch mấy chục giây.
class Clock extends ValueNotifier<DateTime> with WidgetsBindingObserver {
  Clock._() : super(DateTime.now()) {
    WidgetsBinding.instance.addObserver(this);
    _hen();
  }

  static final Clock instance = Clock._();

  Timer? _timer;

  /// Đầu phút kế tiếp tính từ [now].
  static DateTime nextTick(DateTime now) => DateTime(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
  ).add(const Duration(minutes: 1));

  void _hen() {
    final now = DateTime.now();
    _timer?.cancel();
    _timer = Timer(nextTick(now).difference(now), () {
      value = DateTime.now();
      _hen();
    });
  }

  /// Máy khoá màn hình thì Timer cũng ngủ theo; mở lại app phải đúng giờ
  /// ngay từ khung hình đầu, chứ không đợi hết phút.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      value = DateTime.now();
      _hen();
    }
  }

  /// Test tua giờ bằng cách gán thẳng [value]; app thật thì không gọi.
  @visibleForTesting
  void set(DateTime t) => value = t;

  /// Dừng hẹn nhịp — test phải gọi, không thì còn Timer treo lúc kết thúc.
  @visibleForTesting
  void stop() => _timer?.cancel();

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Dựng lại mỗi phút theo đồng hồ chung — đếm ngược, đổi ngày, đổi trạng
/// thái tiết đều đi qua đây.
class Ticker extends StatelessWidget {
  const Ticker({super.key, required this.builder});
  final Widget Function(BuildContext context, DateTime now) builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime>(
    valueListenable: Clock.instance,
    builder: (context, now, _) => builder(context, now),
  );
}
