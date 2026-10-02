import 'dart:convert';

import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Moodle giả: trang form, trang POST, trang /my/ và endpoint ajax.
MockClient moodle({
  required bool dung,
  List<dynamic> goi = const [],
  Map<String, String>? batBody,
}) => MockClient((req) async {
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
            ? 'M.cfg = {"sesskey":"KEY123","userid":7,"wwwroot":"x"};'
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
});

void main() {
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

  test('sai mật khẩu thì bị đẩy về form trống', () async {
    expect(
      () => Lms(client: moodle(dung: false)).login('2012345', 'sai'),
      throwsA(isA<PortalError>()),
    );
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
}
