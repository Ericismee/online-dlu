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
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Nhịp còn quay không. Đứng nghĩa là có ai đó (test) đang tua giờ bằng tay
  /// — [ClockGiay] thấy vậy thì cũng đứng theo chứ đừng lôi giờ máy vào.
  bool get chay => _timer != null;

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Đồng hồ giây, cho đếm ngược chạy thật chứ không nhảy từng phút. Chỉ tích
/// khi có người nghe: không ai hiện đếm ngược thì không có Timer nào quay, mỗi
/// giây một khung hình là thứ không đáng trả bằng pin lúc chẳng ai nhìn.
class ClockGiay extends ValueNotifier<DateTime> {
  ClockGiay._() : super(Clock.instance.value) {
    // Đồng hồ chung nhảy (sang phút mới, hay test tua giờ) thì bám theo ngay:
    // hai đồng hồ nói hai giờ khác nhau là thẻ nào cũng có thể tự mâu thuẫn.
    Clock.instance.addListener(() => value = Clock.instance.value);
  }

  static final instance = ClockGiay._();

  Timer? _timer;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    // Đồng hồ chung đang đứng thì không tự quay: test tua giờ bằng tay, mà
    // nhịp giây kéo giờ máy vào là màn hiện giờ thật thay vì giờ đang dựng.
    if (_timer == null && Clock.instance.chay) {
      value = DateTime.now();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => value = DateTime.now(),
      );
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  /// Dừng nhịp — test phải gọi, không thì còn Timer treo lúc kết thúc.
  @visibleForTesting
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Dựng lại theo đồng hồ chung — đếm ngược, đổi ngày, đổi trạng thái tiết đều
/// đi qua đây. Mặc định mỗi phút; [giay] thì mỗi giây, chỉ dùng cho đúng chỗ
/// hiện số đếm ngược chứ đừng bọc cả màn.
class Ticker extends StatelessWidget {
  const Ticker({super.key, required this.builder, this.giay = false});
  final Widget Function(BuildContext context, DateTime now) builder;
  final bool giay;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<DateTime>(
    valueListenable: giay ? ClockGiay.instance : Clock.instance,
    builder: (context, now, _) => builder(context, now),
  );
}
