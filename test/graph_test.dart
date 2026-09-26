import 'package:dlu_tkb/graph.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isoWeek matches the portal week numbers', () {
    expect(isoWeek(DateTime(2026, 9, 21)), 39); // thứ 2 của tuần 39
    expect(isoWeek(DateTime(2026, 9, 27)), 39); // chủ nhật cùng tuần
    expect(isoWeek(DateTime(2026, 9, 28)), 40);
  });

  test('periodsByDay sums periods per day and drops other months', () {
    final items = [
      {'StartDate': '21/09/2026', 'DayOfWeek': 1, 'NumberOfPeriods': 4},
      {'StartDate': '21/09/2026', 'DayOfWeek': 1, 'NumberOfPeriods': 4},
      {'StartDate': '21/09/2026', 'DayOfWeek': 3, 'NumberOfPeriods': 4},
      {'StartDate': '28/09/2026', 'DayOfWeek': 4, 'NumberOfPeriods': 4}, // 1/10
    ];
    expect(periodsByDay(items, DateTime(2026, 9)), {21: 8, 23: 4});
  });
}
