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

/// Đệm hai đầu mỗi khoảng bận khi che khung: tan tiết còn phải dọn đồ, đi về.
/// Cùng con số với `demDuongPhut` bên nhắc giờ nhưng để riêng, bên kia là mặc
/// định của một tuỳ chọn người dùng còn đây là ràng buộc cứng.
const goiYDemPhut = 15;

/// Lớp che ràng buộc cứng (masking): khung nào đụng [ban] — tiết chính quy,
/// lịch cố định, giờ đã trôi qua, phần sau hạn nộp — thì bandit không được
/// phép chọn, bất kể nó học được gì. Che trước khi tính điểm chứ không phạt
/// sau: thói quen có thích 14h mấy mà hôm đó 14h có tiết thì gợi ý 14h cũng
/// chỉ tổ bắt người dùng sửa tay.
///
/// Kín hết thì trả rỗng — nơi gọi tự quyết là chen đại hay dời sang ngày
/// khác, ở đây không nói dối là còn chỗ.
Set<int> khungRanh(List<(int, int)> ban, {int dem = goiYDemPhut}) {
  final ranh = <int>{};
  for (var k = 0; k < goiYSoKhung; k++) {
    final dau = gioCuaKhung(k);
    final cuoi = dau + 120;
    if (!ban.any((b) => dau < b.$2 + dem && b.$1 - dem < cuoi)) ranh.add(k);
  }
  return ranh;
}

/// Nửa đời của độ gấp: còn đúng một ngày tới hạn thì gấp 0,5; còn ba ngày thì
/// 0,125; còn một tuần thì gần như bằng không.
const goiYNuaDoiHan = Duration(hours: 24);

/// Độ gấp của một hạn, suy giảm theo hàm mũ: 1 là tới hạn tới nơi, 0 là không
/// có hạn nào treo. Mũ chứ không tuyến tính vì sốt ruột không tuyến tính —
/// hạn còn 10 ngày với còn 12 ngày thì chẳng khác gì nhau, mà còn 2 giờ với
/// còn 12 giờ thì khác hẳn.
double gapHan(Duration? conLai) {
  if (conLai == null) return 0;
  if (conLai <= Duration.zero) return 1;
  return exp(-ln2 * conLai.inMinutes / goiYNuaDoiHan.inMinutes);
}

/// Ngày học bao nhiêu phút thì coi như kiệt sức — quá mức này mức tải bão hoà
/// ở 1. Sáu tiếng ngồi lớp là đủ để tối đó chẳng làm được gì nữa.
const goiYPhutKietSuc = 6 * 60;

/// Mức tải của một ngày, 0 là ngày trống và 1 là ngày kín. Sức còn lại là
/// `1 - tải`; không áp đặt dấu, để mỗi khung tự học lấy — khung tối của ngày
/// kín khác hẳn khung tối của ngày rảnh.
double taiNgay(int phutHoc) => (phutHoc / goiYPhutKietSuc).clamp(0, 1);

/// Ngữ cảnh một ngày. Bốn cờ 0/1 (khỏi phải chuẩn hoá thang đo) cộng hai số
/// liên tục đã nằm sẵn trong [0, 1]: [gap] là độ gấp của hạn đang treo, [tai]
/// là ngày đó học nặng tới đâu.
List<double> dacTrungGoiY({
  required bool cuoiTuan,
  required bool sang,
  required bool chieu,
  required bool toi,
  double gap = 0,
  double tai = 0,
}) => [
  1, // hằng số, để mô hình học được mức nền
  cuoiTuan ? 1 : 0,
  sang ? 1 : 0,
  chieu ? 1 : 0,
  toi ? 1 : 0,
  gap,
  tai,
];

const goiYSoChieu = 7;

/// Vị trí [gap] trong vectơ đặc trưng — phần khởi động đọc tới để biết hạn có
/// gấp không.
const goiYViTriGap = 5;

/// Dưới chừng này lượt học thì mô hình chưa biết gì: tám tay bảy chiều mà chỉ
/// vài mẫu thì phần thăm dò quyết hết, gợi ý nhảy lung tung đúng lúc người
/// dùng còn đang cân nhắc có tin tính năng này không.
const goiYWarmup = 8;

/// Thứ tự khung lúc còn khởi động, xếp theo giờ sinh viên hay làm việc riêng:
/// chiều tối trước, rồi chiều, rồi sáng muộn; 6h sáng và 12h trưa để sau cùng.
const _uuTien = [6, 7, 4, 2, 5, 1, 3, 0];

/// Khung chọn lúc chưa đủ dữ liệu. Hạn gấp thì lấy khung rảnh sớm nhất — làm
/// liền còn kịp; không gấp thì theo thứ tự quen thuộc [_uuTien].
int khungWarmup(List<double> x, Set<int> ranh) {
  if (ranh.isEmpty) return _uuTien.first;
  final gap = x.length > goiYViTriGap ? x[goiYViTriGap] : 0.0;
  if (gap >= 0.5) return ranh.reduce(min);
  return _uuTien.firstWhere(ranh.contains, orElse: () => ranh.first);
}

/// Thưởng cho khung đã gợi ý mà người dùng dời đi chỗ khác: lệch một khung
/// (hai tiếng) thì vẫn là suýt đúng, lệch sáu khung là sai hẳn. Cho 0 tuốt
/// thì mô hình học chậm hơn vì lần nào trượt cũng mất sạch thông tin "suýt".
double thuongLech(int lech) => lech == 0 ? 1 : exp(-lech.toDouble()) / 2;

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
  /// kín trong ngày (phút từ 0h) — khung nào đụng vào thì bị che, bandit chỉ
  /// quyết trong những khung thật sự đặt được.
  static Future<int> goiY(List<double> x, {List<(int, int)> ban = const []}) {
    final ranh = khungRanh(ban);
    // Kín sạch thì bỏ ràng buộc, trả về giờ quen thuộc nhất — nơi gọi biết
    // rõ hơn là nên chen vào hay dời ngày, đừng tự ý quyết hộ ở đây.
    return _nap().then(
      (m) => gioCuaKhung(
        m.luot < goiYWarmup
            ? khungWarmup(x, ranh)
            : m.chon(x, choPhep: ranh.isEmpty ? null : ranh),
      ),
    );
  }

  /// Hôm đó còn chỗ nào đặt được không — nơi gọi muốn dời ngày thì hỏi cái
  /// này trước, khỏi phải đoán qua giá trị [goiY] trả về.
  static bool conCho(List<(int, int)> ban) => khungRanh(ban).isNotEmpty;

  /// Người dùng chốt giờ nào thì khung đó được thưởng; khung đã gợi ý mà bị
  /// dời thì ăn phần theo độ lệch ([thuongLech]) — một lượt học cho cả hai
  /// tay, vì mô hình quên dần theo lượt: tách thành hai lượt là tự tay hạ giá
  /// cái vừa học xong.
  static Future<void> ghiNhan({
    required List<double> x,
    required int goiYPhut,
    required int chonPhut,
  }) {
    final goi = khungCuaGio(goiYPhut);
    final chon = khungCuaGio(chonPhut);
    return _hoc(x, {
      chon: 1,
      if (goi != chon) goi: thuongLech((goi - chon).abs()),
    });
  }

  /// Phản hồi thật sau khi buổi đã đặt trôi qua: làm xong thì khung đó đáng
  /// tin, xoá đi thì không. Giờ người dùng *chốt* chỉ là ý định, còn đây mới
  /// là chuyện đã xảy ra, nên nó cũng đáng một lượt học.
  static Future<void> phanHoi({
    required List<double> x,
    required int phut,
    required bool xong,
  }) => _hoc(x, {khungCuaGio(phut): xong ? 1 : 0});

  static Future<void> _hoc(List<double> x, Map<int, double> thuong) async {
    final m = await _nap();
    m.hoc(x, thuong);
    await Db.i.ghi(nhomGoiY, _khoa, giaTri: jsonEncode(m.toJson()));
  }
}
