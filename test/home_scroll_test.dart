import 'package:dlu_tkb/clock.dart';
import 'package:dlu_tkb/main.dart';
import 'package:dlu_tkb/portal.dart';
import 'package:dlu_tkb/settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'db_tam.dart';

final phien = Session(
  id: '2312577',
  fullName: 'Nguyễn Văn A',
  token: 't',
  expire: DateTime(2030),
);

void main() {
  setUp(dungDbTam);

  // Trang chủ phải dựng sẵn cả cột, kể cả thẻ nằm xa dưới màn hình: thẻ bị dẹp
  // rồi dựng lại là gọi portal lại, hiện khung chờ, chiều cao trang đổi — trên
  // iOS kéo quá mép dưới thì chiều cao đổi giữa lúc đang nảy, thành vòng lặp
  // nhảy lên nhảy xuống không dứt tới khi tắt app.
  testWidgets('cả trang dựng sẵn, không dẹp thẻ ngoài tầm nhìn', (t) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeTab(session: phien)),
      ),
    );
    await t.pump();

    expect(find.byType(ListView), findsNothing);
    // Menu nằm cuối trang, cách mép dưới màn hình rất xa.
    expect(find.text('Menu'), findsNothing);

    // Dẹp cây đi rồi tắt nhịp đồng hồ, không thì còn Timer treo lúc kết thúc.
    await t.pumpWidget(const SizedBox());
    Clock.instance.stop();
  });

  testWidgets('lời mời LMS bỏ qua được và chỉ hiện khi chưa kết nối', (
    t,
  ) async {
    await Settings.datLmsBat(false);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeTab(session: phien)),
      ),
    );
    await t.pump();
    await t.pump();
    expect(find.text('Học cùng LMS nhé?'), findsOneWidget);
    await t.tap(find.byTooltip('Để sau'));
    await t.pump();
    expect(find.text('Học cùng LMS nhé?'), findsNothing);

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeTab(session: phien)),
      ),
    );
    await t.pump();
    await t.pump();
    expect(find.text('Học cùng LMS nhé?'), findsNothing);

    await Settings.datLmsBat(true);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeTab(
            session: Session(
              id: 'student2',
              fullName: 'Student',
              token: 'test',
              expire: DateTime(2030),
            ),
          ),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    expect(find.text('Học cùng LMS nhé?'), findsNothing);
    await t.pumpWidget(const SizedBox());
    Clock.instance.stop();
  });

  testWidgets('nút kết nối LMS mở form và cho phép đóng', (t) async {
    await Settings.datLmsBat(false);
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(body: HomeTab(session: phien)),
      ),
    );
    await t.pump();
    await t.pump();
    await t.tap(find.text('Kết nối LMS'));
    await t.pumpAndSettle();
    expect(find.byType(LmsLoginDialog), findsOneWidget);
    await t.tap(find.text('Huỷ'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    Clock.instance.stop();
  });
}
