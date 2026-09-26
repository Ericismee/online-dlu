import 'package:dlu_tkb/marks.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:flutter_test/flutter_test.dart';

final _years = [
  {
    'NamHoc': '2024-2025',
    'DanhSachDiem': [
      {
        'HocKy': 'HK01',
        'DanhSachDiemHK': [
          {'TB_HK_10': '5.78', 'DiemTK_10': '6.0', 'IsPass': 'x'},
        ],
      },
    ],
  },
  {
    'NamHoc': '2025-2026',
    'DanhSachDiem': [
      {
        'HocKy': 'HK01',
        'DanhSachDiemHK': [
          {'TB_HK_10': null, 'DiemTK_10': null, 'IsPass': ''},
        ],
      },
    ],
  },
];

void main() {
  test('markColor: đạt / chưa đạt / chưa có điểm', () {
    expect(markColor({'IsPass': 'x', 'DiemTK_10': '8.0'}), Paper.mint);
    expect(markColor({'IsPass': '', 'DiemTK_10': '3.0'}), Paper.rose);
    expect(markColor({'IsPass': '', 'DiemTK_10': null}), Paper.card);
  });

  test('show thay null bằng gạch', () {
    expect(show(null), '—');
    expect(show(''), '—');
    expect(show('7.5'), '7.5');
  });

  test('termKeys mới nhất trước, latestScored bỏ kỳ chưa có điểm', () {
    expect(termKeys(_years).first, ('2025-2026', 'HK01'));
    expect(latestScored(_years), ('2024-2025', 'HK01'));
    expect(subjectsOf(_years, ('2024-2025', 'HK01')).length, 1);
  });
}
