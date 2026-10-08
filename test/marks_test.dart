import 'dart:convert';

import 'package:dlu_tkb/marks.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:dlu_tkb/paper.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

final _blank = [
  {
    'NamHoc': '2026-2027',
    'DanhSachDiem': [
      {
        'HocKy': 'HK01',
        'DanhSachDiemHK': [
          {
            'CurriculumName': 'Toán',
            'Credits': 3,
            'DiemTK_10': null,
            'DiemTK_Chu': null,
            'IsPass': null,
            'TB_HK_10': null,
            'TB_HK_4': null,
            'TB_TL_TN': '2.58',
            'T_TC_TL_TN': 104,
            'TenXepLoai': 'Khá',
          },
        ],
      },
    ],
  },
];

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
  setUp(dungDbTam);

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

  test('canCaiThien lấy môn dưới B, bỏ môn đã giỏi và học phần điều kiện', () {
    final subjects = [
      {'CurriculumName': 'Toán', 'DiemTK_Chu': 'C+'},
      {'CurriculumName': 'Lý', 'DiemTK_Chu': 'A'}, // đã giỏi -> bỏ
      {'CurriculumName': 'Hoá', 'DiemTK_Chu': 'F'}, // trượt, kéo mạnh nhất
      {'CurriculumName': 'GDTC*', 'DiemTK_Chu': 'D'}, // điều kiện -> bỏ
      {'CurriculumName': 'Sinh', 'DiemTK_Chu': 'B'}, // đúng B -> bỏ
    ];
    expect(canCaiThien(subjects).map((m) => m['CurriculumName']), [
      'Toán',
      'Hoá',
    ]);
  });

  test('goiYCaiThien xếp môn kéo GPA mạnh nhất lên đầu', () {
    final years = [
      {
        'NamHoc': '2024-2025',
        'DanhSachDiem': [
          {
            'HocKy': 'HK01',
            'DanhSachDiemHK': [
              // 1 TC mà trượt: lệch 4 điểm nhưng ít tín chỉ -> kéo nhẹ hơn.
              {'CurriculumName': 'Nhỏ', 'Credits': 1, 'DiemTK_Chu': 'F'},
              // 4 TC điểm D: lệch 3 điểm nhưng nhiều tín chỉ -> kéo mạnh nhất.
              {'CurriculumName': 'To', 'Credits': 4, 'DiemTK_Chu': 'D'},
              {'CurriculumName': 'Giỏi', 'Credits': 4, 'DiemTK_Chu': 'A'},
            ],
          },
        ],
      },
    ];
    final g = goiYCaiThien(years, tcTichLuy: 100);
    expect(g.map((e) => e.mon['CurriculumName']), ['To', 'Nhỏ']);
    expect(g.first.tang, closeTo(4 * 3.0 / 100, 1e-9));
    // Chưa có tín chỉ tích luỹ thì không chia được, đừng gợi ý bừa.
    expect(goiYCaiThien(years, tcTichLuy: 0), isEmpty);
  });

  test('he4Cua đọc đúng thang điểm, trả null nếu điểm lạ/chưa có', () {
    expect(he4Cua({'DiemTK_Chu': 'B+'}), 3.5);
    expect(he4Cua({'DiemTK_Chu': null}), isNull);
    expect(he4Cua({'DiemTK_Chu': 'X'}), isNull);
  });

  test('termKeys mới nhất trước, latestScored bỏ kỳ chưa có điểm', () {
    expect(termKeys(_years).first, ('2025-2026', 'HK01'));
    expect(latestScored(_years), ('2024-2025', 'HK01'));
    expect(subjectsOf(_years, ('2024-2025', 'HK01')).length, 1);
  });

  testWidgets('kỳ chưa có điểm vẫn hiện tên môn, ô điểm để gạch', (t) async {
    final portal = Portal(
      client: MockClient((r) async {
        if (r.url.path.contains('GetStudyProgram')) {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode([
                {'StudyProgramID': 'CQ23CT-PM'},
              ]),
            ),
            200,
          );
        }
        return http.Response.bytes(utf8.encode(jsonEncode(_blank)), 200);
      }),
    );
    await t.pumpWidget(
      MaterialApp(
        home: MarksScreen(
          session: Session(
            id: '1',
            fullName: 'A',
            token: 't',
            expire: DateTime(2030),
          ),
          portal: portal,
        ),
      ),
    );
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    // Có môn thì hiện môn, chứ không nuốt cả kỳ chỉ vì chưa chấm điểm.
    expect(find.text('Toán'), findsOneWidget);
    expect(find.text('— · —'), findsOneWidget);
    expect(find.text('Chưa có điểm'), findsNothing);
    expect(find.textContaining('2.58'), findsOneWidget);
    expect(find.textContaining('null'), findsNothing);
  });

  test(
    'GPA hệ 10 là trung bình có trọng số tín chỉ, bỏ học phần điều kiện',
    () {
      final years = [
        {
          'NamHoc': '2025-2026',
          'DanhSachDiem': [
            {
              'HocKy': 'HK01',
              'DanhSachDiemHK': [
                {'CurriculumName': 'Toán', 'Credits': 4, 'DiemTK_10': '8.0'},
                {'CurriculumName': 'Lý', 'Credits': 2, 'DiemTK_10': '5.0'},
                // Học phần điều kiện (dấu *) không tính vào điểm trung bình.
                {
                  'CurriculumName': 'Giáo dục thể chất *',
                  'Credits': 3,
                  'DiemTK_10': '10.0',
                },
                // Chưa có điểm thì chưa tính.
                {'CurriculumName': 'Hoá', 'Credits': 3, 'DiemTK_10': null},
              ],
            },
          ],
        },
      ];
      expect(gpa10(years), closeTo((8 * 4 + 5 * 2) / 6, 1e-9));
    },
  );

  test('học lại thì chỉ lượt điểm cao nhất được tính, không cộng dồn', () {
    final years = [
      {
        'NamHoc': '2024-2025',
        'DanhSachDiem': [
          {
            'HocKy': 'HK01',
            'DanhSachDiemHK': [
              {'CurriculumName': 'Toán', 'Credits': 4, 'DiemTK_10': '4.0'},
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
              {'CurriculumName': 'Toán', 'Credits': 4, 'DiemTK_10': '9.0'},
            ],
          },
        ],
      },
    ];
    expect(gpa10(years), closeTo(9, 1e-9));
    // Chưa có điểm nào thì không bịa ra số 0.
    expect(gpa10(_blank), isNull);
  });
}
