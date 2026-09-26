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
      {'StartDate': '21/09/2026', 'DayOfWeek': 1, 'NumberOfPeriods': 4, 'PeriodID': 11},
      {'StartDate': '21/09/2026', 'DayOfWeek': 1, 'NumberOfPeriods': 4, 'PeriodID': 1},
      {'StartDate': '21/09/2026', 'DayOfWeek': 3, 'NumberOfPeriods': 4, 'PeriodID': 7},
      {'StartDate': '28/09/2026', 'DayOfWeek': 4, 'NumberOfPeriods': 4, 'PeriodID': 1}, // 1/10
    ];
    expect(itemsByDay(items, DateTime(2026, 9)).map((d, l) => MapEntry(d, periods(l))),
        {21: 8, 23: 4});
    // sắp theo tiết, sáng trước tối
    expect(itemsByDay(items, DateTime(2026, 9))[21]!.first['PeriodID'], 1);
    expect(buoi(1), 'Sáng');
    expect(buoi(7), 'Chiều');
    expect(buoi(11), 'Tối');
  });
}
