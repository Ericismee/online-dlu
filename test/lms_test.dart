import 'dart:convert';

import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:dlu_tkb/settings.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'db_tam.dart';

/// Moodle giả: trang form, trang POST, trang /my/ và endpoint ajax.
MockClient moodle({
  required bool dung,
  List<dynamic> goi = const [],
  Map<String, String>? batBody,
}) => MockClient(moodleXuLy(dung: dung, goi: goi, batBody: batBody));

Future<http.Response> Function(http.Request) moodleXuLy({
  required bool dung,
  List<dynamic> goi = const [],
  Map<String, String>? batBody,
}) => (req) async {
  switch (req.url.path) {
    case '/login/index.php':
      if (req.method == 'GET') {
        return http.Response(
          '<input type="hidden" name="logintoken" value="tok1">',
          200,
          headers: {'set-cookie': 'MoodleSession=vodanh; path=/; HttpOnly'},
        );
      }
      batBody?.addAll(req.bodyFields);
      return dung
          ? http.Response(
              '',
              303,
              headers: {
                'location': '/login/index.php?testsession=9',
                'set-cookie': 'MoodleSession=thatsu; path=/; HttpOnly',
              },
            )
          : http.Response(
              '',
              303,
              headers: {'location': 'https://lms.dlu.edu.vn/login/index.php'},
            );
    case '/my/':
      // Chỉ cookie mới mới được coi là đã đăng nhập.
      return http.Response(
        req.headers['cookie'] == 'MoodleSession=thatsu'
            // Giống lms.dlu thật: M.cfg không có `userid`, id nằm trong JS
            // của trang.
            ? 'M.cfg = {"sesskey":"KEY123","wwwroot":"x"};'
                  '<div data-userid="7"></div>'
            : 'Bạn chưa đăng nhập',
        200,
      );
    case '/lib/ajax/service.php':
      // Không khai charset thì http.Response mã hoá body bằng latin1, chữ
      // Việt trong tên môn làm nó nổ ngay lúc dựng phản hồi giả.
      return http.Response(
        jsonEncode(goi),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
  }
  return http.Response('', 404);
};

void main() {
  // login() cất phiên vào Keychain, calendar() cất mẻ vào sổ — test cần cả
  // kho bí mật giả lẫn SQLite tạm.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await dungDbTam();
  });

  test(
    'đăng nhập dùng cookie Moodle cấp lại, không phải cookie vô danh',
    () async {
      final body = <String, String>{};
      final s = await Lms(client: moodle(dung: true, batBody: body))
          .login('2012345', 'mk');
      expect(s.cookie, 'MoodleSession=thatsu');
      expect(s.sesskey, 'KEY123');
      expect(s.userId, 7);
      expect(body['logintoken'], 'tok1');
      expect(body['username'], '2012345');
    },
  );

  // Mỗi lượt đăng nhập là một lần gửi mật khẩu đi; phiên Moodle sống nhiều
  // ngày nên phải dùng lại, chỉ đăng nhập khi nó chết.
  test('phiên còn sống thì dùng lại, không đăng nhập lần nữa', () async {
    FlutterSecureStorage.setMockInitialValues({
      'lms_username': '2012345',
      'lms_password': 'mk',
    });
    await Settings.datLmsBat(true);

    var soLanDangNhap = 0;
    final that = moodleXuLy(dung: true);
    Lms dem() => Lms(
      client: MockClient((req) async {
        if (req.url.path == '/login/index.php' && req.method == 'POST') {
          soLanDangNhap++;
        }
        return that(req);
      }),
    );

    Lms.boPhien();
    expect((await Lms.phien(lms: dem()))?.sesskey, 'KEY123');
    expect(soLanDangNhap, 1);

    // Lượt sau (vd mở lại app): phiên trong Keychain còn sống nên chỉ hỏi
    // /my/ một cái rồi dùng tiếp.
    Lms.boPhienTrongRam();
    expect((await Lms.phien(lms: dem()))?.sesskey, 'KEY123');
    expect(soLanDangNhap, 1);

    // Phiên chết (server không còn nhận cookie): phải đăng nhập lại.
    await LmsVault.luuPhien((
      cookie: 'MoodleSession=het',
      sesskey: 'CU',
      userId: 7,
    ));
    Lms.boPhienTrongRam();
    expect((await Lms.phien(lms: dem()))?.sesskey, 'KEY123');
    expect(soLanDangNhap, 2);
  });

  test('sai mật khẩu thì bị đẩy về form trống', () async {
    expect(
      () => Lms(client: moodle(dung: false)).login('2012345', 'sai'),
      throwsA(isA<PortalError>()),
    );
  });

  // Moodle gắn `action` vào việc còn phải làm. Nộp bài xong thì nó còn 0 mục
  // (hoặc hết actionable), mà khối "Sắp tới" cứ nhắc hoài thì phiền.
  test('bài đã nộp không còn nằm trong Sắp tới', () async {
    Map<String, Object?> ngay(String ten, int luc, Object? action) => {
      'events': [
        {
          'name': ten,
          'modulename': 'assign',
          'timestart': luc,
          'instance': 1,
          'course': {'fullname': 'CNPM'},
          'action': ?action,
        },
      ],
    };
    final now = DateTime.now();
    final mai = now.add(const Duration(days: 1)).millisecondsSinceEpoch ~/ 1000;
    final lms = Lms(
      client: moodle(
        dung: true,
        goi: [
          {
            'error': false,
            'data': {
              'weeks': [
                {
                  'days': [
                    ngay('Bài 1 đến hạn', mai, {
                      'itemcount': 1,
                      'actionable': true,
                    }),
                    ngay('Bài 2 đến hạn', mai + 60, {
                      'itemcount': 0,
                      'actionable': true,
                    }),
                    ngay('Bài 3 đến hạn', mai + 120, {
                      'itemcount': 1,
                      'actionable': false,
                    }),
                    ngay('Đóng quiz', mai + 180, null),
                  ],
                },
              ],
            },
          },
        ],
      ),
    );
    final viec = await lms.calendar(await lms.login('a', 'b'), 2026, 10);
    expect(viec.map((e) => e.xong), [false, true, true, false]);
    expect(locSuKien(viec, now).map((e) => e.name), [
      'Bài 1 đến hạn',
      'Đóng quiz',
    ]);
  });

  // Sổ giữ nguyên mẻ, không xoá gì: Moodle bỏ một việc khỏi lịch thì dòng chỉ
  // bị ẩn, mà lượt gọi hỏng thì vẫn còn cái để hiện.
  test('lịch tháng vào sổ, mất mạng vẫn đọc lại được', () async {
    final lms = Lms(
      client: moodle(
        dung: true,
        goi: [
          {
            'error': false,
            'data': {
              'weeks': [
                {
                  'days': [
                    {
                      'events': [
                        {
                          'name': 'Bài 1 đến hạn',
                          'modulename': 'assign',
                          'timestart': 1759312800,
                          'instance': 42,
                          'course': {'fullname': 'CNPM'},
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          },
        ],
      ),
    );
    expect(await lichDaLuu(2026, 10), isEmpty);
    await lms.calendar(await lms.login('a', 'b'), 2026, 10);

    final luu = await lichDaLuu(2026, 10);
    expect(luu, hasLength(1));
    expect(luu.single.name, 'Bài 1 đến hạn');
    expect(luu.single.instance, 42);
  });

  test('lịch tháng gom việc của mọi ngày', () async {
    final lms = Lms(
      client: moodle(
        dung: true,
        goi: [
          {
            'error': false,
            'data': {
              'weeks': [
                {
                  'days': [
                    {'events': []},
                    {
                      'events': [
                        {
                          'name': 'Bài tập 1 hết hạn',
                          'timestart': 1759312800,
                          'instance': 42,
                          'url': 'https://lms.dlu.edu.vn/mod/assign/view.php',
                          'course': {'fullname': 'Lập trình Web'},
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          },
        ],
      ),
    );
    final viec = await lms.calendar(await lms.login('a', 'b'), 2026, 10);
    expect(viec, hasLength(1));
    expect(viec.single.course, 'Lập trình Web');
    expect(viec.single.instance, 42);
    expect(viec.single.start.millisecondsSinceEpoch ~/ 1000, 1759312800);
  });

  // Dạng thật của lms.dlu: buổi điểm danh không có `course` lẫn `url`, tên
  // môn chỉ nằm trong `popupname` và cửa sổ điểm nằm ở `timeduration`.
  test(
    'buổi điểm danh: môn lấy từ popupname, cửa sổ từ timeduration',
    () async {
      final lms = Lms(
        client: moodle(
          dung: true,
          goi: [
            {
              'error': false,
              'data': {
                'weeks': [
                  {
                    'days': [
                      {
                        'events': [
                          {
                            'name': 'Điểm danh',
                            'modulename': 'attendance',
                            'timestart': 1790815500,
                            'timeduration': 300,
                            'instance': 159503,
                            'popupname': 'DPctk47: Điểm danh',
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            },
          ],
        ),
      );
      final e = (await lms.calendar(
        await lms.login('a', 'b'),
        2026,
        10,
      )).single;
      expect(e.loai, 'attendance');
      expect(e.course, 'DPctk47');
      expect(e.keoDai, const Duration(minutes: 5));
      expect(e.url, isNull);
    },
  );

  test('lỗi trong gói ajax thành PortalError, dù status 200', () async {
    final lms = Lms(
      client: moodle(
        dung: true,
        goi: [
          {
            'error': true,
            'exception': {'errorcode': 'invalidsesskey'},
          },
        ],
      ),
    );
    final s = await lms.login('a', 'b');
    expect(() => lms.calendar(s, 2026, 10), throwsA(isA<PortalError>()));
  });

  test('đọc thông báo Moodle chưa đọc', () async {
    final lms = Lms(
      client: moodle(
        dung: true,
        goi: [
          {
            'error': false,
            'data': [
              {
                'subject': 'Thông báo môn học',
                'smallmessage': 'Có bài tập mới',
                'timecreated': 1759312800,
                'read': 0,
                'userfrom': {'fullname': 'Giảng viên'},
              },
            ],
          },
        ],
      ),
    );
    final notifications = await lms.notifications(await lms.login('a', 'b'));
    expect(notifications.single.subject, 'Thông báo môn học');
    expect(notifications.single.sender, 'Giảng viên');
    expect(notifications.single.unread, isTrue);
  });

  // lms.dlu.edu.vn không gửi chứng chỉ trung gian, app phải mang theo. PEM hỏng
  // thì dựng client là ném luôn, nên chỉ cần dựng thử một cái là biết.
  test('client mặc định dựng được với chứng chỉ trung gian mang theo', () {
    expect(Lms.new, returnsNormally);
  });
}
