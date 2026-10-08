import 'dart:convert';
import 'dart:math';

import 'db.dart';
import 'lin_ucb.dart';

/// Khung giờ gợi ý: hai tiếng một khung, từ 6h tới 22h. Chia thô vậy vì dữ
/// liệu học được chỉ là vài chục lần đặt lịch — chia nhỏ tới từng 30 phút thì
/// khung nào cũng trống, gợi ý hoá ra bốc thăm.
const goiYKhungDau = 6;
const goiYSoKhung = 8;

int gioCuaKhung(int k) => (goiYKhungDau + k * 2) * 60;

int khungCuaGio(int phut) =>
    ((phut ~/ 60 - goiYKhungDau) ~/ 2).clamp(0, goiYSoKhung - 1);

/// Các khung còn đặt được: khung nào bị một khoảng trong [ban] đè lên thì bỏ.
/// Kín hết thì trả rỗng — nơi gọi tự quyết là chen đại hay dời sang ngày
/// khác, ở đây không nói dối là còn chỗ.
Set<int> khungRanh(List<(int, int)> ban) {
  final ranh = <int>{};
  for (var k = 0; k < goiYSoKhung; k++) {
    final dau = gioCuaKhung(k);
    final cuoi = dau + 120;
    if (!ban.any((b) => dau < b.$2 && b.$1 < cuoi)) ranh.add(k);
  }
  return ranh;
}

/// Ngữ cảnh một ngày. Toàn cờ 0/1 nên không cần chuẩn hoá thang đo: giờ rảnh
/// để làm việc riêng phụ thuộc chủ yếu vào hôm đó phải lên lớp buổi nào.
List<double> dacTrungGoiY({
  required bool cuoiTuan,
  required bool sang,
  required bool chieu,
  required bool toi,
}) => [
  1, // hằng số, để mô hình học được mức nền
  cuoiTuan ? 1 : 0,
  sang ? 1 : 0,
  chieu ? 1 : 0,
  toi ? 1 : 0,
];

const goiYSoChieu = 5;

/// Gợi ý giờ cho lịch tự đặt, học dần từ chính giờ người dùng chốt.
///
/// Mô hình nằm trong SQLite như mọi thứ khác; ghi đè chứ không xoá, và khung
/// giờ nào đổi thì bản cũ bị bỏ qua chứ không ghép bừa.
class GoiYGio {
  static const _khoa = 'lich_rieng';

  /// Test cắm Random cố định để kết quả khỏi nhảy.
  static Random? ngau;

  static LinUCB? _bo;

  static Future<LinUCB> _nap() async {
    if (_bo != null) return _bo!;
    final d = await Db.i.doc(nhomGoiY, _khoa);
    if (d != null && d.giaTri.isNotEmpty) {
      final cu = LinUCB.fromJson(
        jsonDecode(d.giaTri) as Map<String, dynamic>,
        soTay: goiYSoKhung,
        soChieu: goiYSoChieu,
        ngau: ngau,
      );
      if (cu != null) return _bo = cu;
    }
    return _bo = LinUCB(soTay: goiYSoKhung, soChieu: goiYSoChieu, ngau: ngau);
  }

  /// Quên bản đang giữ trong RAM — đổi tài khoản là đổi sổ, mô hình phải đọc
  /// lại từ sổ mới.
  static void quen() => _bo = null;

  /// Giờ nên đặt (phút từ 0h) cho ngữ cảnh [x]. [ban] là các khoảng giờ đã
  /// kín trong ngày (phút từ 0h) — khung nào đụng vào thì loại khỏi danh sách
  /// chọn, bandit chỉ quyết trong những khung thật sự đặt được.
  static Future<int> goiY(List<double> x, {List<(int, int)> ban = const []}) {
    final ranh = khungRanh(ban);
    // Kín sạch thì bỏ ràng buộc, trả về giờ quen thuộc nhất — nơi gọi biết
    // rõ hơn là nên chen vào hay dời ngày, đừng tự ý quyết hộ ở đây.
    return _nap().then(
      (m) => gioCuaKhung(m.chon(x, choPhep: ranh.isEmpty ? null : ranh)),
    );
  }

  /// Hôm đó còn chỗ nào đặt được không — nơi gọi muốn dời ngày thì hỏi cái
  /// này trước, khỏi phải đoán qua giá trị [goiY] trả về.
  static bool conCho(List<(int, int)> ban) => khungRanh(ban).isNotEmpty;

  /// Người dùng chốt giờ nào thì khung đó được thưởng; khung đã gợi ý mà bị
  /// bỏ qua thì ăn 0 — đúng một lượt học cho mỗi tay đã "chơi".
  static Future<void> ghiNhan({
    required List<double> x,
    required int goiYPhut,
    required int chonPhut,
  }) async {
    final m = await _nap();
    final goi = khungCuaGio(goiYPhut);
    final chon = khungCuaGio(chonPhut);
    m.hoc(chon, x, 1);
    if (goi != chon) m.hoc(goi, x, 0);
    await Db.i.ghi(nhomGoiY, _khoa, giaTri: jsonEncode(m.toJson()));
  }
}
