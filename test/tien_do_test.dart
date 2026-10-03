import 'package:dlu_tkb/graph.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Một buổi: ngày trong tháng, tiết đầu, tiết cuối, số tiết.
Map<String, dynamic> buoi(int tietDau, int tietCuoi, int soTiet) => {
  'PeriodID': tietDau,
  'EndTime': 'Tiết: $tietCuoi',
  'NumberOfPeriods': soTiet,
};

void main() {
  // Tiết 3 vào 9h30, tiết 4 tan 11h10; tiết 7 vào 13h, tiết 8 tan 14h40.
  final thang = {
    1: [buoi(3, 4, 2)],
    15: [buoi(3, 4, 2), buoi(7, 8, 2)],
    28: [buoi(3, 4, 2)],
  };

  test('ngày đã qua tính hết, ngày chưa tới không tính', () {
    expect(tietDaHoc(thang, DateTime(2026, 10, 15, 0, 30)), (2, 8));
  });

  test('buổi hôm nay chỉ tính khi đã tan', () {
    // 10h: đang trong tiết 4 của buổi sáng, chưa tính buổi nào hôm nay.
    expect(tietDaHoc(thang, DateTime(2026, 10, 15, 10)), (2, 8));
    // 11h30: sáng tan rồi, chiều chưa vào.
    expect(tietDaHoc(thang, DateTime(2026, 10, 15, 11, 30)), (4, 8));
    // 15h: hết ngày.
    expect(tietDaHoc(thang, DateTime(2026, 10, 15, 15)), (6, 8));
  });

  test('cuối tháng thì đã học bằng tổng', () {
    expect(tietDaHoc(thang, DateTime(2026, 10, 29)), (8, 8));
  });

  testWidgets('vòng tiến độ hiện số giữa vòng, không tràn khi quá 100%', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              PaperRing(value: 3.21 / 4, center: '3.21', label: 'GPA'),
              // Dữ liệu lệch có thể cho ra hơn 1; vòng phải kẹp lại chứ không
              // vẽ quá một lượt.
              PaperRing(value: 1.4, center: '7/5', label: 'Tiết'),
            ],
          ),
        ),
      ),
    );
    expect(find.text('3.21'), findsOneWidget);
    expect(find.text('7/5'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
