import 'package:dlu_tkb/graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isoWeek matches the portal week numbers', () {
    expect(isoWeek(DateTime(2026, 9, 21)), 39); // thứ 2 của tuần 39
    expect(isoWeek(DateTime(2026, 9, 27)), 39); // chủ nhật cùng tuần
    expect(isoWeek(DateTime(2026, 9, 28)), 40);
  });

  test('itemsByDay groups by day and drops other months', () {
    final items = [
      {
        'StartDate': '21/09/2026',
        'DayOfWeek': 1,
        'NumberOfPeriods': 4,
        'PeriodID': 11,
      },
      {
        'StartDate': '21/09/2026',
        'DayOfWeek': 1,
        'NumberOfPeriods': 4,
        'PeriodID': 1,
      },
      {
        'StartDate': '21/09/2026',
        'DayOfWeek': 3,
        'NumberOfPeriods': 4,
        'PeriodID': 7,
      },
      {
        'StartDate': '28/09/2026',
        'DayOfWeek': 4,
        'NumberOfPeriods': 4,
        'PeriodID': 1,
      }, // 1/10
    ];
    expect(
      itemsByDay(
        items,
        DateTime(2026, 9),
      ).map((d, l) => MapEntry(d, periods(l))),
      {21: 8, 23: 4},
    );
    // sắp theo tiết, sáng trước tối
    expect(itemsByDay(items, DateTime(2026, 9))[21]!.first['PeriodID'], 1);
    expect(buoi(1), 'Sáng');
    expect(buoi(7), 'Chiều');
    expect(buoi(11), 'Tối');
  });

  test('yearTermFor suy học kỳ từ tháng', () {
    expect(yearTermFor(DateTime(2026, 9)), ('2026-2027', 'HK01'));
    expect(yearTermFor(DateTime(2027, 1)), ('2026-2027', 'HK01'));
    expect(yearTermFor(DateTime(2027, 3)), ('2026-2027', 'HK02'));
    expect(yearTermFor(DateTime(2027, 7)), ('2026-2027', 'HK03'));
  });

  test('màu ô theo số buổi học trong ngày', () {
    expect(
      dayColor(const []),
      isNot(
        dayColor(const [
          {'PeriodID': 1},
        ]),
      ),
    );
    // hai tiết cùng buổi sáng vẫn là một buổi
    expect(
      dayColor(const [
        {'PeriodID': 1},
        {'PeriodID': 3},
      ]),
      dayColor(const [
        {'PeriodID': 5},
      ]),
    );
    expect(
      dayColor(const [
        {'PeriodID': 1},
        {'PeriodID': 7},
      ]),
      isNot(
        dayColor(const [
          {'PeriodID': 1},
        ]),
      ),
    );
    expect(
      dayColor(const [
        {'PeriodID': 1},
        {'PeriodID': 7},
        {'PeriodID': 12},
      ]),
      isNot(
        dayColor(const [
          {'PeriodID': 1},
          {'PeriodID': 7},
        ]),
      ),
    );
  });

  test('khung giờ theo bảng giờ giảng của trường', () {
    expect(khungGio(1, 1), ('7h30', '8h20'));
    expect(khungGio(1, 4), ('7h30', '11h10'));
    expect(khungGio(7, 10), ('13h00', '16h30'));
    expect(khungGio(11, 14), ('16h40', '20h00'));
    expect(khungGio(0, 3), isNull);
    expect(tietNo('Tiết: 3'), 3);
    expect(buoi(6), 'Sáng');
  });
}
