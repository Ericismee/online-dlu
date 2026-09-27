import 'package:flutter_test/flutter_test.dart';

import 'package:dlu_tkb/data.dart';
import 'package:dlu_tkb/marks.dart';

void main() {
  test('chưa chọn môn nào thì GPA giữ nguyên', () {
    expect(gpaDuBao(gpa: 2.58, tc: 104, them: const []), (2.58, 104));
  });

  test('GPA dự kiến là trung bình có trọng số theo tín chỉ', () {
    final (gpa, tc) = gpaDuBao(
      gpa: 3.0,
      tc: 100,
      them: const [(2, 4.0), (3, 2.0)],
    );
    expect(tc, 105);
    // (3*100 + 2*4 + 3*2) / 105
    expect(gpa, closeTo(314 / 105, 1e-9));
  });

  test('chuaCoDiem bỏ môn đã có điểm và học phần điều kiện', () {
    final rows = [
      {'CurriculumName': 'Toán', 'DiemTK_10': 8.0},
      {'CurriculumName': 'Lý', 'DiemTK_10': null},
      {'CurriculumName': 'Hoá', 'DiemTK_10': ''},
      {'CurriculumName': 'Giáo dục quốc phòng*', 'DiemTK_10': null},
    ];
    final con = chuaCoDiem(rows);
    expect(con.map((m) => subjectName(m['CurriculumName'])), ['Lý', 'Hoá']);
  });

  test('thang 4 đủ tám mức, A cao nhất F bằng không', () {
    expect(thang4.first, ('A', 4.0));
    expect(thang4.last, ('F', 0.0));
    expect(thang4.length, 8);
  });
}
