import 'package:dlu_tkb/courses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recentYears bắt đầu từ năm học hiện tại', () {
    expect(recentYears(DateTime(2026, 9)).first, '2026-2027');
    expect(recentYears(DateTime(2026, 5)).first, '2025-2026');
    expect(recentYears(DateTime(2026, 9)).length, 6);
  });
}
