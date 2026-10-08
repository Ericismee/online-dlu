import 'dart:convert';

import 'custom_lich.dart';
import 'data.dart';
import 'graph.dart';

/// Lịch học một tháng thành chuỗi iCalendar (RFC 5545) để nạp vào app Lịch
/// của máy — nhắc giờ học là việc của hệ điều hành, app khỏi nuôi thông báo.
///
/// Giờ để dạng 'floating' (không kèm múi giờ): máy đọc theo giờ địa phương,
/// khỏi phải nhét nguyên khối VTIMEZONE cho mỗi file.
String icsMonth(
  DateTime month,
  Map<int, List<dynamic>> days, {
  DateTime? now,
  Map<int, List<CustomLich>> rieng = const {},
}) {
  final out = StringBuffer()
    ..writeAll([
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//DLU Online//Thoi khoa bieu//VI',
      'CALSCALE:GREGORIAN',
      '',
    ], '\r\n');
  final stamp = _luc((now ?? DateTime.now()).toUtc());
  for (final day in days.keys.toList()..sort()) {
    for (final i in days[day]!) {
      final dau = tietNo(i['BeginTime']);
      final cuoi = tietNo(i['EndTime']);
      final batDau = batDauPhut(dau);
      final ketThuc = batDauPhut(cuoi);
      // Tiết lạ thì bỏ qua, thà thiếu một buổi còn hơn ghi sai giờ vào lịch.
      if (batDau == null || ketThuc == null) continue;
      final d = DateTime(month.year, month.month, day);
      final ten = subjectName(i['CurriculumName']);
      final phong = clean(i['RoomID']);
      final gv = clean(i['FullName']);
      out.writeAll([
        'BEGIN:VEVENT',
        'UID:${d.year}${_pad(d.month)}${_pad(day)}-$dau-$phong@dlu-online',
        'DTSTAMP:$stamp',
        'DTSTART:${_gioDia(d, batDau)}',
        'DTEND:${_gioDia(d, ketThuc + tietPhut)}',
        _fold('SUMMARY:${_esc(ten)}'),
        if (phong.isNotEmpty) _fold('LOCATION:${_esc('Phòng $phong')}'),
        _fold(
          'DESCRIPTION:${_esc('Tiết $dau-$cuoi${gv.isEmpty ? '' : ' · GV: $gv'}')}',
        ),
        // Nhắc trước 15 phút — có dòng này thì app Lịch mới rung,
        // không thì buổi học chỉ nằm im trong lịch.
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'TRIGGER:-PT15M',
        _fold('DESCRIPTION:${_esc(ten)}'),
        'END:VALARM',
        'END:VEVENT',
        '',
      ], '\r\n');
    }
  }
  for (final day in rieng.keys.toList()..sort()) {
    final d = DateTime(month.year, month.month, day);
    for (final (n, c) in rieng[day]!.indexed) {
      // Không biết giờ về thì cho một tiếng — app Lịch nào cũng cần DTEND,
      // mà để 0 phút thì nhiều app vẽ thành vạch mỏng không bấm trúng.
      final ket = c.ketThuc == null || c.ketThuc! <= c.batDau
          ? c.batDau + 60
          : c.ketThuc!;
      final noi = c.viTri?.trim() ?? '';
      out.writeAll([
        'BEGIN:VEVENT',
        'UID:${d.year}${_pad(d.month)}${_pad(day)}-rieng$n@dlu-online',
        'DTSTAMP:$stamp',
        'DTSTART:${_gioDia(d, c.batDau)}',
        'DTEND:${_gioDia(d, ket)}',
        _fold('SUMMARY:${_esc(c.tieuDe)}'),
        if (noi.isNotEmpty) _fold('LOCATION:${_esc(noi)}'),
        'BEGIN:VALARM',
        'ACTION:DISPLAY',
        'TRIGGER:-PT15M',
        _fold('DESCRIPTION:${_esc(c.tieuDe)}'),
        'END:VALARM',
        'END:VEVENT',
        '',
      ], '\r\n');
    }
  }
  out.write('END:VCALENDAR\r\n');
  return out.toString();
}

/// Số buổi sẽ được ghi vào file — để hỏi người dùng cho rõ trước khi xuất.
int icsCount(
  Map<int, List<dynamic>> days, [
  Map<int, List<CustomLich>> rieng = const {},
]) =>
    days.values
        .expand((e) => e)
        .where((i) => batDauPhut(tietNo(i['BeginTime'])) != null)
        .length +
    rieng.values.fold(0, (a, e) => a + e.length);

String _pad(int n) => n.toString().padLeft(2, '0');

String _gioDia(DateTime d, int phut) =>
    '${d.year}${_pad(d.month)}${_pad(d.day)}T${_pad(phut ~/ 60)}${_pad(phut % 60)}00';

String _luc(DateTime utc) =>
    '${utc.year}${_pad(utc.month)}${_pad(utc.day)}T'
    '${_pad(utc.hour)}${_pad(utc.minute)}${_pad(utc.second)}Z';

/// RFC 5545: dấu \ , ; và xuống dòng phải escape, không thì vỡ file.
String _esc(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(',', '\\,')
    .replaceAll(';', '\\;')
    .replaceAll('\n', '\\n');

/// Dòng dài quá 75 octet phải gấp; tên môn tiếng Việt có dấu rất dễ vượt.
String _fold(String line) {
  if (utf8.encode(line).length <= 75) return line;
  final out = StringBuffer();
  var len = 0;
  for (final c in line.split('')) {
    final n = utf8.encode(c).length;
    // Gấp ở 73 octet, chừa chỗ cho CRLF và dấu cách nối dòng.
    if (len + n > 73) {
      out.write('\r\n ');
      len = 1;
    }
    out.write(c);
    len += n;
  }
  return out.toString();
}
