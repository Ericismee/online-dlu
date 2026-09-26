import 'package:dlu_tkb/exams.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sortExams: sắp thi gần nhất trước, rồi đã thi mới nhất trước', () {
    final list = sortExams([
      {'NgayThi': '03/12/2023'},
      {'NgayThi': '20/10/2026'},
      {'NgayThi': '05/10/2026'},
      {'NgayThi': '01/06/2026'},
    ], DateTime(2026, 9, 27));

    expect(list.map((e) => e['NgayThi']), [
      '05/10/2026',
      '20/10/2026',
      '01/06/2026',
      '03/12/2023',
    ]);
  });

  test('examTerm đọc năm/kỳ từ StudyUnitID', () {
    expect(examTerm({'StudyUnitID': '251QP2101D'}), ('2025-2026', 'HK01'));
    expect(examTerm({'StudyUnitID': '232IT1234'}), ('2023-2024', 'HK02'));
    expect(examTerm({'StudyUnitID': ''}), null);
  });
}
