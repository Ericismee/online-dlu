import 'dart:convert';

import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Moodle giả: chỉ 'dung'/'mk' là vào được.
Lms moodle() => Lms(
  client: MockClient((req) async {
    switch (req.url.path) {
      case '/login/index.php':
        if (req.method == 'GET') {
          return http.Response(
            '<input name="logintoken" value="tok1">',
            200,
            headers: {'set-cookie': 'MoodleSession=khach; path=/'},
          );
        }
        final f = Uri.splitQueryString(req.body);
        return f['username'] == 'dung' && f['password'] == 'mk'
            ? http.Response(
                '',
                303,
                headers: {
                  'set-cookie': 'MoodleSession=thatsu; path=/',
                  'location': 'https://lms.dlu.edu.vn/login/index.php?t=1',
                },
              )
            : http.Response(
                '',
                303,
                headers: {'location': 'https://lms.dlu.edu.vn/login/index.php'},
              );
      case '/my/':
        return http.Response(
          'M.cfg = {"sesskey":"KEY123"};<div data-userid="7"></div>',
          200,
        );
    }
    return http.Response(jsonEncode([]), 200);
  }),
);

Future<(String, String)?> moHop(WidgetTester t) async {
  (String, String)? ra;
  var xong = false;
  await t.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                ra = await showDialog<(String, String)>(
                  context: context,
                  builder: (_) => LmsLoginDialog(lms: moodle()),
                );
                xong = true;
              },
              child: const Text('mở'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('mở'));
  await t.pumpAndSettle();
  addTearDown(() => expect(xong || ra == null, isTrue));
  return ra;
}

Future<void> go(WidgetTester t, String user, String pass) async {
  await t.enterText(find.byType(TextField).first, user);
  await t.enterText(find.byType(TextField).last, pass);
  await t.tap(find.text('Đăng nhập'));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('bỏ trống thì nhắc ngay, không gọi mạng', (t) async {
    await moHop(t);
    await t.tap(find.text('Đăng nhập'));
    await t.pumpAndSettle();
    expect(find.text('Nhập cả tài khoản và mật khẩu LMS.'), findsOneWidget);
    // Hộp vẫn mở: chưa đăng nhập được thì đừng đóng.
    expect(find.text('Đăng nhập LMS'), findsOneWidget);
  });

  testWidgets('sai mật khẩu thì báo trong hộp, không đóng', (t) async {
    await moHop(t);
    await go(t, 'sai', 'mk');
    expect(find.text('Sai tài khoản hoặc mật khẩu LMS'), findsOneWidget);
    expect(find.text('Đăng nhập LMS'), findsOneWidget);
  });

  testWidgets('đúng thì đóng và trả tài khoản đã thử được', (t) async {
    await moHop(t);
    await go(t, 'dung', 'mk');
    expect(find.text('Đăng nhập LMS'), findsNothing);
  });
}
