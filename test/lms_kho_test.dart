import 'package:dlu_tkb/lms.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

LmsNotification tb(String id, {String date = '2026-10-02 08:00'}) => (
  id: id,
  subject: 'Thông báo $id',
  sender: 'Giảng viên',
  date: date,
  body: 'Nội dung $id',
  unread: true,
);

void main() {
  setUp(dungDbTam);

  test('giữ lại thông báo cũ, mới nhất lên trước', () async {
    await LmsKho.luu([tb('1', date: '2026-10-01 08:00')]);
    // Mẻ sau Moodle không trả về cái cũ nữa — nó vẫn phải còn.
    await LmsKho.luu([tb('2', date: '2026-10-03 08:00')]);
    expect((await LmsKho.doc()).map((n) => n.id), ['2', '1']);
  });

  test('lấy lại mẻ cũ không làm thông báo đã xem chưa đọc lại', () async {
    await LmsKho.luu([tb('1'), tb('2')]);
    await LmsKho.danhDauDaXem('1');
    await LmsKho.luu([tb('1'), tb('2')]);
    final ds = await LmsKho.doc();
    expect(ds.firstWhere((n) => n.id == '1').unread, isFalse);
    expect(ds.firstWhere((n) => n.id == '2').unread, isTrue);
  });

  test('đánh dấu tất cả khi không nói id nào', () async {
    await LmsKho.luu([tb('1'), tb('2')]);
    await LmsKho.danhDauDaXem();
    expect((await LmsKho.doc()).every((n) => !n.unread), isTrue);
  });

  test('thông báo không có id thì bỏ, khỏi đè lên nhau', () async {
    await LmsKho.luu([tb('')]);
    expect(await LmsKho.doc(), isEmpty);
  });
}
