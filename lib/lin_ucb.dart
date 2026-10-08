import 'dart:math';

/// LinUCB rời có quên dần (Discounted LinUCB — Russac và cộng sự 2019, "Weighted
/// Linear Bandits for Non-Stationary Environments"): mỗi "tay" giữ mô hình
/// tuyến tính riêng, chọn tay có điểm `θᵀx + α·√(xᵀA⁻¹x)` cao nhất. Vế sau là
/// bề rộng khoảng tin cậy — tay nào còn ít dữ liệu thì được cộng điểm để còn
/// được thử, chứ không phải cứ bám mãi tay đầu tiên trúng.
///
/// Khác bản gốc ở chỗ mỗi lượt mọi tay đều bị chiết khấu [gamma] trước khi ghi
/// nhận:
///
///     A ← γ·A + (1−γ)·λ·I + Σ x·xᵀ      b ← γ·b + Σ thưởng·x
///
/// Thói quen người dùng không đứng yên: học kỳ đổi thời khoá biểu, giờ rảnh
/// đổi theo. LinUCB thường cộng dồn mãi nên một học kỳ cũ với vài chục mẫu đè
/// chết vài mẫu mới của học kỳ này. Chiết khấu làm mẫu cũ nhẹ dần, mà phần
/// `(1−γ)·λ·I` giữ `A` không teo về 0 — không có nó thì `A⁻¹` phình vô hạn và
/// điểm thăm dò nuốt hết phần đã học.
class LinUCB {
  /// Thăm dò vừa phải. Để cao (1.0 như trong bài báo gốc) thì với vài chục
  /// mẫu và toàn đặc trưng 0/1, phần thăm dò lấn hết phần đã học — gợi ý nhảy
  /// lung tung, người dùng sửa tay hoài rồi thôi không thèm nhìn nữa.
  static const alphaMacDinh = 0.25;

  /// Quên dần: nửa đời khoảng 14 lượt với γ = 0.95. Đặt lịch riêng cỡ vài lần
  /// một tuần thì chừng một tháng là thói quen cũ chỉ còn nửa tiếng nói — vừa
  /// đủ để đổi theo thời khoá biểu mới mà không quên sạch sau một tuần lạ.
  static const gammaMacDinh = 0.95;

  /// Hệ số chuẩn hoá của `λ·I`, cũng là `A` lúc chưa có dữ liệu gì.
  static const _lamBda = 1.0;

  LinUCB({
    required int soTay,
    required this.soChieu,
    this.alpha = alphaMacDinh,
    this.gamma = gammaMacDinh,
    Random? ngau,
  }) : _ngau = ngau ?? Random(),
       _a = [for (var i = 0; i < soTay; i++) _donVi(soChieu, _lamBda)],
       _b = [for (var i = 0; i < soTay; i++) List.filled(soChieu, 0.0)];

  LinUCB._(this._a, this._b, this.soChieu, this.alpha, this.gamma, this._ngau);

  final int soChieu;

  /// Hệ số thăm dò. Cao thì hay thử tay lạ, thấp thì bám cái đang ăn.
  final double alpha;

  /// Hệ số quên, trong khoảng (0, 1]. Bằng 1 là LinUCB thường — nhớ hết.
  final double gamma;

  final Random _ngau;

  /// `A` của từng tay, ma trận [soChieu]×[soChieu] trải phẳng theo hàng.
  final List<List<double>> _a;

  /// `b = Σ thưởng·x` của từng tay, cũng đã chiết khấu.
  final List<List<double>> _b;

  /// `A⁻¹` tính sẵn, xoá mỗi khi `A` đổi. Nghịch đảo một ma trận 5×5 thì rẻ,
  /// nhưng mỗi lượt gợi ý hỏi điểm cả tám tay nên nhớ lại vẫn hơn.
  late final List<List<double>?> _nd = List.filled(soTay, null);

  int get soTay => _b.length;

  static List<double> _donVi(int d, [double he = 1.0]) => [
    for (var i = 0; i < d; i++)
      for (var j = 0; j < d; j++) i == j ? he : 0.0,
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

  /// Nghịch đảo ma trận vuông trải phẳng bằng khử Gauss-Jordan có chọn trụ.
  /// Suy biến thì trả null — `A` luôn có `λ·I` nên không xảy ra, nhưng bản
  /// đọc từ sổ thì có thể là bất cứ thứ gì.
  static List<double>? nghichDao(List<double> m, int d) {
    final a = [...m];
    final r = _donVi(d);
    for (var c = 0; c < d; c++) {
      var tru = c;
      for (var i = c + 1; i < d; i++) {
        if (a[i * d + c].abs() > a[tru * d + c].abs()) tru = i;
      }
      if (a[tru * d + c].abs() < 1e-12) return null;
      if (tru != c) {
        for (var j = 0; j < d; j++) {
          final t = a[c * d + j];
          a[c * d + j] = a[tru * d + j];
          a[tru * d + j] = t;
          final u = r[c * d + j];
          r[c * d + j] = r[tru * d + j];
          r[tru * d + j] = u;
        }
      }
      final p = a[c * d + c];
      for (var j = 0; j < d; j++) {
        a[c * d + j] /= p;
        r[c * d + j] /= p;
      }
      for (var i = 0; i < d; i++) {
        if (i == c) continue;
        final he = a[i * d + c];
        if (he == 0) continue;
        for (var j = 0; j < d; j++) {
          a[i * d + j] -= he * a[c * d + j];
          r[i * d + j] -= he * r[c * d + j];
        }
      }
    }
    return r;
  }

  List<double> _nghichDao(int tay) =>
      _nd[tay] ??= nghichDao(_a[tay], soChieu) ?? _donVi(soChieu);

  /// Điểm UCB của một tay trong ngữ cảnh [x].
  double diem(int tay, List<double> x) {
    final nd = _nghichDao(tay);
    final ax = _nhan(nd, x);
    final theta = _nhan(nd, _b[tay]);
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

  /// Một lượt học trong ngữ cảnh [x]: thời gian trôi một nhịp (mọi tay quên
  /// bớt theo [gamma]) rồi ghi nhận [thuong] cho những tay đã chơi.
  ///
  /// Quên là việc của cả lượt chứ không của riêng tay được chọn: tay không
  /// được chơi mà vẫn giữ nguyên trọng số cũ thì nó mới là tay không bao giờ
  /// quên, và thói quen cũ lại đè được thói quen mới.
  void hoc(List<double> x, Map<int, double> thuong) {
    for (var tay = 0; tay < soTay; tay++) {
      final m = _a[tay];
      for (var i = 0; i < soChieu; i++) {
        for (var j = 0; j < soChieu; j++) {
          m[i * soChieu + j] =
              gamma * m[i * soChieu + j] +
              (i == j ? (1 - gamma) * _lamBda : 0.0);
        }
        _b[tay][i] *= gamma;
      }
      _nd[tay] = null;
    }
    for (final e in thuong.entries) {
      final m = _a[e.key];
      for (var i = 0; i < soChieu; i++) {
        for (var j = 0; j < soChieu; j++) {
          m[i * soChieu + j] += x[i] * x[j];
        }
        _b[e.key][i] += e.value * x[i];
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'chieu': soChieu,
    'alpha': alpha,
    'gamma': gamma,
    'a': _a,
    'b': _b,
  };

  /// Đọc lại mô hình đã lưu. Số tay hay số chiều đổi (app nâng cấp, thêm
  /// khung giờ) thì bản cũ không dùng được nữa — trả null để nơi gọi dựng
  /// mô hình mới, đừng cố ghép vào rồi lệch chỉ số.
  ///
  /// Bản cũ lưu thẳng `A⁻¹` (`ainv`): nghịch đảo lại thành `A` chứ đừng vứt,
  /// người dùng đã dạy nó cả học kỳ rồi.
  static LinUCB? fromJson(
    Map<String, dynamic> j, {
    required int soTay,
    required int soChieu,
    Random? ngau,
  }) {
    List<List<double>>? doc(Object? v) => (v as List?)
        ?.map((r) => [for (final x in r as List) (x as num).toDouble()])
        .toList();
    var a = doc(j['a']);
    if (a == null) {
      final cu = doc(j['ainv']);
      if (cu != null && cu.every((r) => r.length == soChieu * soChieu)) {
        a = [
          for (final r in cu) nghichDao(r, soChieu) ?? _donVi(soChieu, _lamBda),
        ];
      }
    }
    final b = doc(j['b']);
    if (a == null || b == null) return null;
    if (a.length != soTay || b.length != soTay) return null;
    if (a.any((r) => r.length != soChieu * soChieu)) return null;
    if (b.any((r) => r.length != soChieu)) return null;
    return LinUCB._(
      a,
      b,
      soChieu,
      (j['alpha'] as num?)?.toDouble() ?? alphaMacDinh,
      (j['gamma'] as num?)?.toDouble() ?? gammaMacDinh,
      ngau ?? Random(),
    );
  }
}
