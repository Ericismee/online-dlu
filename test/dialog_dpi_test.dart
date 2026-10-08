import 'package:dlu_tkb/paper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Changelog thật của v1.2.3 — thân hộp thoại "Có bản mới" dài đúng cỡ này.
const _notes =
    '- Sửa lịch ở màn nào là mọi màn khác thấy ngay, không phải kéo làm mới '
    'hay mở lại app.\n'
    '- Nhắc trước giờ tự hẹn lại ngay sau khi bạn thêm, sửa hay xoá lịch tự đặt.\n'
    '- Đồng hồ đếm ngược tới giờ vào lớp chạy từng giây thay vì nhảy từng phút.\n'
    '- Gợi ý giờ đặt lịch học theo thói quen mới của bạn: giờ hay chọn gần đây '
    'có tiếng nói hơn giờ của học kỳ trước, đổi lịch là gợi ý đổi theo.\n'
    '- Gợi ý giờ né thêm 15 phút hai đầu mỗi tiết học, không còn xếp việc sát '
    'giờ tan lớp.\n'
    '- Hạn bài tập càng gần thì Xếp giờ làm càng đẩy buổi làm bài lên sớm; hạn '
    'còn xa thì xếp vào giờ bạn thường rảnh.\n'
    '- Lần đầu dùng, khi app chưa biết gì về bạn, gợi ý giờ theo khung hợp lý '
    'sẵn thay vì chọn ngẫu nhiên.\n'
    '- Bấm Đã xong hay xoá một mục lịch tự đặt cũng là góp ý cho gợi ý giờ: '
    'khung nào hay bỏ dở thì app thôi đề xuất.';

void main() {
  /// Máy thật, từ máy nhỏ chữ thường tới máy nhỏ chữ phóng to hết cỡ.
  const may = <(String, Size, double, double)>[
    ('Android nhỏ', Size(320, 480), 2, 1),
    ('Android phổ thông', Size(360, 640), 3, 1),
    ('Android DPI cao', Size(412, 915), 3.5, 1),
    ('Android chữ to', Size(360, 640), 3, 1.3),
    ('Android chữ to hết cỡ', Size(360, 640), 3, 2),
    ('iPhone SE chữ to', Size(320, 568), 2, 1.35),
  ];

  for (final (ten, size, dpr, chu) in may) {
    testWidgets('hộp thoại bản mới không vỡ trên $ten', (t) async {
      t.view.physicalSize = size * dpr;
      t.view.devicePixelRatio = dpr;
      addTearDown(t.view.reset);

      await t.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(chu)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmDialog(
                context,
                title: 'Có bản mới v1.2.3',
                body: _notes,
                ok: 'Tải về',
                icon: Icons.rocket_launch_rounded,
                color: Paper.mint,
              ),
              child: const Text('mở'),
            ),
          ),
        ),
      );
      await t.tap(find.text('mở'));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull, reason: 'tràn khung trên $ten');
      // Nút phải bấm được, không thì hộp thoại coi như kẹt.
      expect(find.text('Tải về'), findsOneWidget);
      await t.tap(find.text('Tải về'), warnIfMissed: false);
      await t.pumpAndSettle();
      expect(find.text('Tải về'), findsNothing, reason: 'nút không bấm nổi');
    });
  }

  testWidgets('hộp thoại nhiều lựa chọn cũng cuộn được khi chữ to hết cỡ', (
    t,
  ) async {
    t.view.physicalSize = const Size(320, 480) * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => chonDialog(
              context,
              title: 'Xoá "Lên ATC"',
              body: _notes,
              lua: const ['Chỉ buổi này', 'Cả chuỗi lặp'],
            ),
            child: const Text('mở'),
          ),
        ),
      ),
    );
    await t.tap(find.text('mở'));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    // Ba nút mà chữ to gấp đôi thì chính hàng nút cũng phải cuộn — miễn là
    // cuộn tới được chứ không bị cắt mất.
    await t.ensureVisible(find.text('Cả chuỗi lặp'));
    await t.pumpAndSettle();
    await t.tap(find.text('Cả chuỗi lặp'));
    await t.pumpAndSettle();
    expect(find.text('Cả chuỗi lặp'), findsNothing);
  });
}
