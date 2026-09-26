import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

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

  /// Throws [PortalError] when the portal rejects the login.
  static Session fromJson(Map<String, dynamic> j) {
    if (j['IsLogin'] != true || j['Token'] == null) {
      final msg = (j['Message'] as String?)?.trim();
      throw PortalError(
        msg == null || msg.isEmpty ? 'Sai tài khoản hoặc mật khẩu' : msg,
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
  PortalError(this.message);
  final String message;
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
    });
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

  Future<Map<String, dynamic>> _get(String path, String token) => _send(
    () => _client.get(
      Uri.parse('$_base$path'),
      headers: {..._keys, 'authorization': 'Bearer $token'},
    ),
  );

  Future<Map<String, dynamic>> _post(String path, Object body) => _send(
    () => _client.post(
      Uri.parse('$_base$path'),
      headers: {..._keys, 'content-type': 'application/json'},
      body: jsonEncode(body),
    ),
  );

  Future<List<dynamic>> _getList(String path, String token) async =>
      (await _raw(
        () => _client.get(
          Uri.parse('$_base$path'),
          headers: {..._keys, 'authorization': 'Bearer $token'},
        ),
      )) as List;

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async => (await _raw(request)) as Map<String, dynamic>;

  Future<dynamic> _raw(Future<http.Response> Function() request) async {
    final http.Response res;
    try {
      res = await request().timeout(const Duration(seconds: 20));
    } catch (e) {
      throw PortalError('Không kết nối được portal. Kiểm tra mạng.');
    }
    if (res.statusCode != 200) {
      throw PortalError('Portal trả về lỗi ${res.statusCode}');
    }
    return jsonDecode(utf8.decode(res.bodyBytes));
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
