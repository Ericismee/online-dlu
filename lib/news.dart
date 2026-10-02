import 'dart:async';
import 'dart:math';

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

  /// Thư Online. null là chưa nạp xong lượt đầu — chuông còn xám, chưa bấm được.
  List<dynamic>? _online;

  /// Thông báo LMS, đọc ra từ SQLite nên lần mở app sau vẫn còn.
  List<LmsNotification> _lms = const [];

  /// Sự kiện sắp đến từ LMS. Nằm cùng chuông vì cũng là "việc đang đến với
  /// mình", chỉ khác là chưa xảy ra; để riêng một khối trên Trang chủ thì
  /// người chưa bật LMS phải cuộn qua một chỗ trống.
  List<LmsEvent> _suKien = const [];

  List<dynamic> get _tatCa => [..._lms, ...?_online];

  /// Số chưa xem lượt trước, để chỉ lắc chuông khi có cái mới — chứ không
  /// lắc lại mỗi lần làm mới.
  int _chuaXem = 0;

  Timer? _hen;
  final _ngau = Random();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hen?.cancel();
    _wiggle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final online = <dynamic>[];
    try {
      online.addAll(
        await (widget.portal ?? Portal()).messages(widget.session.token),
      );
    } on PortalError {
      // LMS remains independent when Online is unavailable.
    }
    if (!mounted) return;
    setState(() => _online = online);
    await _lamMoiLms();
  }

  /// Chỉ phần LMS: thư Online nặng hơn và không đổi mỗi phút, giữ nguyên nhịp
  /// cũ (nạp lượt đầu và lúc kéo xuống làm mới).
  Future<void> _lamMoiLms() async {
    try {
      final session = await Lms.phien();
      if (session != null) {
        await LmsKho.luu(await Lms().notifications(session));
      }
    } on PortalError {
      // Online messages remain visible when LMS is unavailable.
    }
    // Ba lượt riêng nhau: hộp thư hỏng thì sự kiện vẫn lên và ngược lại, còn
    // thông báo đã cất trong SQLite thì mất mạng cũng đọc ra được.
    // `suKienSapToi` tự trả rỗng khi chưa bật LMS nên khỏi hỏi lại ở đây.
    final lms = await LmsKho.doc();
    var suKien = _suKien;
    try {
      suKien = await (widget.suKien ?? suKienSapToi)(DateTime.now());
    } on PortalError {
      // Giữ danh sách lần trước, mất mạng không được dọn sạch hộp thư.
    }
    if (!mounted) return;
    setState(() {
      _lms = lms;
      _suKien = suKien;
    });
    final n = unread(_tatCa);
    if (n > _chuaXem) _wiggle.forward(from: 0);
    _chuaXem = n;
    _henLuotSau();
  }

  /// App đang mở thì tự lấy LMS về mỗi 90–120 giây. Lệch ngẫu nhiên để nhiều
  /// máy không gõ cửa Moodle cùng một nhịp.
  void _henLuotSau() {
    _hen?.cancel();
    _hen = Timer(Duration(seconds: 90 + _ngau.nextInt(31)), () => _lamMoiLms());
  }

  /// Đọc lại cờ đã xem sau khi đóng hộp thư, để số trên chuông khớp ngay.
  Future<void> _docLai() async {
    final lms = await LmsKho.doc();
    if (!mounted) return;
    setState(() => _lms = lms);
    _chuaXem = unread(_tatCa);
  }

  @override
  Widget build(BuildContext context) {
    final n = unread(_tatCa);
    return Semantics(
      button: true,
      label: n > 0 ? 'Thông báo, $n tin chưa đọc' : 'Thông báo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _online == null
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
                  color: _online == null ? Paper.ink3 : Paper.ink,
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

  Future<void> _open(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => _Inbox(online: _online!, lms: _lms, suKien: _suKien),
    );
    await _docLai();
  }
}

class _Inbox extends StatefulWidget {
  const _Inbox({required this.online, required this.lms, required this.suKien});
  final List<dynamic> online;
  final List<LmsNotification> lms;
  final List<LmsEvent> suKien;

  @override
  State<_Inbox> createState() => _InboxState();
}

class _InboxState extends State<_Inbox> {
  late List<LmsNotification> _lms = widget.lms;

  List<LmsEvent> get suKien => widget.suKien;

  /// Đánh dấu rồi đọc lại từ SQLite thay vì sửa tay bản ghi trên màn: cờ trên
  /// màn với cờ trong tệp không có đường lệch nhau.
  Future<void> _daXem([String? id]) async {
    await LmsKho.danhDauDaXem(id);
    final lms = await LmsKho.doc();
    if (mounted) setState(() => _lms = lms);
  }

  Future<void> _xem(LmsNotification n) async {
    await showDialog(context: context, builder: (_) => _ChiTiet(n));
    await _daXem(n.id);
  }

  /// Thông báo LMS lên trước thư Online: nó mới là thứ đổi mỗi phút.
  List<dynamic> get messages => [..._lms, ...widget.online];

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
                  _Message(m, onXem: _xem, onDaXem: _daXem),
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
  const _Message(this.m, {this.onXem, this.onDaXem});
  final dynamic m;

  /// Chỉ thông báo LMS mới xem/đánh dấu được; thư Online giữ nguyên như cũ.
  final Future<void> Function(LmsNotification n)? onXem;
  final Future<void> Function(String id)? onDaXem;

  @override
  Widget build(BuildContext context) {
    if (m is LmsNotification) {
      final n = m as LmsNotification;
      return PaperBox(
        color: n.unread ? Paper.sun : Paper.card,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              clean(n.subject),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Paper.ink,
              ),
            ),
            if (n.body.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(clean(n.body), maxLines: 3, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Pill('LMS · ${clean(n.sender)}', color: Paper.mint),
                Text(
                  n.date,
                  style: const TextStyle(fontSize: 12, color: Paper.ink3),
                ),
                if (onXem != null)
                  PaperButton(
                    label: 'Xem',
                    fontSize: 13,
                    color: Paper.sky,
                    onColor: Paper.ink,
                    onPressed: () => onXem!(n),
                  ),
                // Thông báo đã xem thì không có gì để đánh dấu nữa.
                if (onDaXem != null && n.unread)
                  PaperButton(
                    label: 'Đã xem',
                    fontSize: 13,
                    color: Paper.card,
                    onColor: Paper.ink,
                    onPressed: () => onDaXem!(n.id),
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

/// Nội dung đầy đủ một thông báo LMS. Hộp thư chỉ hiện 3 dòng đầu, thông báo
/// của Moodle thì thường dài hơn thế.
class _ChiTiet extends StatelessWidget {
  const _ChiTiet(this.n);
  final LmsNotification n;

  @override
  Widget build(BuildContext context) => PaperDialog(
    title: clean(n.subject),
    icon: Icons.school_rounded,
    color: Paper.mint,
    maxWidth: 420,
    children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Pill('LMS · ${clean(n.sender)}', color: Paper.mint),
          Text(n.date, style: const TextStyle(fontSize: 12, color: Paper.ink3)),
        ],
      ),
      const SizedBox(height: 12),
      if (n.body.isNotEmpty)
        Flexible(
          child: SingleChildScrollView(
            child: PaperBox(
              padding: const EdgeInsets.all(14),
              child: Text(
                clean(n.body),
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Paper.ink2,
                ),
              ),
            ),
          ),
        ),
      const SizedBox(height: 16),
      PaperButton(
        label: 'Đóng',
        color: Paper.card,
        onColor: Paper.ink,
        onPressed: () => Navigator.pop(context),
      ),
    ],
  );
}
