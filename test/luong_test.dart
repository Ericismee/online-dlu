import 'dart:convert';

import 'package:dlu_tkb/luong.dart';
import 'package:flutter_test/flutter_test.dart';

/// Chạy bằng `test` chứ không `testWidgets`: isolate thật cần vòng lặp sự kiện
/// thật, còn binding của widget test thì giả lập đồng hồ.
void main() {
  final goc = nguongLuong;
  tearDown(() => nguongLuong = goc);

  test('cục lớn đi isolate, cục nhỏ làm tại chỗ, kết quả như nhau', () async {
    final to = [
      for (var i = 0; i < 2000; i++) {'id': i, 'ten': 'Môn học số $i'},
    ];
    final bytes = utf8.encode(jsonEncode(to));
    expect(bytes.length, greaterThan(nguongLuong));
    expect(await giaiMa(bytes), to);

    nguongLuong = 1 << 30;
    expect(await giaiMa(bytes), to);
  });

  test('giaiMaNhieu giữ đúng thứ tự dù qua isolate hay không', () async {
    final raw = [
      for (var i = 0; i < 500; i++) jsonEncode({'i': i}),
    ];
    for (final n in [1, 1 << 30]) {
      nguongLuong = n;
      final ra = await giaiMaNhieu(raw);
      expect(ra, hasLength(500));
      expect((ra.first as Map)['i'], 0);
      expect((ra.last as Map)['i'], 499);
    }
  });

  test('mã hoá qua isolate ra đúng chuỗi như mã hoá tại chỗ', () async {
    final dai = [for (var i = 0; i < 100; i++) i];
    expect(await maHoa(dai), jsonEncode(dai));
    expect(await maHoa({'a': 1}), '{"a":1}');
    expect(await maHoaNhieu(dai), [for (final i in dai) '$i']);
    expect(await maHoaNhieu([1, 2]), ['1', '2']);
  });
}
