import 'package:flutter_test/flutter_test.dart';

import 'package:dlu_tkb/ics.dart';

void main() {
  final days = <int, List<dynamic>>{
    1: [
      {
        'BeginTime': 'Tiết: 1',
        'EndTime': 'Tiết: 4',
        'CurriculumName': 'Lập trình, nâng cao*',
        'RoomID': 'A11',
        'FullName': 'Nguyễn Văn A',
      },
    ],
    // Tiết lạ: portal thỉnh thoảng trả tiết 0 / 15, không được bịa giờ.
    3: [
      {'BeginTime': 'Tiết: 0', 'EndTime': 'Tiết: 2', 'RoomID': 'B02'},
    ],
  };

  test('mỗi buổi thành một VEVENT, giờ theo bảng giờ giảng', () {
    final ics = icsMonth(
      DateTime(2026, 9),
      days,
      now: DateTime.utc(2026, 9, 27),
    );
    expect(ics, startsWith('BEGIN:VCALENDAR\r\n'));
    expect(ics, endsWith('END:VCALENDAR\r\n'));
    expect('BEGIN:VEVENT'.allMatches(ics).length, 1);
    expect(ics, contains('DTSTART:20260901T073000'));
    expect(ics, contains('DTEND:20260901T111000'));
    // Có VALARM thì app Lịch mới nhắc, đúng như lời hộp thoại hứa.
    expect(ics, contains('TRIGGER:-PT15M'));
    expect(ics, contains('DTSTAMP:20260927T000000Z'));
    expect(ics, contains('LOCATION:Phòng A11'));
    expect(icsCount(days), 1);
  });

  test('dấu phẩy trong tên môn được escape, dấu sao điều kiện bị bỏ', () {
    final ics = icsMonth(
      DateTime(2026, 9),
      days,
      now: DateTime.utc(2026, 9, 27),
    );
    expect(ics, contains(r'SUMMARY:Lập trình\, nâng cao'));
    expect(ics, isNot(contains('nâng cao*')));
  });

  test('dòng dài quá 75 octet thì gấp, dòng gấp bắt đầu bằng dấu cách', () {
    final dai = {
      1: [
        {
          'BeginTime': 'Tiết: 1',
          'EndTime': 'Tiết: 1',
          'CurriculumName':
              'Những nguyên lý cơ bản của chủ nghĩa Mác Lênin '
              'phần hai dành cho sinh viên khoá bốn bảy',
          'RoomID': 'A11',
        },
      ],
    };
    final ics = icsMonth(DateTime(2026, 9), dai);
    final summary = ics
        .split('\r\n')
        .skipWhile((l) => !l.startsWith('SUMMARY:'))
        .take(2)
        .toList();
    expect(summary.first.length, lessThan(76));
    expect(summary[1], startsWith(' '));
  });
}
