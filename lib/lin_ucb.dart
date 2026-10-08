import 'dart:math';

/// LinUCB rời (disjoint LinUCB, Li et al. 2010): mỗi "tay" giữ mô hình tuyến
/// tính riêng, chọn tay có điểm `θᵀx + α·√(xᵀA⁻¹x)` cao nhất. Vế sau là bề
/// rộng khoảng tin cậy — tay nào còn ít dữ liệu thì được cộng điểm để còn
/// được thử, chứ không phải cứ bám mãi tay đầu tiên trúng.
///
/// Giữ thẳng `A⁻¹` rồi cập nhật theo công thức Sherman–Morrison, khỏi phải
/// nghịch đảo ma trận sau mỗi lượt học: với vài chiều thì nghịch đảo không
/// tốn mấy, nhưng viết ra là thêm một đoạn dễ sai mà chẳng được gì.
class LinUCB {
  /// Thăm dò vừa phải. Để cao (1.0 như trong bài báo gốc) thì với vài chục
  /// mẫu và toàn đặc trưng 0/1, phần thăm dò lấn hết phần đã học — gợi ý nhảy
  /// lung tung, người dùng sửa tay hoài rồi thôi không thèm nhìn nữa.
  static const alphaMacDinh = 0.25;

  LinUCB({
    required int soTay,
    required this.soChieu,
    this.alpha = alphaMacDinh,
    Random? ngau,
  }) : _ngau = ngau ?? Random(),
       _nghichDao = [for (var i = 0; i < soTay; i++) _donVi(soChieu)],
       _b = [for (var i = 0; i < soTay; i++) List.filled(soChieu, 0.0)];

  LinUCB._(this._nghichDao, this._b, this.soChieu, this.alpha, this._ngau);

  final int soChieu;

  /// Hệ số thăm dò. Cao thì hay thử tay lạ, thấp thì bám cái đang ăn.
  final double alpha;

  final Random _ngau;

  /// `A⁻¹` của từng tay, ma trận [soChieu]×[soChieu] trải phẳng theo hàng.
  final List<List<double>> _nghichDao;

  /// `b = Σ thưởng·x` của từng tay.
  final List<List<double>> _b;

  int get soTay => _b.length;

  static List<double> _donVi(int d) => [
    for (var i = 0; i < d; i++)
      for (var j = 0; j < d; j++) i == j ? 1.0 : 0.0,
  ];

  List<double> _nhan(List<double> m, List<double> x) => [
    for (var i = 0; i < soChieu; i++)
      _cham(m.sublist(i * soChieu, i * soChieu + soChieu), x),
  ];

  static double _cham(List<double> a, List<double> b) {
    var s = 0.0;
    for (var i = 0; i < a.length; i++) {
      s += a[i] * b[i];
    }
    return s;
  }

  /// Điểm UCB của một tay trong ngữ cảnh [x].
  double diem(int tay, List<double> x) {
    final ax = _nhan(_nghichDao[tay], x);
    final theta = _nhan(_nghichDao[tay], _b[tay]);
    return _cham(theta, x) + alpha * sqrt(max(_cham(x, ax), 0));
  }

  /// Tay đáng chọn nhất. Lúc chưa có dữ liệu thì mọi tay điểm bằng nhau —
  /// bốc ngẫu nhiên trong đám đồng điểm, chứ cứ lấy tay đầu thì bộ gợi ý mãi
  /// mãi nói đúng một giờ và không bao giờ học được gì khác.
  /// [choPhep] null là xét mọi tay; có thì chỉ xét những tay trong đó — phần
  /// thưởng học được chẳng ích gì nếu giờ ấy đã kín lịch.
  ///
  /// Null chứ không phải tập rỗng: rỗng là "không tay nào đặt được", mà gộp
  /// hai thứ đó làm một thì lúc kín lịch cả ngày ràng buộc bị bỏ qua lặng
  /// lẽ và bộ gợi ý chỉ thẳng vào giữa giờ học.
  int chon(List<double> x, {Set<int>? choPhep}) {
    var cao = double.negativeInfinity;
    final nhat = <int>[];
    for (var a = 0; a < soTay; a++) {
      if (choPhep != null && !choPhep.contains(a)) continue;
      final d = diem(a, x);
      if (d > cao + 1e-9) {
        cao = d;
        nhat
          ..clear()
          ..add(a);
      } else if (d > cao - 1e-9) {
        nhat.add(a);
      }
    }
    // Mọi tay đều bị loại (kín lịch cả ngày) thì đành trả tay đầu, nơi gọi
    // còn hơn là không có gì để điền sẵn.
    if (nhat.isEmpty) return 0;
    return nhat[_ngau.nextInt(nhat.length)];
  }

  /// Ghi nhận [thuong] cho [tay] trong ngữ cảnh [x].
  void hoc(int tay, List<double> x, double thuong) {
    final m = _nghichDao[tay];
    // `A` là đơn vị cộng dồn các `xxᵀ` nên đối xứng, `A⁻¹` cũng vậy — `xᵀA⁻¹`
    // chính là `A⁻¹x`, khỏi tính riêng.
    final ax = _nhan(m, x);
    final mau = 1 + _cham(x, ax);
    for (var i = 0; i < soChieu; i++) {
      for (var j = 0; j < soChieu; j++) {
        m[i * soChieu + j] -= ax[i] * ax[j] / mau;
      }
    }
    for (var i = 0; i < soChieu; i++) {
      _b[tay][i] += thuong * x[i];
    }
  }

  Map<String, dynamic> toJson() => {
    'chieu': soChieu,
    'alpha': alpha,
    'ainv': _nghichDao,
    'b': _b,
  };

  /// Đọc lại mô hình đã lưu. Số tay hay số chiều đổi (app nâng cấp, thêm
  /// khung giờ) thì bản cũ không dùng được nữa — trả null để nơi gọi dựng
  /// mô hình mới, đừng cố ghép vào rồi lệch chỉ số.
  static LinUCB? fromJson(
    Map<String, dynamic> j, {
    required int soTay,
    required int soChieu,
    Random? ngau,
  }) {
    final ainv = (j['ainv'] as List?)
        ?.map((r) => [for (final v in r as List) (v as num).toDouble()])
        .toList();
    final b = (j['b'] as List?)
        ?.map((r) => [for (final v in r as List) (v as num).toDouble()])
        .toList();
    if (ainv == null || b == null) return null;
    if (ainv.length != soTay || b.length != soTay) return null;
    if (ainv.any((r) => r.length != soChieu * soChieu)) return null;
    if (b.any((r) => r.length != soChieu)) return null;
    return LinUCB._(
      ainv,
      b,
      soChieu,
      (j['alpha'] as num?)?.toDouble() ?? alphaMacDinh,
      ngau ?? Random(),
    );
  }
}
