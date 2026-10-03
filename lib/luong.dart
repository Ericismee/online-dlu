import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Mã hoá / giải mã JSON ngoài luồng UI khi cục dữ liệu đủ lớn.
///
/// SQLite đã chạy isolate riêng (drift_flutter tự dựng), còn JSON thì không:
/// bảng điểm, chương trình đào tạo hay lịch cả tháng là vài trăm KB, giải mã
/// ngay trên luồng UI là tụt khung đúng lúc màn hình đang hiện ra.
///
/// Cục nhỏ vẫn làm tại chỗ: dựng một isolate tốn cỡ vài ms, hơn cả thời gian
/// giải mã mấy trăm byte, mà phần lớn endpoint của portal là cục nhỏ.
// ponytail: ngưỡng đoán theo cỡ payload của portal; máy yếu còn tụt thì hạ
// xuống, đo bằng devtools timeline chứ đừng đoán tiếp.
@visibleForTesting
int nguongLuong = 16 * 1024;

/// Giải mã JSON từ body HTTP.
Future<dynamic> giaiMa(Uint8List bytes) => bytes.length < nguongLuong
    ? Future.value(_giaiMa(bytes))
    : compute(_giaiMa, bytes);

dynamic _giaiMa(Uint8List b) => jsonDecode(utf8.decode(b));

/// Giải mã một loạt chuỗi JSON trong **một** lượt nhảy isolate: mỗi dòng một
/// lượt thì phí gửi nhận còn đắt hơn việc cần làm.
Future<List<dynamic>> giaiMaNhieu(List<String> raw) {
  var co = 0;
  for (final s in raw) {
    co += s.length;
    if (co >= nguongLuong) return compute(_giaiMaNhieu, raw);
  }
  return Future.value(_giaiMaNhieu(raw));
}

List<dynamic> _giaiMaNhieu(List<String> raw) => [
  for (final s in raw) jsonDecode(s),
];

/// Mã hoá JSON. Không biết trước cỡ nên đoán theo số phần tử: danh sách dài
/// mới đáng đẩy sang isolate.
Future<String> maHoa(Object? data) =>
    data is List && data.length >= 50 || data is Map && data.length >= 50
    ? compute(jsonEncode, data)
    : Future.value(jsonEncode(data));

/// Mã hoá từng mục của một mẻ, một lượt nhảy isolate cho cả mẻ.
Future<List<String>> maHoaNhieu(List<dynamic> moi) => moi.length >= 50
    ? compute(_maHoaNhieu, moi)
    : Future.value(_maHoaNhieu(moi));

List<String> _maHoaNhieu(List<dynamic> moi) => [
  for (final m in moi) jsonEncode(m),
];
