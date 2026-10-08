import 'dart:math';

import 'package:dlu_tkb/cache.dart';
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

  test('hôm nay hết chỗ thì dời sang ngày mai, không lố qua nửa đêm', () async {
    // 23h50: hôm nay chỉ còn từ 0h20 hôm sau trở đi, tức là hết chỗ.
    final now = DateTime(2026, 9, 29, 23, 50);
    final (ngay, viec) = await deXuatViec(
      han(DateTime(2026, 9, 30, 23, 59)),
      now,
    );
    expect(ngay, DateTime(2026, 9, 30));
    expect(viec.batDau + 90, lessThanOrEqualTo(24 * 60));
  });

  test('không ngày nào còn chỗ thì vẫn nằm gọn trong ngày', () async {
    final now = DateTime(2026, 9, 29, 23, 50);
    // Hạn ngay trong đêm nay: không còn ngày nào để dời.
    final (ngay, viec) = await deXuatViec(
      han(DateTime(2026, 9, 29, 23, 59)),
      now,
    );
    expect(ngay, DateTime(2026, 9, 29));
    expect(viec.batDau, greaterThanOrEqualTo(0));
    expect(viec.ketThuc, lessThanOrEqualTo(24 * 60));
  });

  test('hạn đã qua thì vẫn đề xuất được, không kẹt vòng lặp', () async {
    final now = DateTime(2026, 9, 29, 10, 0);
    final (ngay, viec) = await deXuatViec(
      han(DateTime(2026, 9, 28, 9, 0)),
      now,
    );
    expect(ngay, DateTime(2026, 9, 29));
    expect(viec.batDau, greaterThanOrEqualTo(10 * 60 + 30));
  });

  test('đọc lịch ngày từ cache đúng khoá mà fetchMonth đã ghi', () async {
    // Tháng 1 thuộc HK01 của niên khoá trước, mà yearTermFor(ngày) cũng ra
    // HK01 — chỗ dễ trượt là tháng 8: ngày 1/8 thuộc niên khoá mới.
    final d = DateTime(2026, 8, 3); // thứ hai
    final (nam, ky) = yearTermFor(DateTime(d.year, d.month));
    await Cache.write(
      '/api/student/DrawingSchedules_v2'
      '?namhoc=$nam&hocky=$ky&tuan=${isoWeek(d)}',
      {
        'ResultDataSchedule': [
          {
            'StartDate': '03/08/2026',
            'DayOfWeek': 1,
            'NumberOfPeriods': 4,
            'BeginTime': 'Tiết: 1',
            'EndTime': 'Tiết: 4',
            'PeriodID': 1,
            'CurriculumName': 'Giải tích',
            'RoomID': 'A1.203',
          },
        ],
      },
    );
    expect(lichNgayTuCache(d), hasLength(1));
    // Ngày không có gì trong cache thì coi như trống, không nổ.
    expect(lichNgayTuCache(DateTime(2026, 8, 4)), isEmpty);
  });
}
