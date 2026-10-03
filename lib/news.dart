import 'package:flutter/material.dart';

import 'db.dart';
import 'data.dart';
import 'lms.dart';
import 'paper.dart';
import 'portal.dart';
import 'su_kien.dart';

int unread(Iterable<dynamic> messages) => messages.where(_chuaXem).length;

/// Thư Online coi là chưa xem khi portal không nói rõ nó đã đọc. Trước đây
/// điều kiện là `IsRead == 0`, nên hộp thư mà portal trả về không có field đó
/// thì mọi thư Online bị tính là đã xem: huy hiệu không lên số và nút "Đã xem
/// tất cả" không bao giờ hiện.
bool _chuaXem(dynamic m) =>
    m is LmsNotification ? m.unread : (m as Map)['IsRead'] != 1;

const _nhomOnlineDaXem = 'thong_bao_online_da_xem';

String _onlineId(Map message) =>
    '${message['MessageID'] ?? message['ID'] ?? message['Id'] ?? message['id'] ?? '${message['SenderName']}:${message['CreationDate']}:${message['MessageSubject']}'}';

/// Portal không có API đánh dấu đã đọc, nên cờ nằm trong máy và phải chồng lên
/// danh sách lấy về — cả chỗ đếm huy hiệu lẫn chỗ hiện hộp thư, nếu không bấm
/// "Đã xem tất cả" rồi đóng hộp thư là số trên chuông vẫn y nguyên.
Future<List<dynamic>> apDaXemOnline(Iterable<dynamic> online) async {
  final daXem = {for (final d in await Db.i.nhomDang(_nhomOnlineDaXem)) d.khoa};
  return [
    for (final m in online)
      if (daXem.contains(_onlineId(m as Map))) {...m, 'IsRead': 1} else m,
  ];
}

/// Một dòng hộp thư đã chuẩn hoá. Online và LMS đi chung một đường từ đây trở
/// đi nên không còn chỗ nào cho hai nguồn hiện lệch nhau.
typedef Tin = ({
  String id,
  bool laLms,
  String nguon,
  String subject,
  String sender,
  String date,
  String body,
  bool chuaXem,
  LmsNotification? lms,
});

Tin tin(dynamic m) {
  if (m is LmsNotification) {
    return (
      id: m.id,
      laLms: true,
      nguon: 'LMS',
      subject: m.subject,
      sender: m.sender,
      date: m.date,
      body: m.body,
      chuaXem: m.unread,
      lms: m,
    );
  }
  final o = m as Map;
  return (
    id: _onlineId(o),
    laLms: false,
    nguon: 'Online',
    subject: o['MessageSubject'] as String? ?? '',
    sender: o['SenderName'] as String? ?? '—',
    date: o['CreationDate'] as String? ?? '',
    body: _bodyOnline(o),
    chuaXem: _chuaXem(o),
    lms: null,
  );
}

/// ponytail: chưa dò được tên field nội dung của hộp thư portal, nên thử lần
/// lượt các tên nó thường dùng. Không có cái nào thì coi như thư không có thân
/// — đúng bằng những gì app hiện hôm nay, không tệ hơn.
String _bodyOnline(Map o) {
  for (final k in const [
    'MessageContent',
    'MessageBody',
    'Content',
    'Body',
    'Message',
  ]) {
    final v = o[k];
    if (v is String && v.trim().isNotEmpty) return v;
  }
  return '';
}

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

  @override
  void initState() {
    super.initState();
    LmsNhip.them(_lamMoiLms);
    _load();
  }

  @override
  void dispose() {
    LmsNhip.bo(_lamMoiLms);
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
    final daXem = await apDaXemOnline(online);
    if (!mounted) return;
    setState(() => _online = daXem);
    await _lamMoiLms();
  }

  /// Chỉ phần LMS, gọi lại theo [LmsNhip]: thư Online nặng hơn và không đổi
  /// mỗi phút, giữ nguyên nhịp cũ (nạp lượt đầu và lúc kéo xuống làm mới).
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
  }

  /// Đọc lại cờ đã xem sau khi đóng hộp thư, để số trên chuông khớp ngay.
  Future<void> _docLai() async {
    final lms = await LmsKho.doc();
    final online = await apDaXemOnline(_online ?? const []);
    if (!mounted) return;
    setState(() {
      _lms = lms;
      _online = online;
    });
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
                          // Kem trên cam chỉ 3.03:1, mực trên cam 5.23:1.
                          color: Paper.ink,
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
  late List<dynamic> _online = widget.online;

  @override
  void initState() {
    super.initState();
    _docOnlineDaXem();
  }

  Future<void> _docOnlineDaXem() async {
    final online = await apDaXemOnline(widget.online);
    if (!mounted) return;
    setState(() => _online = online);
  }

  List<LmsEvent> get suKien => widget.suKien;

  /// Đánh dấu rồi đọc lại cờ từ nơi cất thay vì sửa tay bản ghi trên màn: cờ
  /// trên màn với cờ trong tệp không có đường lệch nhau.
  Future<void> _daXem([Tin? t]) async {
    if (t == null || t.laLms) await LmsKho.danhDauDaXem(t?.id);
    if (t == null) {
      for (final m in _online.where(_chuaXem)) {
        await Db.i.ghi(_nhomOnlineDaXem, _onlineId(m as Map));
      }
    } else if (!t.laLms) {
      await Db.i.ghi(_nhomOnlineDaXem, t.id);
    }
    final lms = await LmsKho.doc();
    final online = await apDaXemOnline(widget.online);
    if (!mounted) return;
    setState(() {
      _lms = lms;
      _online = online;
    });
  }

  Future<void> _xem(Tin t) async {
    await showDialog(context: context, builder: (_) => _ChiTiet(t));
    await _daXem(t);
  }

  /// Thông báo LMS lên trước thư Online: nó mới là thứ đổi mỗi phút.
  List<Tin> get messages => [
    for (final m in [..._lms, ..._online]) tin(m),
  ];

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
          // Hàng riêng, không chen vào hàng tiêu đề: trên máy hẹp thì tiêu đề
          // với nút Đóng đã ăn hết chiều ngang, nút này bị bóp còn mươi pixel.
          if (messages.any((t) => t.chuaXem)) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: PaperButton(
                label: 'Đã xem tất cả',
                fontSize: 13,
                color: Paper.mint,
                onColor: Paper.ink,
                onPressed: () => _daXem(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
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
  const _Message(this.t, {this.onXem, this.onDaXem});
  final Tin t;

  final Future<void> Function(Tin t)? onXem;
  final Future<void> Function(Tin t)? onDaXem;

  @override
  Widget build(BuildContext context) {
    final (subject, sender, date, body) = (t.subject, t.sender, t.date, t.body);
    return PaperBox(
      color: t.chuaXem ? Paper.sun : Paper.card,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            clean(subject),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Paper.ink,
            ),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(clean(body), maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill('${t.nguon} · ${clean(sender)}', color: Paper.mint),
              Text(
                date,
                style: const TextStyle(fontSize: 12, color: Paper.ink2),
              ),
              if (t.chuaXem)
                const Pill('Chưa xem', color: Paper.sun)
              else
                const Pill('Đã xem', color: Paper.card),
              if (onXem != null)
                PaperButton(
                  label: 'Xem',
                  fontSize: 13,
                  color: Paper.sky,
                  onColor: Paper.ink,
                  onPressed: () => onXem!(t),
                ),
              if (onDaXem != null && t.chuaXem)
                PaperButton(
                  label: 'Đã xem',
                  fontSize: 13,
                  color: Paper.card,
                  onColor: Paper.ink,
                  onPressed: () => onDaXem!(t),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Nội dung đầy đủ một tin. Hộp thư chỉ hiện 3 dòng đầu, thông báo của Moodle
/// thì thường dài hơn thế.
class _ChiTiet extends StatelessWidget {
  const _ChiTiet(this.t);
  final Tin t;

  @override
  Widget build(BuildContext context) => PaperDialog(
    title: clean(t.subject),
    icon: t.laLms ? Icons.school_rounded : Icons.mail_rounded,
    color: Paper.mint,
    maxWidth: 420,
    children: [
      Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Pill('${t.nguon} · ${clean(t.sender)}', color: Paper.mint),
          Text(t.date, style: const TextStyle(fontSize: 12, color: Paper.ink2)),
        ],
      ),
      const SizedBox(height: 12),
      if (t.body.isEmpty)
        const Text(
          'Thư này không có nội dung kèm theo.',
          style: TextStyle(fontSize: 14, color: Paper.ink2),
        )
      else
        Flexible(
          child: SingleChildScrollView(
            child: PaperBox(
              padding: const EdgeInsets.all(14),
              child: Text(
                clean(t.body),
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
