import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpClient, SecurityContext;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' show IOClient;

import 'cache.dart';
import 'data.dart' show clean;
import 'db.dart';
import 'nhat_ky.dart';
import 'luong.dart';
import 'portal.dart' show PortalError;
import 'settings.dart' show Settings;

/// Một phiên Moodle đã đăng nhập: cookie kèm token CSRF gắn với nó.
typedef LmsSession = ({String cookie, String sesskey, int userId});

typedef LmsAttendanceStatus = ({String id, String label});
typedef LmsAttendanceForm = ({Uri action, List<LmsAttendanceStatus> statuses});

typedef LmsNotification = ({
  /// Id Moodle, dùng làm khoá trong SQLite nên phải là của server, không
  /// được tự sinh: cùng một thông báo lấy lại lần sau phải trùng khoá cũ.
  String id,
  String subject,
  String sender,
  String date,
  String body,
  bool unread,
});

class LmsVault {
  static const _storage = FlutterSecureStorage();

  static Future<void> save(String username, String password) async {
    // Đổi tài khoản thì phiên cũ hết dùng được, y như lúc xoá: không bỏ đi là
    // lượt làm mới ngay sau đó vẫn đọc thông báo của chủ cũ.
    Lms.boPhien();
    await _storage.write(key: 'lms_username', value: username);
    await _storage.write(key: 'lms_password', value: password);
  }

  static Future<(String, String)?> read() async {
    final username = await _storage.read(key: 'lms_username');
    final password = await _storage.read(key: 'lms_password');
    return username == null || password == null ? null : (username, password);
  }

  static Future<void> clear() async {
    Lms.boPhien();
    await _storage.delete(key: 'lms_username');
    await _storage.delete(key: 'lms_password');
    await xoaPhien();
  }

  /// Phiên Moodle nằm trong Keychain chứ không phải SQLite: cookie phiên mở
  /// được tài khoản y như mật khẩu, mà sổ SQLite thì nằm trần trong thư mục
  /// dữ liệu của app.
  static Future<void> luuPhien(LmsSession s) async {
    await _storage.write(key: 'lms_cookie', value: s.cookie);
    await _storage.write(key: 'lms_sesskey', value: s.sesskey);
    await _storage.write(key: 'lms_userid', value: '${s.userId}');
  }

  static Future<LmsSession?> docPhien() async {
    final cookie = await _storage.read(key: 'lms_cookie');
    final sesskey = await _storage.read(key: 'lms_sesskey');
    final uid = int.tryParse(await _storage.read(key: 'lms_userid') ?? '');
    return cookie == null || sesskey == null || uid == null
        ? null
        : (cookie: cookie, sesskey: sesskey, userId: uid);
  }

  static Future<void> xoaPhien() async {
    await _storage.delete(key: 'lms_cookie');
    await _storage.delete(key: 'lms_sesskey');
    await _storage.delete(key: 'lms_userid');
  }
}

/// Nhịp làm mới LMS dùng chung: app đang mở thì cứ 90–120 giây gọi lại mọi
/// nơi đang nghe. Lệch ngẫu nhiên để nhiều máy không gõ cửa Moodle cùng nhịp.
///
/// Một nhịp cho cả app, không phải mỗi màn một Timer: chuông với thẻ điểm
/// danh mà tự hẹn riêng thì server trường ăn hai lượt lệch nhau, còn mình thì
/// phải sửa cùng một đoạn hẹn giờ ở hai chỗ.
class LmsNhip {
  static final _nghe = <Future<void> Function()>[];
  static final _ngau = Random();
  static Timer? _hen;

  /// Khoảng giữa hai lượt. Test đổi xuống vài ms cho khỏi ngồi chờ.
  @visibleForTesting
  static Duration Function() khoang = () =>
      Duration(seconds: 90 + _ngau.nextInt(31));

  static void them(Future<void> Function() viec) {
    _nghe.add(viec);
    if (_hen == null) _lap();
  }

  static void bo(Future<void> Function() viec) {
    _nghe.remove(viec);
    // Không còn ai nghe thì tắt hẳn, đừng để Timer chạy không.
    if (_nghe.isEmpty) {
      _hen?.cancel();
      _hen = null;
    }
  }

  /// Tắt nhịp mà giữ danh sách người nghe — app xuống nền thì ngừng gõ cửa
  /// Moodle, lên lại thì [chay] tiếp, không ai phải đăng ký lại.
  static void dung() {
    _hen?.cancel();
    _hen = null;
  }

  static void chay() {
    if (_hen == null && _nghe.isNotEmpty) _lap();
  }

  /// Một lượt ngay, không chờ hết nhịp: vừa đăng nhập LMS xong mà chuông với
  /// thẻ điểm danh đang mở thì chúng đã nạp lượt đầu lúc chưa có tài khoản,
  /// không gọi lại là người dùng ngồi nhìn chỗ trống tới hai phút.
  ///
  /// Gọi lần lượt chứ không song song: cùng một server trường, mà lượt này
  /// chưa về đã bắn lượt sau thì chỉ làm nó nặng thêm.
  static Future<void> ngay() async {
    for (final viec in [..._nghe]) {
      try {
        await viec();
      } catch (_) {
        // Một nơi hỏng không được làm đứng cả nhịp.
      }
    }
  }

  /// Mốc của lượt kế, để sổ verbose đếm ngược được còn bao lâu.
  static DateTime? ke;

  static void _lap() {
    final cho = khoang();
    ke = DateTime.now().add(cho);
    _hen = Timer(cho, () async {
      NhatKy.ghi('nhip', 'lms: ${_nghe.length} nơi nghe, bắt đầu lượt');
      await ngay();
      NhatKy.ghi('nhip', 'lms: xong lượt');
      if (_nghe.isEmpty) {
        _hen = null;
        ke = null;
      } else {
        _lap();
      }
    });
  }
}

/// Thông báo LMS cất trong SQLite: Moodle chỉ trả về 30 cái mới nhất và chỉ
/// loại chưa đọc, nên không giữ lại thì cái nào trôi khỏi danh sách đó là mất.
/// Mỗi dòng một thông báo, nội dung là JSON kèm cờ [_daXem]; "đã xem" chỉ đổi
/// cờ, không xoá dòng nào.
class LmsKho {
  static const _daXem = 'da_xem';

  /// Mọi thông báo đã từng lấy về, mới nhất lên trước. [KhoData.luc] là lúc
  /// ghi nên không dùng để sắp — sắp theo ngày của chính thông báo.
  /// [caDaXoa] lấy cả dòng đã vuốt xoá — hộp thư cần chúng để bày lại trong
  /// mục "Thông báo cũ"; chỗ nào chỉ đếm tin mới thì để nguyên mặc định.
  static Future<List<LmsNotification>> doc({bool caDaXoa = false}) async {
    final dong = caDaXoa
        ? await Db.i.nhomCa(nhomThongBao)
        : await Db.i.nhomDang(nhomThongBao);
    // Nhịp LMS gọi hàm này 90 giây một lượt và hộp thư chỉ dài ra theo thời
    // gian, nên cả đống đi một lượt sang isolate khác mà giải mã.
    final m = await giaiMaNhieu([for (final d in dong) d.giaTri]);
    final out = [
      for (var i = 0; i < dong.length; i++)
        _tu(dong[i].khoa, m[i] as Map<String, dynamic>),
    ]..sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  /// Nhập mẻ vừa lấy về: khác dòng đang có thì ghi, giống thì bỏ qua. Cứ 90
  /// giây Moodle lại trả về gần như y hệt mẻ trước, ghi lại cả 30 dòng mỗi
  /// lượt là chép đè vô ích — mà [KhoData.luc] còn bị dí thành giờ hiện tại,
  /// mất luôn dấu "thông báo này về từ lúc nào".
  ///
  /// Thông báo đã có thì giữ nguyên cờ đã xem: server không biết mình đã xem
  /// trong app, ghi đè là nó chưa đọc lại lần nữa.
  /// Thông báo người dùng đã vuốt xoá thì không nhận lại: Moodle vẫn trả nó
  /// về mỗi nhịp vì server không biết mình đã bỏ.
  static Future<void> luu(Iterable<LmsNotification> moi) async {
    final dong = await Db.i.nhomCa(nhomThongBao);
    final cu = {for (final d in dong) d.khoa: d.giaTri};
    final daXoa = {
      for (final d in dong)
        if (!d.bat) d.khoa,
    };
    for (final n in moi) {
      if (n.id.isEmpty || daXoa.contains(n.id)) continue;
      // Cùng một hàm dựng JSON nên so chuỗi là đủ, khỏi so từng khoá.
      final json = jsonEncode({
        'subject': n.subject,
        'sender': n.sender,
        'date': n.date,
        'body': n.body,
        _daXem: cu[n.id] != null && _daXemTrong(cu[n.id]!),
      });
      if (cu[n.id] == json) continue;
      await Db.i.ghi(nhomThongBao, n.id, giaTri: json);
    }
  }

  /// Khoá cố định cho tin "mật khẩu LMS sai": sai bao nhiêu lượt cũng chỉ một
  /// dòng, không dồn thành một chồng thông báo giống nhau.
  static const khoaSaiMatKhau = 'lms-sai-mat-khau';

  /// Mật khẩu LMS hỏng là tin của chính app, không phải của Moodle — nhưng
  /// chỗ người dùng sẽ nhìn là chuông, nên cất cùng một kho.
  static Future<void> baoSaiMatKhau(String taiKhoan) => Db.i.ghi(
    nhomThongBao,
    khoaSaiMatKhau,
    giaTri: jsonEncode({
      'subject': 'Mật khẩu LMS không còn đúng',
      'sender': 'Online DLU',
      'date': DateTime.now().toIso8601String(),
      'body':
          'LMS đã tạm tắt vì Moodle từ chối tài khoản $taiKhoan. '
          'Vào Cài đặt → Tài khoản LMS để đăng nhập lại; '
          'thông báo và buổi điểm danh sẽ chạy tiếp ngay sau đó.',
      _daXem: false,
    }),
  );

  /// Vuốt xoá một thông báo: ẩn dòng đi, chữ vẫn nằm trong máy. Đánh dấu đã
  /// xem luôn — xoá rồi mà huy hiệu trên chuông vẫn đếm nó thì vô lý.
  static Future<void> xoa(String id) async {
    await danhDauDaXem(id);
    await Db.i.an(nhomThongBao, id);
  }

  /// Đăng nhập LMS lại được thì cất tin cảnh báo đi — ẩn chứ không xoá.
  static Future<void> thoiBaoSaiMatKhau() =>
      Db.i.an(nhomThongBao, khoaSaiMatKhau);

  static bool _daXemTrong(String giaTri) =>
      (jsonDecode(giaTri) as Map<String, dynamic>)[_daXem] == true;

  /// Đánh dấu đã xem một thông báo, hay tất cả khi [id] để trống.
  static Future<void> danhDauDaXem([String? id]) async {
    for (final d in await Db.i.nhomDang(nhomThongBao)) {
      if (id != null && d.khoa != id) continue;
      final m = jsonDecode(d.giaTri) as Map<String, dynamic>;
      if (m[_daXem] == true) continue;
      m[_daXem] = true;
      await Db.i.ghi(nhomThongBao, d.khoa, giaTri: jsonEncode(m));
    }
  }

  static LmsNotification _tu(String id, Map<String, dynamic> m) {
    return (
      id: id,
      subject: m['subject'] as String? ?? '',
      sender: m['sender'] as String? ?? '',
      date: m['date'] as String? ?? '',
      body: m['body'] as String? ?? '',
      unread: m[_daXem] != true,
    );
  }
}

/// Một việc trên lịch Moodle: bài tập, hạn nộp, mốc mở/đóng quiz, điểm danh...
typedef LmsEvent = ({
  String name,
  String course,
  DateTime start,

  /// Cửa sổ mở của việc này; 0 với loại chỉ có một mốc (hạn nộp bài). Buổi
  /// điểm danh thì đây là khoảng được phép điểm — thường chỉ 5 phút.
  Duration keoDai,

  /// `modulename` của Moodle: 'attendance', 'assign', 'quiz'... Dùng để nhận
  /// ra loại việc chắc chắn hơn là đoán theo tên.
  String loai,
  String? url,
  int instance,

  /// Moodle gắn một "action" vào việc còn phải làm (nộp bài, điểm danh). Nộp
  /// xong là nó hết actionable hoặc còn 0 mục — tức việc đã xong, đừng nhắc
  /// nữa. Việc không có action (mốc đóng quiz, lịch khoá học) thì luôn false.
  bool xong,
});

/// Mốc kết thúc cửa sổ của một việc.
DateTime ketThuc(LmsEvent e) => e.start.add(e.keoDai);

/// lms.dlu.edu.vn chỉ gửi chứng chỉ lá, thiếu chứng chỉ trung gian của Sectigo
/// (portal-api thì gửi đủ). macOS/iOS tự tải khúc thiếu về theo AIA nên vẫn vào
/// được, còn BoringSSL mà Dart dùng trên Android thì không — bắt tay TLS hỏng
/// và app chỉ báo được "Không kết nối được LMS". Mang sẵn chứng chỉ trung gian
/// theo app để nối đủ chuỗi, vẫn giữ nguyên kho gốc và vẫn kiểm chứng chỉ đàng
/// hoàng — không bao giờ badCertificateCallback.
// ponytail: chứng chỉ hết hạn 31/12/2030, hoặc sớm hơn nếu trường cấu hình lại
// server cho gửi đủ chuỗi; lúc đó xoá cả khối này đi là xong.
final _tinCay = SecurityContext(withTrustedRoots: true)
  ..setTrustedCertificatesBytes(ascii.encode(_sectigo));

/// Sectigo RSA Organization Validation Secure Server CA — lấy từ chính đường
/// `CA Issuers` ghi trong chứng chỉ lá của lms.dlu.edu.vn.
const _sectigo = '''
-----BEGIN CERTIFICATE-----
MIIGGTCCBAGgAwIBAgIQE31TnKp8MamkM3AZaIR6jTANBgkqhkiG9w0BAQwFADCB
iDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0pl
cnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNV
BAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTgx
MTAyMDAwMDAwWhcNMzAxMjMxMjM1OTU5WjCBlTELMAkGA1UEBhMCR0IxGzAZBgNV
BAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UE
ChMPU2VjdGlnbyBMaW1pdGVkMT0wOwYDVQQDEzRTZWN0aWdvIFJTQSBPcmdhbml6
YXRpb24gVmFsaWRhdGlvbiBTZWN1cmUgU2VydmVyIENBMIIBIjANBgkqhkiG9w0B
AQEFAAOCAQ8AMIIBCgKCAQEAnJMCRkVKUkiS/FeN+S3qU76zLNXYqKXsW2kDwB0Q
9lkz3v4HSKjojHpnSvH1jcM3ZtAykffEnQRgxLVK4oOLp64m1F06XvjRFnG7ir1x
on3IzqJgJLBSoDpFUd54k2xiYPHkVpy3O/c8Vdjf1XoxfDV/ElFw4Sy+BKzL+k/h
fGVqwECn2XylY4QZ4ffK76q06Fha2ZnjJt+OErK43DOyNtoUHZZYQkBuCyKFHFEi
rsTIBkVtkuZntxkj5Ng2a4XQf8dS48+wdQHgibSov4o2TqPgbOuEQc6lL0giE5dQ
YkUeCaXMn2xXcEAG2yDoG9bzk4unMp63RBUJ16/9fAEc2wIDAQABo4IBbjCCAWow
HwYDVR0jBBgwFoAUU3m/WqorSs9UgOHYm8Cd8rIDZsswHQYDVR0OBBYEFBfZ1iUn
Z/kxwklD2TA2RIxsqU/rMA4GA1UdDwEB/wQEAwIBhjASBgNVHRMBAf8ECDAGAQH/
AgEAMB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjAbBgNVHSAEFDASMAYG
BFUdIAAwCAYGZ4EMAQICMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNl
cnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNy
bDB2BggrBgEFBQcBAQRqMGgwPwYIKwYBBQUHMAKGM2h0dHA6Ly9jcnQudXNlcnRy
dXN0LmNvbS9VU0VSVHJ1c3RSU0FBZGRUcnVzdENBLmNydDAlBggrBgEFBQcwAYYZ
aHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAThNA
lsnD5m5bwOO69Bfhrgkfyb/LDCUW8nNTs3Yat6tIBtbNAHwgRUNFbBZaGxNh10m6
pAKkrOjOzi3JKnSj3N6uq9BoNviRrzwB93fVC8+Xq+uH5xWo+jBaYXEgscBDxLmP
bYox6xU2JPti1Qucj+lmveZhUZeTth2HvbC1bP6mESkGYTQxMD0gJ3NR0N6Fg9N3
OSBGltqnxloWJ4Wyz04PToxcvr44APhL+XJ71PJ616IphdAEutNCLFGIUi7RPSRn
R+xVzBv0yjTqJsHe3cQhifa6ezIejpZehEU4z4CqN2mLYBd0FUiRnG3wTqN3yhsc
SPr5z0noX0+FCuKPkBurcEya67emP7SsXaRfz+bYipaQ908mgWB2XQ8kd5GzKjGf
FlqyXYwcKapInI5v03hAcNt37N3j0VcFcC3mSZiIBYRiBXBWdoY5TtMibx3+bfEO
s2LEPMvAhblhHrrhFYBZlAyuBbuMf1a+HNJav5fyakywxnB2sJCNwQs2uRHY1ihc
6k/+JLcYCpsM0MF8XPtpvcyiTcaQvKZN8rG61ppnW5YCUtCC+cQKXA0o4D/I+pWV
idWkvklsQLI+qGu41SWyxP7x09fn1txDAXYw+zuLXfdKiXyaNb78yvBXAfCNP6CH
MntHWpdLgtJmwsQt6j8k9Kf5qLnjatkYYaA7jBU=
-----END CERTIFICATE-----
''';

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
    : _browserWithoutProxy = kIsWeb && client == null,
      _client =
          client ??
          (kIsWeb ? http.Client() : IOClient(HttpClient(context: _tinCay)));

  final http.Client _client;
  final bool _browserWithoutProxy;
  final String _base;

  /// Moodle tự nhận ra đăng nhập hỏng bằng mấy dấu này trong trang trả về.
  static const _loi = [
    'loginerror',
    'invalid login',
    'invalidlogin',
    'sai tên đăng nhập',
  ];

  /// Phiên dùng chung cho cả lượt chạy app. Moodle chỉ cấp phiên qua form
  /// đăng nhập, nên mỗi màn tự gọi [login] là mỗi lần gửi mật khẩu thêm một
  /// lượt; giữ lại một phiên cho mọi màn dùng chung.
  static Future<LmsSession>? _phien;

  /// Phiên đang dùng, hay null nếu người dùng chưa bật LMS / chưa lưu tài
  /// khoản. Đăng nhập hỏng thì bỏ luôn phiên hỏng để lượt sau thử lại sạch.
  static Future<LmsSession?> phien({Lms? lms}) async {
    if (!await Settings.lmsBat()) return null;
    final tk = await LmsVault.read();
    if (tk == null) return null;
    try {
      return await (_phien ??= _mo(lms ?? Lms(), tk));
    } on PortalError catch (e) {
      _phien = null;
      // Mật khẩu LMS không còn đúng thì tắt LMS ngay và báo vào chuông, chứ
      // không im lặng thử lại mỗi 90 giây — Moodle khoá IP sau vài chục lượt
      // sai, mà người dùng thì không biết tại sao chuông im. Tài khoản đã lưu
      // giữ nguyên để chỉ phải sửa mật khẩu, khỏi gõ lại từ đầu.
      if (e.saiMatKhau) {
        await Settings.datLmsBat(false);
        await LmsKho.baoSaiMatKhau(tk.$1);
      }
      rethrow;
    } catch (_) {
      _phien = null;
      rethrow;
    }
  }

  /// Phiên cũ còn sống thì dùng tiếp, chết mới đăng nhập lại. Mỗi lượt đăng
  /// nhập là một lần gửi mật khẩu đi, mà phiên Moodle sống được nhiều ngày.
  static Future<LmsSession> _mo(Lms l, (String, String) tk) async {
    final cu = await LmsVault.docPhien();
    if (cu != null && await l.conSong(cu)) return cu;
    final s = await l.login(tk.$1, tk.$2);
    await LmsVault.luuPhien(s);
    return s;
  }

  /// Phiên còn sống không. Trang `/my/` chỉ in đúng `sesskey` của phiên khi
  /// cookie còn hiệu lực; hết hạn thì Moodle đẩy về form đăng nhập.
  Future<bool> conSong(LmsSession s) async {
    try {
      final res = await _send(
        http.Request('GET', Uri.parse('$_base/my/'))
          ..headers['cookie'] = s.cookie,
      );
      return _text(res).contains('"sesskey":"${s.sesskey}"');
    } catch (_) {
      return false;
    }
  }

  /// Bỏ phiên đang giữ. Phiên đã chết thì bỏ khỏi Keychain luôn, không thì
  /// lượt mở app sau lại thử đúng cái phiên đó.
  static void boPhien() {
    boPhienTrongRam();
    unawaited(LmsVault.xoaPhien());
  }

  /// Chỉ quên phiên đang giữ trong RAM, phiên trong Keychain vẫn còn — y như
  /// lúc mở lại app.
  @visibleForTesting
  static void boPhienTrongRam() => _phien = null;

  Future<LmsSession> login(String username, String password) {
    if (_browserWithoutProxy) {
      throw PortalError(
        'LMS chưa cho phép đăng nhập từ trình duyệt. Hãy dùng app trên Android hoặc iOS để đăng nhập và điểm danh.',
      );
    }
    return _login(username, password).timeout(
      const Duration(seconds: 25),
      onTimeout: () => throw PortalError(
        'LMS phản hồi quá lâu. Kiểm tra kết nối rồi thử lại.',
        offline: true,
      ),
    );
  }

  Future<LmsSession> _login(String username, String password) async {
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
    final trang = _text(me);
    // sesskey luôn có trong M.cfg; `userid` thì tuỳ bản Moodle — lms.dlu
    // (theme lambda) không in nó ở đó, phải bắt trong phần JS của trang.
    final sesskey = RegExp(r'"sesskey":"([A-Za-z0-9]+)"')
        .firstMatch(trang)
        ?.group(1);
    final userId = int.tryParse(
      RegExp(
            r'userid["\s:=]+(\d+)',
            caseSensitive: false,
          ).firstMatch(trang)?.group(1) ??
          RegExp(r'/user/profile\.php\?id=(\d+)').firstMatch(trang)?.group(1) ??
          '',
    );
    if (sesskey == null || userId == null) throw _sai();
    final s = (cookie: cookie, sesskey: sesskey, userId: userId);
    await LmsVault.luuPhien(s);
    return s;
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
    final viec = [
      for (final w in (data['weeks'] as List? ?? const []))
        for (final d in (w['days'] as List? ?? const []))
          for (final e in (d['events'] as List? ?? const []))
            (
              name: e['name'] as String? ?? '',
              // Lịch tháng chỉ kèm `course` cho vài loại việc; buổi điểm danh
              // thì tên môn chỉ có trong `popupname` ("DPctk47: Điểm danh").
              course:
                  (e['course']?['fullname'] as String?) ??
                  _monTuPopup(e['popupname'] as String?),
              // `timestart` là giây Unix thật, đừng đổi múi giờ lần nữa.
              start: DateTime.fromMillisecondsSinceEpoch(
                (e['timestart'] as num).toInt() * 1000,
              ),
              keoDai: Duration(
                seconds: (e['timeduration'] as num?)?.toInt() ?? 0,
              ),
              loai: e['modulename'] as String? ?? '',
              url: e['url'] as String?,
              instance: (e['instance'] as num?)?.toInt() ?? 0,
              xong: _xong(e['action']),
            ),
    ];
    await luuLich(year, month, viec);
    if (NhatKy.bat) {
      NhatKy.ghi('lms', 'lịch $year-$month: ${viec.length} việc');
      for (final w in (data['weeks'] as List? ?? const [])) {
        for (final d in (w['days'] as List? ?? const [])) {
          for (final e in (d['events'] as List? ?? const [])) {
            NhatKy.ghi(
              'lms',
              '  ${e['name']} · ${e['modulename']} · ${_goiAction(e['action'])}',
            );
          }
        }
      }
    }
    return viec;
  }

  /// Gói `action` lại thành một dòng ngắn để soi trong sổ verbose: đây là thứ
  /// quyết định việc đã xong hay chưa, nên phải nhìn được bằng mắt.
  static String _goiAction(Object? action) => action is! Map
      ? 'không có action'
      : 'itemcount=${action['itemcount']} actionable=${action['actionable']}';

  /// Việc đã xong chưa, theo khối `action` của Moodle.
  static bool _xong(Object? action) {
    if (action is! Map) return false;
    final con = (action['itemcount'] as num?)?.toInt() ?? 1;
    return con <= 0 || (action['actionable'] as bool? ?? true) == false;
  }

  /// Tải đúng form của buổi điểm danh đang mở. Moodle không đưa `sessid` và
  /// các trạng thái vào API lịch, nên phải đi qua trang activity như browser.
  Future<LmsAttendanceForm> attendanceForm(
    LmsSession session,
    int instance,
  ) async {
    if (instance <= 0) throw PortalError('Buổi điểm danh không hợp lệ');
    final view = await _send(
      http.Request(
        'GET',
        Uri.parse('$_base/mod/attendance/view.php?id=$instance'),
      )..headers['cookie'] = session.cookie,
    );
    if (view.statusCode != 200) {
      throw PortalError('Không mở được buổi điểm danh');
    }
    final href = RegExp(
      r'''href\s*=\s*["']([^"']*/mod/attendance/attendance\.php\?[^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(_text(view))?.group(1);
    if (href == null) {
      throw PortalError('Buổi điểm danh chưa mở hoặc đã được ghi nhận');
    }
    final action = Uri.parse(_base).resolve(clean(href));
    final base = Uri.parse(_base);
    if (action.scheme != base.scheme || action.host != base.host) {
      throw PortalError('Đường dẫn điểm danh không hợp lệ');
    }

    final page = await _send(
      http.Request('GET', action)..headers['cookie'] = session.cookie,
    );
    if (page.statusCode != 200) {
      throw PortalError('Không tải được lựa chọn điểm danh');
    }
    final html = _text(page);
    final statuses = <LmsAttendanceStatus>[];
    for (final match in RegExp(
      r'''<input\b[^>]*\bname\s*=\s*["']status["'][^>]*>''',
      caseSensitive: false,
    ).allMatches(html)) {
      final input = match.group(0)!;
      final id = _attribute(input, 'id');
      final value = _attribute(input, 'value');
      if (id == null || value == null) continue;
      final label = RegExp(
        '''<label\\b[^>]*\\bfor\\s*=\\s*["']${RegExp.escape(id)}["'][^>]*>([\\s\\S]*?)</label>''',
        caseSensitive: false,
      ).firstMatch(html)?.group(1);
      if (label != null) statuses.add((id: value, label: clean(label)));
    }
    if (statuses.isEmpty) {
      throw PortalError('LMS không trả về trạng thái điểm danh');
    }
    return (action: action, statuses: statuses);
  }

  /// Gửi trạng thái người dùng vừa chọn. Chỉ redirect về trang activity mới
  /// được coi là thành công; trang 200 thường là form báo lỗi của Moodle.
  Future<void> submitAttendance(
    LmsSession session,
    LmsAttendanceForm form,
    String status,
  ) async {
    if (!form.statuses.any((item) => item.id == status)) {
      throw PortalError('Trạng thái điểm danh không hợp lệ');
    }
    final sessid = form.action.queryParameters['sessid'];
    if (sessid == null || sessid.isEmpty) {
      throw PortalError('Buổi điểm danh thiếu mã phiên');
    }
    final request = http.Request('POST', form.action.replace(query: null))
      ..followRedirects = false
      ..headers['content-type'] = 'application/x-www-form-urlencoded'
      ..headers['cookie'] = session.cookie
      ..bodyFields = {
        'sessid': sessid,
        'sesskey': session.sesskey,
        '_qf__mod_attendance_form_studentattendance': '1',
        'mform_isexpanded_id_session': '1',
        'status': status,
        'submitbutton': 'Lưu những thay đổi',
      };
    final response = await _send(request);
    final location = response.headers['location'];
    final destination = location == null
        ? null
        : Uri.parse(_base).resolve(location);
    if (response.statusCode != 303 ||
        destination?.path != '/mod/attendance/view.php') {
      if (destination?.path == '/login/index.php') boPhien();
      throw PortalError('LMS chưa ghi nhận điểm danh, vui lòng thử lại');
    }
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
          id: item['id']?.toString() ?? '',
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
          // Đã lọc `read: 0` nên mọi thứ trả về đều là chưa đọc; bản Moodle
          // của trường không in lại cờ `read` trong bản ghi, đừng đoán ngược.
          unread: item['read'] != true && item['read'] != 1,
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
      // Hết phiên cũng rơi vào đây, nên coi như phải đăng nhập lại. Bỏ phiên
      // đang giữ, không thì cả lượt chạy app cứ gọi lại bằng phiên đã chết.
      boPhien();
      throw PortalError('Phiên LMS hết hạn, đăng nhập lại');
    }
    return goi['data'] ?? const {};
  }

  /// "DPctk47: Điểm danh" → "DPctk47". Chỉ lấy phần trước dấu hai chấm, phần
  /// sau là tên việc mà mình đã có ở `name`.
  static String _monTuPopup(String? popupname) {
    final i = popupname?.indexOf(': ') ?? -1;
    return i > 0 ? popupname!.substring(0, i) : '';
  }

  static String? _attribute(String tag, String name) => RegExp(
    '''\\b${RegExp.escape(name)}\\s*=\\s*["']([^"']*)["']''',
    caseSensitive: false,
  ).firstMatch(tag)?.group(1);

  PortalError _sai() =>
      PortalError('Sai tài khoản hoặc mật khẩu LMS', saiMatKhau: true);

  /// HTML một trang Moodle bằng phiên [s], chỉ để **đọc** (vd. bảng điểm danh
  /// của chính mình trong `mod/attendance/view.php`). Chỉ nhận đường trong
  /// [_base]: cookie phiên không bao giờ đi tới host khác.
  Future<String> trang(LmsSession s, String url) async {
    final u = Uri.parse(url);
    if (u.origin != Uri.parse(_base).origin) {
      throw PortalError('Không phải trang của LMS');
    }
    final res = await _send(
      http.Request('GET', u)..headers['cookie'] = s.cookie,
    );
    return _text(res);
  }

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
    // Chỉ ghi phương thức với host+path: query của Moodle mang token phiên,
    // còn thân của lượt đăng nhập mang mật khẩu.
    final nhan = '${req.method} ${NhatKy.diaChi(req.url)}';
    final batDau = DateTime.now();
    NhatKy.ghi('lms', '→ $nhan');
    try {
      final res = await http.Response.fromStream(
        await _client.send(req).timeout(const Duration(seconds: 20)),
      );
      final ms = DateTime.now().difference(batDau).inMilliseconds;
      NhatKy.ghi(
        'lms',
        '← $nhan ${res.statusCode} (${ms}ms, ${res.bodyBytes.length} B)',
      );
      return res;
    } on PortalError {
      rethrow;
    } catch (_) {
      // Không log url/body: POST đăng nhập mang theo mật khẩu.
      NhatKy.ghi('lms', '✗ $nhan: mất kết nối');
      throw PortalError(
        'Không kết nối được LMS. Kiểm tra mạng.',
        offline: true,
      );
    }
  }
}

/// Khối "Sự kiện sắp đến" của Moodle: hạn nộp bài, mốc điểm danh, quiz sắp
/// mở... Lấy từ lịch tháng này và tháng sau rồi bỏ mốc đã qua; mặc định nhìn
/// trước 21 ngày và cắt còn 10 mục, đúng như khối trên web của trường.
///
/// Rỗng khi người dùng chưa bật LMS — không phải lỗi, chỉ là không có gì.
Future<List<LmsEvent>> suKienSapToi(
  DateTime now, {
  Duration truoc = const Duration(days: 21),
  int toiDa = 10,
  Lms? lms,
}) async {
  final s = await Lms.phien(lms: lms);
  if (s == null) return const [];
  final l = lms ?? Lms();
  final den = now.add(truoc);
  final out = <LmsEvent>[];
  // Khoảng 21 ngày vắt qua nhiều nhất hai tháng; cùng tháng thì Set gộp lại.
  for (final m in {(now.year, now.month), (den.year, den.month)}) {
    // Lượt gọi hỏng thì lấy tháng đó trong sổ ra, chứ đừng để trống cả khối.
    try {
      out.addAll(await l.calendar(s, m.$1, m.$2));
    } on PortalError {
      out.addAll(await lichDaLuu(m.$1, m.$2));
    }
  }
  final ds = locSuKien(out, now, truoc: truoc, toiDa: toiDa);
  await luuSuKien(ds);
  return ds;
}

/// Khoá sổ mục của lịch một tháng. Mỗi việc là một dòng [Kho] riêng, nên
/// Moodle bỏ một việc khỏi lịch thì dòng chỉ bị ẩn chứ không mất.
String khoaLich(int year, int month) =>
    'lms:lich:$year-${month.toString().padLeft(2, '0')}';

/// Cất nguyên mẻ lịch tháng, không lọc gì: chỗ hiển thị mới là chỗ lọc, còn
/// sổ thì giữ đủ để mất mạng vẫn có cái mà xem.
Future<void> luuLich(int year, int month, List<LmsEvent> ds) =>
    DsKho.nhap(khoaLich(year, month), [for (final e in ds) _raJson(e)]);

/// Lịch tháng đã lưu, không gọi mạng.
Future<List<LmsEvent>> lichDaLuu(int year, int month) async => [
  for (final m in await DsKho.doc(khoaLich(year, month)))
    _tuJson(Map<String, dynamic>.from(m as Map)),
];

/// Khoá cache của mẻ sự kiện lần trước.
const khoaSuKien = 'lms:su_kien';

/// Cất mẻ sự kiện lại để lượt sau có cái hiện ngay.
Future<void> luuSuKien(List<LmsEvent> ds) =>
    Cache.write(khoaSuKien, [for (final e in ds) _raJson(e)]);

/// Sự kiện của lượt lấy trước, đọc thẳng từ cache đã nạp sẵn vào RAM nên gọi
/// được ngay trong `build`. Lấy lại từ LMS mất cả lượt đăng nhập Moodle, có
/// khi nửa phút; trong lúc đó vẫn phải có cái để nhìn, và mất mạng thì đây là
/// tất cả những gì còn.
///
/// Lọc lại theo [now] vì mẻ cũ có thể đã qua mốc từ đời nào.
List<LmsEvent> suKienDaLuu(DateTime now) {
  final c = Cache.read(khoaSuKien);
  if (c == null) return const [];
  return locSuKien([
    for (final m in c.$1 as List) _tuJson(m as Map<String, dynamic>),
  ], now);
}

Map<String, dynamic> _raJson(LmsEvent e) => {
  'name': e.name,
  'course': e.course,
  'start': e.start.toIso8601String(),
  'keoDai': e.keoDai.inSeconds,
  'loai': e.loai,
  'url': e.url,
  'instance': e.instance,
  'xong': e.xong,
};

LmsEvent _tuJson(Map<String, dynamic> m) => (
  name: m['name'] as String? ?? '',
  course: m['course'] as String? ?? '',
  start: DateTime.parse(m['start'] as String),
  keoDai: Duration(seconds: m['keoDai'] as int? ?? 0),
  loai: m['loai'] as String? ?? '',
  url: m['url'] as String?,
  instance: m['instance'] as int? ?? 0,
  xong: m['xong'] as bool? ?? false,
);

/// Bỏ mốc đã qua và mốc quá xa, sắp theo thời gian rồi cắt còn [toiDa]. Lịch
/// tháng trả về cả tháng nên phần lọc này mới là thứ quyết định "sắp đến".
List<LmsEvent> locSuKien(
  List<LmsEvent> suKien,
  DateTime now, {
  Duration truoc = const Duration(days: 21),
  int toiDa = 10,
}) {
  final den = now.add(truoc);
  final out = [...suKien]
    ..retainWhere(
      (e) => !e.xong && e.start.isAfter(now) && e.start.isBefore(den),
    )
    ..sort((a, b) => a.start.compareTo(b.start));
  return out.take(toiDa).toList();
}
