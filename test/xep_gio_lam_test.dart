import 'dart:math';

import 'package:dlu_tkb/custom_lich.dart';
import 'package:dlu_tkb/goi_y_gio.dart';
import 'package:dlu_tkb/graph.dart';
import 'package:dlu_tkb/lms.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

LmsEvent han(DateTime luc) => (
  name: 'Bài thực hành 03',
  course: 'Mẫu Thiết kế',
  start: luc,
  keoDai: Duration.zero,
  loai: 'assign',
  url: null,
  instance: 1,
  xong: false,
);

void main() {
  setUp(() async {
    await dungDbTam();
    GoiYGio.quen();
    GoiYGio.ngau = Random(3);
  });
  tearDown(() => GoiYGio.ngau = null);

  test('xếp vào chỗ trống sau giờ hiện tại, dài 90 phút', () async {
    final now = DateTime(2026, 9, 29, 9, 0);
    final (ngay, viec) = await deXuatViec(
      han(DateTime(2026, 9, 30, 23, 59)),
      now,
    );
    expect(ngay, DateTime(2026, 9, 29));
    expect(viec.tieuDe, 'Làm: Bài thực hành 03');
    expect(viec.ketThuc! - viec.batDau, 90);
    // Không xếp vào giờ đã trôi qua (còn chừa 30 phút để kịp ngồi vào bàn).
    expect(viec.batDau, greaterThanOrEqualTo(9 * 60 + 30));
  });

  test('né lịch tự đặt đã có trong ngày', () async {
    final now = DateTime(2026, 9, 29, 8, 0);
    await CustomLichStore.add(
      DateTime(2026, 9, 29),
      const CustomLich(tieuDe: 'Lên ATC', batDau: 13 * 60, ketThuc: 17 * 60),
    );
    final (_, viec) = await deXuatViec(han(DateTime(2026, 9, 30, 23, 59)), now);
    // Chen vào 13h–17h là đụng mục đã có.
    expect(viec.batDau < 13 * 60 || viec.batDau >= 17 * 60, isTrue);
  });

  test('hạn ngay hôm nay thì không xếp sau hạn', () async {
    final now = DateTime(2026, 9, 29, 8, 0);
    final (_, viec) = await deXuatViec(han(DateTime(2026, 9, 29, 15, 0)), now);
    expect(viec.batDau, lessThan(15 * 60));
  });

  test(
    'kín sạch thì vẫn đẩy về sau giờ hiện tại, không lùi vào quá khứ',
    () async {
      final now = DateTime(2026, 9, 29, 20, 0);
      // Hạn 21h hôm nay: mọi khung đều bị loại (quá khứ hoặc sau hạn).
      final (_, viec) = await deXuatViec(
        han(DateTime(2026, 9, 29, 21, 0)),
        now,
      );
      expect(viec.batDau, 20 * 60 + 30);
    },
  );
}
