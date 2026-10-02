import 'package:dlu_tkb/main.dart';
import 'package:dlu_tkb/settings.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

void main() {
  setUp(dungDbTam);

  test('chưa kéo bao giờ thì giữ nguyên thứ tự mặc định', () {
    expect(sapTheoThuTu([1, 2, 3], const [], (e) => e), [1, 2, 3]);
  });

  test('xếp theo thứ tự đã lưu', () {
    expect(sapTheoThuTu([1, 2, 3], const [3, 1, 2], (e) => e), [3, 1, 2]);
  });

  test('mục mới của bản cập nhật rơi xuống cuối, không biến mất', () {
    // Thứ tự cũ chưa biết mục 4; mã 9 là mục đã gỡ nên bỏ qua.
    expect(sapTheoThuTu([1, 2, 3, 4], const [9, 3, 1], (e) => e), [3, 1, 2, 4]);
  });

  test('thứ tự menu lưu rồi đọc lại đúng, chưa lưu thì rỗng', () async {
    expect(await Settings.thuTuMenu(), isEmpty);
    await Settings.datThuTuMenu(const [-5, 0, 3]);
    expect(await Settings.thuTuMenu(), [-5, 0, 3]);
  });
}
