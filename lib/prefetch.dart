import 'dart:async';

import 'cache.dart';
import 'graph.dart';
import 'portal.dart';

/// Nạp sẵn mọi thứ vào máy ngay khi mở app, để mất mạng vẫn mở được và các
/// màn sau bấm vào là có ngay.
///
/// Gọi tuần tự chứ không bắn một lượt: server trường yếu, mà đằng nào người
/// dùng cũng chỉ nhìn một màn tại một thời điểm. Thứ nào cache còn hạn thì
/// [Portal] tự trả về từ máy, không đụng tới mạng.
class Prefetch {
  /// Một lượt nạp tại một thời điểm, khỏi nhân đôi số lần gọi portal.
  static bool _dangChay = false;

  /// Lượt nạp gần nhất xong lúc nào — trong một phiên thì khỏi lặp lại.
  static DateTime? xongLuc;

  static Future<void> run(Session session, {Portal? portal}) async {
    if (_dangChay) return;
    if (xongLuc != null && !Cache.stale(xongLuc!)) return;
    _dangChay = true;
    final p = portal ?? Portal();
    final token = session.token;
    final now = DateTime.now();
    final (year, term) = yearTermFor(now);
    try {
      await _thu(() => p.studentInfo(token));
      await _thu(() => p.exams(token));
      await _thu(() => p.messages(token));
      await _thu(() => p.behaviorScores(token));
      await _thu(() => p.behaviorDetail(token, year: year, term: term));
      await _thu(() => p.registrations(token, year: year, term: term));
      final program = await _thu(() => p.studyProgram(token));
      if (program != null) {
        await _thu(() => p.marks(token, program));
        await _thu(() => p.curriculum(token, program));
      }
      // Tháng này và tháng sau: cuối tháng mở ra vẫn thấy lịch tuần tới,
      // và nửa đêm sang tháng mới không phải chờ mạng.
      for (final m in [
        DateTime(now.year, now.month),
        DateTime(now.year, now.month + 1),
      ]) {
        await _thu(() => fetchMonth(p, token, m));
      }
      xongLuc = DateTime.now();
    } finally {
      _dangChay = false;
    }
  }

  /// Một mục hỏng (portal lỗi, mất mạng) thì bỏ qua, đừng chặn các mục sau.
  static Future<T?> _thu<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PortalError {
      return null;
    }
  }
}
