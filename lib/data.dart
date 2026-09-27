/// Portal gắn '*' vào tên học phần điều kiện (GDQP, GDTC...) — học để đủ
/// điều kiện tốt nghiệp nhưng không tính vào điểm trung bình.
bool isCondition(Object? name) => clean(name).endsWith('*');

/// Tên học phần đã bỏ dấu '*' ở cuối.
String subjectName(Object? name) =>
    clean(name).replaceFirst(RegExp(r'\s*\*$'), '');

/// Portal lúc trả số, lúc trả chuỗi, ép về num cho khỏi văng.
num toNum(Object? v) => v is num ? v : (num.tryParse('$v') ?? 0);

/// Portal nhét thẻ html vào vài tên môn, gỡ hết cho sạch.
String clean(Object? v) {
  if (v == null) return '';
  return '$v'
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Tên thứ theo DateTime.weekday (1 = thứ 2).
const dayNames = [
  '',
  'Thứ 2',
  'Thứ 3',
  'Thứ 4',
  'Thứ 5',
  'Thứ 6',
  'Thứ 7',
  'CN',
];

/// Nhãn cho biết số đang xem lấy về lúc nào. Cùng ngày thì chỉ cần giờ.
String dataAge(DateTime at, DateTime now) {
  final gio = '${at.hour}:${at.minute.toString().padLeft(2, '0')}';
  final cungNgay =
      at.year == now.year && at.month == now.month && at.day == now.day;
  return cungNgay
      ? 'Dữ liệu lúc $gio'
      : 'Dữ liệu ${at.day}/${at.month} lúc $gio';
}

/// Gõ 'toan roi rac' vẫn ra 'Toán rời rạc' — sinh viên hiếm ai gõ dấu khi tìm.
const _nhomDau = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

String khongDau(String s) {
  final out = StringBuffer();
  for (final c in s.toLowerCase().split('')) {
    out.write(
      _nhomDau.entries
          .firstWhere((e) => e.value.contains(c), orElse: () => MapEntry(c, ''))
          .key,
    );
  }
  return out.toString();
}

/// Ô tìm kiếm khớp không phân biệt dấu lẫn hoa thường. Gõ rỗng thì khớp hết.
bool khop(String text, String q) =>
    q.trim().isEmpty || khongDau(text).contains(khongDau(q.trim()));
