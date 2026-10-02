import 'package:flutter/material.dart';

import 'data.dart';
import 'lms.dart';
import 'paper.dart';
import 'portal.dart';
import 'su_kien.dart';

int unread(Iterable<dynamic> messages) => messages
    .where((m) => m is LmsNotification ? m.unread : m['IsRead'] == 0)
    .length;

/// Chuông + popup hộp thư, dán ở góc phải top bar.
class Bell extends StatefulWidget {
  const Bell({super.key, required this.session, this.portal, this.suKien});
  final Session session;
  final Portal? portal;

  /// Nguồn sự kiện LMS; để trống là lấy thật. Chỉ test mới truyền vào.
  final Future<List<LmsEvent>> Function(DateTime now)? suKien;

  @override
  State<Bell> createState() => _BellState();
}

class _BellState extends State<Bell>
    with Reloadable<Bell>, SingleTickerProviderStateMixin {
  /// Lắc chuông kiểu bell-wiggle của codex-resets.com: -14deg, 11deg, -5deg.
  late final _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final _angle = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.24), weight: 25),
    TweenSequenceItem(tween: Tween(begin: -0.24, end: 0.19), weight: 30),
    TweenSequenceItem(tween: Tween(begin: 0.19, end: -0.09), weight: 25),
    TweenSequenceItem(tween: Tween(begin: -0.09, end: 0.0), weight: 20),
  ]).animate(_wiggle);

  @override
  Future<void> reload() => _load();

  List<dynamic>? _msgs;

  /// Sự kiện sắp đến từ LMS. Nằm cùng chuông vì cũng là "việc đang đến với
  /// mình", chỉ khác là chưa xảy ra; để riêng một khối trên Trang chủ thì
  /// người chưa bật LMS phải cuộn qua một chỗ trống.
  List<LmsEvent> _suKien = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final combined = <dynamic>[];
    try {
      combined.addAll(
        await (widget.portal ?? Portal()).messages(widget.session.token),
      );
    } on PortalError {
      // LMS remains independent when Online is unavailable.
    }
    try {
      final session = await Lms.phien();
      if (session != null) {
        combined.addAll(await Lms().notifications(session));
      }
    } on PortalError {
      // Online messages remain visible when LMS is unavailable.
    }
    // Hai lượt gọi riêng: hộp thư hỏng thì sự kiện vẫn lên, và ngược lại.
    // `suKienSapToi` tự trả rỗng khi chưa bật LMS nên khỏi hỏi lại ở đây.
    var suKien = _suKien;
    try {
      suKien = await (widget.suKien ?? suKienSapToi)(DateTime.now());
    } on PortalError {
      // Giữ danh sách lần trước, mất mạng không được dọn sạch hộp thư.
    }
    if (mounted) {
      setState(() {
        _msgs = combined;
        _suKien = suKien;
      });
      if (unread(combined) > 0) _wiggle.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = unread(_msgs ?? const []);
    return Semantics(
      button: true,
      label: n > 0 ? 'Thông báo, $n tin chưa đọc' : 'Thông báo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _msgs == null
            ? null
            : () {
                _wiggle.forward(from: 0);
                _open(context);
              },
        child: AnimatedBuilder(
          animation: _angle,
          builder: (context, child) =>
              Transform.rotate(angle: _angle.value, child: child),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                // 12+22+12 = 46pt, đủ ngưỡng chạm.
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Paper.card,
                  border: Paper.border,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: Paper.shadow(3),
                ),
                child: Icon(
                  Icons.notifications_rounded,
                  size: 22,
                  color: _msgs == null ? Paper.ink3 : Paper.ink,
                ),
              ),
              if (n > 0)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Transform.rotate(
                    angle: -0.12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: Paper.accent,
                        border: Paper.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$n',
                        style: const TextStyle(
                          fontFamily: 'Baloo',
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Paper.card,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) => showDialog(
    context: context,
    builder: (_) => _Inbox(messages: _msgs!, suKien: _suKien),
  );
}

class _Inbox extends StatelessWidget {
  const _Inbox({required this.messages, required this.suKien});
  final List<dynamic> messages;
  final List<LmsEvent> suKien;

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(20),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
      decoration: BoxDecoration(
        color: Paper.paper,
        border: Paper.border,
        borderRadius: BorderRadius.circular(20),
        boxShadow: Paper.shadow(6),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Thông báo',
                  style: TextStyle(
                    fontFamily: 'Baloo',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: Paper.ink,
                  ),
                ),
              ),
              PaperButton(
                label: 'Đóng',
                color: Paper.card,
                onColor: Paper.ink,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // Việc chưa tới lên trước việc đã xong: hạn nộp bài đáng
                // nhìn hơn cái thư báo "đã nhận bài của bạn".
                if (suKien.isNotEmpty) ...[
                  const _Muc('Sự kiện sắp đến'),
                  SuKienNhom(suKien: suKien),
                  const SizedBox(height: 18),
                  const _Muc('Hộp thư'),
                ],
                if (messages.isEmpty)
                  const Text(
                    'Hộp thư trống.',
                    style: TextStyle(color: Paper.ink2),
                  ),
                for (final (i, m) in messages.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _Message(m),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

/// Tiêu đề một mục trong hộp thư.
class _Muc extends StatelessWidget {
  const _Muc(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'Baloo',
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: Paper.ink,
      ),
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.m);
  final dynamic m;

  @override
  Widget build(BuildContext context) {
    if (m is LmsNotification) {
      final notification = m as LmsNotification;
      return PaperBox(
        color: notification.unread ? Paper.sun : Paper.card,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              clean(notification.subject),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Paper.ink,
              ),
            ),
            if (notification.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                clean(notification.body),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Pill('LMS · ${clean(notification.sender)}', color: Paper.mint),
                const SizedBox(width: 6),
                Text(
                  notification.date,
                  style: const TextStyle(fontSize: 12, color: Paper.ink3),
                ),
              ],
            ),
          ],
        ),
      );
    }
    final isNew = m['IsRead'] == 0;
    return PaperBox(
      color: isNew ? Paper.sun : Paper.card,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clean(m['MessageSubject']),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Pill(m['SenderName'] as String? ?? '—', color: Paper.mint),
              const SizedBox(width: 6),
              Text(
                m['CreationDate'] as String? ?? '',
                style: const TextStyle(fontSize: 12, color: Paper.ink3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
