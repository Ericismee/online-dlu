import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'portal.dart' show PortalError;

/// Một phiên Moodle đã đăng nhập: cookie kèm token CSRF gắn với nó.
typedef LmsSession = ({String cookie, String sesskey, int userId});

typedef LmsNotification = ({
  String subject,
  String sender,
  String date,
  String body,
  bool unread,
});

class LmsVault {
  static const _storage = FlutterSecureStorage();

  static Future<void> save(String username, String password) async {
    await _storage.write(key: 'lms_username', value: username);
    await _storage.write(key: 'lms_password', value: password);
  }

  static Future<(String, String)?> read() async {
    final username = await _storage.read(key: 'lms_username');
    final password = await _storage.read(key: 'lms_password');
    return username == null || password == null ? null : (username, password);
  }

  static Future<void> clear() async {
    await _storage.delete(key: 'lms_username');
    await _storage.delete(key: 'lms_password');
  }
}

/// Một việc trên lịch Moodle: bài tập, hạn nộp, mốc mở/đóng quiz...
typedef LmsEvent = ({
  String name,
  String course,
  DateTime start,
  String? url,
  int instance,
});

/// Moodle của trường (lms.dlu.edu.vn). Web service chính thức bị tắt
/// (`/login/token.php` trả `enablewsdescription`), nên chỉ còn đường đăng nhập
/// bằng form như trình duyệt:
///
/// 1. `GET /login/index.php` — lấy `logintoken` dùng một lần + MoodleSession vô danh.
/// 2. `POST /login/index.php` — không chạy theo redirect, vì Moodle đổi id phiên
///    khi đăng nhập được: cookie trên chính phản hồi này mới là cookie thật.
/// 3. `GET /my/` — `sesskey` nằm trong khối `M.cfg` của mọi trang đã đăng nhập,
///    không bao giờ là cookie hay header.
/// 4. `POST /lib/ajax/service.php?sesskey=…&info=…` — dữ liệu.
class Lms {
  Lms({http.Client? client, this._base = 'https://lms.dlu.edu.vn'})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String _base;

  /// Moodle tự nhận ra đăng nhập hỏng bằng mấy dấu này trong trang trả về.
  static const _loi = [
    'loginerror',
    'invalid login',
    'invalidlogin',
    'sai tên đăng nhập',
  ];

  Future<LmsSession> login(String username, String password) async {
    final url = Uri.parse('$_base/login/index.php');

    final form = await _send(http.Request('GET', url));
    var cookie =
        _cookie(form) ??
        (throw PortalError('LMS không cấp phiên đăng nhập', offline: true));
    final token = RegExp(r'name="logintoken"\s+value="([^"]*)"')
        .firstMatch(_text(form))
        ?.group(1);
    // Bản Moodle nào không in logintoken thì bỏ hẳn khoá đó, đừng gửi rỗng:
    // rỗng là token sai, còn thiếu là "trang này không dùng token".
    final fields = {'username': username, 'password': password, 'anchor': ''};
    if (token != null) fields['logintoken'] = token;

    final post = http.Request('POST', url)
      ..followRedirects = false
      ..headers['content-type'] = 'application/x-www-form-urlencoded'
      ..headers['cookie'] = cookie
      ..bodyFields = fields;
    final res = await _send(post);
    // Đăng nhập được thì Moodle sinh id phiên mới, cookie cũ thành vô dụng.
    cookie = _cookie(res) ?? cookie;

    if (res.statusCode >= 300 && res.statusCode < 400) {
      // Sai mật khẩu thì bị đẩy về đúng trang form trống; đăng nhập được thì
      // redirect có query (`?testsession=…`) hoặc sang trang khác.
      final to = res.headers['location'] ?? '';
      if (RegExp(r'/login/index\.php/?$').hasMatch(to)) throw _sai();
    } else {
      final body = _text(res).toLowerCase();
      // Trang 200 lạ không coi là hỏng — bước lấy sesskey dưới đây mới là
      // phép thử thật, không phải đoán theo câu chữ.
      if (_loi.any(body.contains)) throw _sai();
    }

    final me = await _send(
      http.Request('GET', Uri.parse('$_base/my/'))..headers['cookie'] = cookie,
    );
    final config = RegExp(r'M\.cfg\s*=\s*(\{[^;]+\})')
        .firstMatch(_text(me))
        ?.group(1);
    if (config == null) throw _sai();
    final cfg = jsonDecode(config) as Map<String, dynamic>;
    final sesskey = cfg['sesskey'] as String?;
    final userId = (cfg['userid'] as num?)?.toInt();
    if (sesskey == null || userId == null) throw _sai();
    return (cookie: cookie, sesskey: sesskey, userId: userId);
  }

  /// Lịch một tháng ([month] đếm từ 1). `courseid: 1` là khoá học gốc của site,
  /// nghĩa là "mọi thứ sinh viên này thấy được", không phải một môn.
  Future<List<LmsEvent>> calendar(LmsSession s, int year, int month) async {
    final data = await _ajax(
      s: s,
      method: 'core_calendar_get_calendar_monthly_view',
      args: {
        'year': year,
        'month': month,
        'courseid': 1,
        'includenavigation': false,
        'mini': true,
        'day': 1,
      },
    ) as Map<String, dynamic>;
    return [
      for (final w in (data['weeks'] as List? ?? const []))
        for (final d in (w['days'] as List? ?? const []))
          for (final e in (d['events'] as List? ?? const []))
            (
              name: e['name'] as String? ?? '',
              course: (e['course']?['fullname'] as String?) ?? '',
              // `timestart` là giây Unix thật, đừng đổi múi giờ lần nữa.
              start: DateTime.fromMillisecondsSinceEpoch(
                (e['timestart'] as num).toInt() * 1000,
              ),
              url: e['url'] as String?,
              instance: (e['instance'] as num?)?.toInt() ?? 0,
            ),
    ];
  }

  Future<List<LmsNotification>> notifications(LmsSession session) async {
    final data = await _ajax(
      s: session,
      method: 'core_message_get_messages',
      args: {
        'useridto': session.userId,
        'useridfrom': 0,
        'type': 'notifications',
        'read': 0,
        'newestfirst': true,
        'limitfrom': 0,
        'limitnum': 30,
      },
    );
    final items = data is List
        ? data
        : (data as Map<String, dynamic>)['messages'] as List? ?? const [];
    return [
      for (final item in items)
        (
          subject: item['subject'] as String? ?? '',
          sender:
              item['userfrom']?['fullname'] as String? ??
              item['component'] as String? ??
              'Moodle',
          date: DateTime.fromMillisecondsSinceEpoch(
            ((item['timecreated'] as num?)?.toInt() ?? 0) * 1000,
          ).toLocal().toString().substring(0, 16),
          body:
              item['smallmessage'] as String? ??
              item['fullmessage'] as String? ??
              '',
          unread: item['read'] == false || item['read'] == 0,
        ),
    ];
  }

  Future<dynamic> _ajax({
    required LmsSession s,
    required String method,
    required Map<String, dynamic> args,
  }) async {
    final res = await _send(
      http.Request(
          'POST',
          Uri.parse(
            '$_base/lib/ajax/service.php'
            '?sesskey=${Uri.encodeQueryComponent(s.sesskey)}&info=$method',
          ),
        )
        ..headers['content-type'] = 'application/json'
        ..headers['cookie'] = s.cookie
        ..body = jsonEncode([
          {'index': 0, 'methodname': method, 'args': args},
        ]),
    );
    if (res.statusCode != 200) {
      throw PortalError(
        'LMS trả về lỗi ${res.statusCode}',
        offline: res.statusCode >= 500,
      );
    }
    // Endpoint này luôn trả 200, lỗi nằm trong `error`/`exception`.
    final goi = (jsonDecode(_text(res)) as List?)?.firstOrNull;
    if (goi == null) throw PortalError('LMS trả về rỗng', offline: true);
    // `error` luôn có mặt, bình thường là `false` — chỉ `true` mới là lỗi.
    if (goi['error'] == true || goi['exception'] != null) {
      // Hết phiên cũng rơi vào đây, nên coi như phải đăng nhập lại.
      throw PortalError('Phiên LMS hết hạn, đăng nhập lại');
    }
    return goi['data'] ?? const {};
  }

  PortalError _sai() => PortalError('Sai tài khoản hoặc mật khẩu LMS');

  /// Moodle trả utf-8; `res.body` lại đoán latin1 khi header thiếu charset,
  /// làm chữ Việt (và cả dấu hiệu lỗi đăng nhập) sai hết.
  String _text(http.Response res) =>
      utf8.decode(res.bodyBytes, allowMalformed: true);

  /// `MoodleSession=<id>` nếu phản hồi có đặt cookie. http gộp mọi
  /// `Set-Cookie` vào một dòng nên cứ tìm thẳng trên cả dòng.
  String? _cookie(http.Response res) =>
      RegExp(r'(MoodleSession[^=;,\s]*)=([^;,\s]+)')
          .firstMatch(res.headers['set-cookie'] ?? '')
          ?.group(0);

  Future<http.Response> _send(http.Request req) async {
    try {
      return await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 20)),
      );
    } on PortalError {
      rethrow;
    } catch (_) {
      // Không log url/body: POST đăng nhập mang theo mật khẩu.
      throw PortalError(
        'Không kết nối được LMS. Kiểm tra mạng.',
        offline: true,
      );
    }
  }
}
