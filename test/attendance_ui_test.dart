import 'dart:convert';

import 'package:dlu_tkb/lms.dart';
import 'package:dlu_tkb/settings.dart';
import 'package:dlu_tkb/su_kien.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'db_tam.dart';

void main() {
  testWidgets('phiếu điểm danh hiện môn, trạng thái và gửi lựa chọn', (
    t,
  ) async {
    await dungDbTam();
    Lms.boPhien();
    FlutterSecureStorage.setMockInitialValues({});
    await Settings.datLmsBat(true);
    await LmsVault.save('sv', 'mk');
    addTearDown(Lms.boPhien);
    Map<String, String>? submitted;
    final lms = Lms(
      client: MockClient((request) async {
        switch (request.url.path) {
          case '/login/index.php':
            if (request.method == 'GET') {
              return http.Response(
                '<input name=logintoken value=tok>',
                200,
                headers: {
                  'set-cookie': 'MoodleSession=vodanh; path=/; HttpOnly',
                },
              );
            }
            return http.Response(
              '',
              303,
              headers: {
                'set-cookie': 'MoodleSession=thatsu; path=/; HttpOnly',
                'location': '/login/index.php?testsession=9',
              },
            );
          case '/my/':
            return http.Response(
              'M.cfg = {\u0022sesskey\u0022:\u0022KEY123\u0022,'
              '\u0022wwwroot\u0022:\u0022x\u0022};'
              '<div data-userid=\u00227\u0022></div>',
              200,
            );
          case '/mod/attendance/view.php':
            return http.Response(
              '<a href=\u0027/mod/attendance/attendance.php?'
              'sessid=91&amp;sesskey=KEY123\u0027>Open</a>',
              200,
            );
          case '/mod/attendance/attendance.php':
            if (request.method == 'GET') {
              return http.Response.bytes(
                utf8.encode(
                  '<input name=\u0027status\u0027 value=\u002722738\u0027 '
                  'id=\u0027present\u0027>'
                  '<label for=\u0027present\u0027>Có mặt</label>'
                  '<input name=\u0027status\u0027 value=\u002722739\u0027 '
                  'id=\u0027absent\u0027>'
                  '<label for=\u0027absent\u0027>Vắng</label>',
                ),
                200,
                headers: {'content-type': 'text/html; charset=utf-8'},
              );
            }
            submitted = request.bodyFields;
            return http.Response(
              '',
              303,
              headers: {'location': '/mod/attendance/view.php?id=159503'},
            );
        }
        return http.Response('', 404);
      }),
    );
    final now = DateTime.now();
    final event = (
      name: 'Điểm danh buổi 5',
      course: 'Phát triển ứng dụng Web',
      start: now.subtract(const Duration(minutes: 1)),
      keoDai: const Duration(minutes: 5),
      loai: 'attendance',
      xong: false,
      url: null as String?,
      instance: 159503,
    );

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => moDiemDanh(context, event, lms: lms),
              child: const Text('Mở phiếu'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Mở phiếu'));
    await t.pumpAndSettle();

    expect(find.text('Phát triển ứng dụng Web'), findsOneWidget);
    expect(find.textContaining('Điểm danh buổi 5'), findsOneWidget);
    expect(find.text('Có mặt'), findsOneWidget);
    expect(find.text('Vắng'), findsOneWidget);

    await t.tap(find.text('Có mặt'));
    await t.pump();
    await t.tap(find.text('Gửi điểm danh'));
    await t.pumpAndSettle();

    expect(submitted?['status'], '22738');
    expect(
      find.text('Đã gửi Có mặt cho Phát triển ứng dụng Web ✨'),
      findsOneWidget,
    );
  });
}
