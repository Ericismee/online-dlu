import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'cache.dart';
import 'luong.dart';
import 'nhat_ky.dart';

/// A logged-in student session. The portal's token lives ~2h, so it is kept in
/// memory only — on a cold start we log in again from the saved credentials.
class Session {
  Session({
    required this.id,
    required this.fullName,
    required this.token,
    required this.expire,
  });

  final String id;
  final String fullName;
  final String token;
  final DateTime expire;

  bool get valid => DateTime.now().isBefore(expire);

  Map<String, dynamic> toMap() => {
    'id': id,
    'fullName': fullName,
    'token': token,
    'expire': expire.toIso8601String(),
  };

  /// Phiên lưu trong cache, để mở app là vào thẳng dù chưa đăng nhập lại được.
  static Session fromMap(Map<String, dynamic> m) => Session(
    id: m['id'] as String? ?? '',
    fullName: m['fullName'] as String? ?? '',
    token: m['token'] as String? ?? '',
    expire: DateTime.parse(m['expire'] as String),
  );

  /// Throws [PortalError] when the portal rejects the login.
  static Session fromJson(Map<String, dynamic> j) {
    if (j['IsLogin'] != true || j['Token'] == null) {
      final msg = (j['Message'] as String?)?.trim();
      throw PortalError(
        msg == null || msg.isEmpty ? 'Sai tài khoản hoặc mật khẩu' : msg,
        saiMatKhau: true,
      );
    }
    return Session(
      id: j['Id'] as String? ?? '',
      fullName: j['FullName'] as String? ?? '',
      token: j['Token'] as String,
      expire:
          DateTime.tryParse(j['Expire'] as String? ?? '') ??
          DateTime.now().add(const Duration(hours: 2)),
    );
  }
}

class PortalError implements Exception {
  PortalError(this.message, {this.offline = false, this.saiMatKhau = false});
  final String message;

  /// Lỗi mạng / portal chết, không phải sai mật khẩu.
  final bool offline;

  /// Chính server từ chối tài khoản này. Chỉ lỗi loại này mới được xoá mật
  /// khẩu đã lưu và đá về màn đăng nhập — portal trả 403 lúc bảo trì hay máy
  /// mất mạng thì mật khẩu vẫn đúng, giữ nguyên mà dùng số cũ.
  final bool saiMatKhau;
  @override
  String toString() => message;
}

class Portal {
  Portal({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _base = 'https://portal-api.dlu.edu.vn';

  /// Public client keys taken from the portal's own web app (online.dlu.edu.vn).
  static const _keys = {
    'apikey': 'pscRBF0zT2Mqo6vMw69YMOH43IrB2RtXBS0EHit2kzvL2auxaFJBvw==',
    'clientid': 'vhu',
  };

  Future<Session> login(String username, String password) async {
    final res = await _post('/api/authenticate/authpsc', {
      'username': username,
      'password': password,
      'type': 0,
    }, dangNhap: true);
    return Session.fromJson(res);
  }

  /// `/api/student/info` returns `{sinhVien: {...}, IsUpdate: {...}}` —
  /// only the student map is interesting.
  Future<Map<String, dynamic>> studentInfo(String token) async {
    final res = await _get('/api/student/info', token);
    return (res['sinhVien'] as Map<String, dynamic>?) ??
        (throw PortalError('Portal không trả về thông tin sinh viên'));
  }

  /// Lịch học một tuần ISO. Mỗi phần tử có DayOfWeek (1 = thứ 2),
  /// NumberOfPeriods và StartDate (dd/MM/yyyy) của thứ 2 trong tuần.
  Future<List<dynamic>> weekSchedule(
    String token, {
    required String year,
    required String term,
    required int week,
  }) async {
    final r = await _get(
      '/api/student/DrawingSchedules_v2?namhoc=$year&hocky=$term&tuan=$week',
      token,
    );
    return (r['ResultDataSchedule'] as List?) ?? const [];
  }

  /// Hộp thư của sinh viên, mới nhất trước.
  Future<List<dynamic>> messages(String token) async =>
      (await _getList('/api/student/GetMessagesByReceiverID', token));

  /// Lịch thi của sinh viên, tất cả các kỳ.
  /// Mã chương trình đào tạo, cần cho API điểm.
  Future<String> studyProgram(String token) async {
    final r = await _getList('/api/student/GetStudyProgram', token);
    return r.isEmpty
        ? throw PortalError('Không lấy được chương trình đào tạo')
        : r.first['StudyProgramID'] as String;
  }

  /// Các học phần trong chương trình đào tạo.
  Future<List<dynamic>> curriculum(String token, String program) async =>
      (await _get(
            '/api/student/studyProgram?StudyProgramID=$program',
            token,
          ))['tbStudyPrograms']
          as List;

  /// Bảng điểm, nhóm theo năm học rồi học kỳ.
  Future<List<dynamic>> marks(String token, String program) =>
      _getList('/api/student/marks?ctdt=$program&&loai=SV', token);

  /// Điểm rèn luyện tất cả các kỳ.
  Future<List<dynamic>> behaviorScores(String token) =>
      _getList('/api/student/behaviorscoretotal', token);

  /// Phiếu chấm rèn luyện của một kỳ: từng tiêu chí và điểm chốt.
  Future<Map<String, dynamic>> behaviorDetail(
    String token, {
    required String year,
    required String term,
  }) => _get('/api/student/BehaviorByStudent?namhoc=$year&hocky=$term', token);

  /// Kết quả đăng ký học phần của một học kỳ.
  Future<List<dynamic>> registrations(
    String token, {
    required String year,
    required String term,
  }) => _getList(
    '/api/student/XemKetQuaDangKyHP?namhoc=$year&hocky=$term',
    token,
  );

  Future<List<dynamic>> exams(String token) =>
      _getList('/api/student/showexambytime', token);

  Future<Map<String, dynamic>> _get(String path, String token) async =>
      (await _cached(path, token)) as Map<String, dynamic>;

  Future<List<dynamic>> _getList(String path, String token) async =>
      (await _cached(path, token)) as List;

  /// Cache trước, mạng sau: có cache thì trả luôn cho nhẹ, cache cũ quá thì
  /// gọi portal ngầm để lần mở sau đã mới.
  /// ponytail: màn hình đang mở không tự cập nhật, kéo xuống để làm mới.
  Future<dynamic> _cached(String path, String token) async {
    final saved = Cache.read(path);
    final hit = (Cache.bypass || Cache.forced) ? null : saved;
    // Cache ghi trước lượt kéo làm mới gần nhất thì không dùng nữa: người
    // dùng đã bảo lấy số mới, màn này mở sau cũng phải là số mới.
    if (hit != null && !Cache.invalidated(hit.$2)) {
      if (Cache.stale(hit.$2)) unawaited(_fetch(path, token));
      // Màn đang xem số của lúc cache ghi, không phải của bây giờ.
      Cache.served[path] = hit.$2;
      return hit.$1;
    }
    try {
      final data = await _fetch(path, token);
      // Lấy lại đúng mốc vừa ghi vào cache cho khỏi lệch vài mili giây.
      Cache.served[path] = Cache.read(path)?.$2 ?? DateTime.now();
      return data;
    } on PortalError {
      // Mất mạng mà trong máy còn số cũ thì đưa số cũ, hơn là màn báo lỗi —
      // kể cả trong lượt làm mới, vì portal lỗi một lần không có nghĩa là
      // phải xoá sạch những gì người dùng đang xem.
      if (saved == null) rethrow;
      Cache.served[path] = saved.$2;
      return saved.$1;
    }
  }

  Future<dynamic> _fetch(String path, String token) async {
    final data = await _raw(
      () => _client.get(
        Uri.parse('$_base$path'),
        headers: {..._keys, 'authorization': 'Bearer $token'},
      ),
      nhan: 'GET $path',
    );
    // Danh sách thì vào sổ mục trước: mục mới thêm dòng, mục portal không còn
    // trả về thì ẩn dòng. Cache cục JSON vẫn giữ để khung hình đầu có số ngay,
    // nhưng ghi bản đã qua sổ để hai nơi không nói khác nhau.
    final luu = data is List ? await DsKho.nhap(path, data) : data;
    await Cache.write(path, luu);
    return luu;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Object body, {
    bool dangNhap = false,
  }) => _send(
    () => _client.post(
      Uri.parse('$_base$path'),
      headers: {..._keys, 'content-type': 'application/json'},
      body: jsonEncode(body),
    ),
    nhan: 'POST $path',
    dangNhap: dangNhap,
  );

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request, {
    String? nhan,
    bool dangNhap = false,
  }) async =>
      (await _raw(request, nhan: nhan, dangNhap: dangNhap))
          as Map<String, dynamic>;

  /// [nhan] chỉ có phương thức và path — thân request mang mật khẩu, query
  /// mang token, nên hai thứ đó không bao giờ vào sổ.
  Future<dynamic> _raw(
    Future<http.Response> Function() request, {
    String? nhan,
    bool dangNhap = false,
  }) async {
    final http.Response res;
    final batDau = DateTime.now();
    if (nhan != null) NhatKy.ghi('portal', '→ $nhan');
    try {
      res = await request().timeout(const Duration(seconds: 20));
    } catch (e) {
      if (nhan != null) NhatKy.ghi('portal', '✗ $nhan: mất kết nối');
      throw PortalError(
        'Không kết nối được portal. Kiểm tra mạng.',
        offline: true,
      );
    }
    if (nhan != null) {
      final ms = DateTime.now().difference(batDau).inMilliseconds;
      NhatKy.ghi(
        'portal',
        '← $nhan ${res.statusCode} (${ms}ms, ${res.bodyBytes.length} B)',
      );
    }
    // Sai mật khẩu thì portal trả 400 kèm lời nhắn, chứ không phải 200 với
    // `IsLogin: false`. Đưa nguyên mã số ra màn đăng nhập thì người dùng chỉ
    // thấy "Portal trả về lỗi 400" và không biết phải sửa gì.
    //
    // Chỉ coi là sai mật khẩu khi portal tự nói ra bằng JSON của nó: 400 trơn
    // có thể là proxy chen vào hay mạng bắt đăng nhập wifi, mà cờ này thì
    // xoá mật khẩu đã lưu và đá về màn đăng nhập.
    if (dangNhap && (res.statusCode == 400 || res.statusCode == 401)) {
      final msg = await _loiDangNhap(res.bodyBytes);
      throw PortalError(
        msg ?? 'Sai tài khoản hoặc mật khẩu',
        saiMatKhau: msg != null,
      );
    }
    if (res.statusCode != 200) {
      throw PortalError(
        'Portal trả về lỗi ${res.statusCode}',
        offline: res.statusCode >= 500,
      );
    }
    return giaiMa(res.bodyBytes);
  }

  /// Lời nhắn portal gửi kèm lúc từ chối đăng nhập, null là thân lỗi không
  /// phải JSON của portal.
  static Future<String?> _loiDangNhap(Uint8List than) async {
    try {
      final j = await giaiMa(than);
      final msg = j is Map ? (j['Message'] as String?)?.trim() : null;
      return msg == null || msg.isEmpty ? null : msg;
    } catch (_) {
      return null;
    }
  }
}

/// Credentials go to the Keychain / Keystore, never to SharedPreferences.
class Vault {
  static const _storage = FlutterSecureStorage();

  static Future<void> save(String username, String password) async {
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'password', value: password);
  }

  static Future<(String, String)?> read() async {
    final u = await _storage.read(key: 'username');
    final p = await _storage.read(key: 'password');
    return (u == null || p == null) ? null : (u, p);
  }

  static Future<void> clear() async {
    await _storage.delete(key: 'username');
    await _storage.delete(key: 'password');
  }
}
