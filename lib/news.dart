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

/// Thư Online người dùng đã vuốt xoá. Portal không có API xoá nên cờ nằm
/// trong máy, y như cờ đã xem.
const _nhomOnlineAn = 'thong_bao_online_an';

String _onlineId(Map message) =>
    '${message['MessageID'] ?? message['ID'] ?? message['Id'] ?? message['id'] ?? '${message['SenderName']}:${message['CreationDate']}:${message['MessageSubject']}'}';

/// Portal không có API đánh dấu đã đọc, nên cờ nằm trong máy và phải chồng lên
/// danh sách lấy về — cả chỗ đếm huy hiệu lẫn chỗ hiện hộp thư, nếu không bấm
/// "Đã xem tất cả" rồi đóng hộp thư là số trên chuông vẫn y nguyên.
/// Thư đã vuốt xoá tính luôn là đã xem: huy hiệu khỏi đếm nó, mà nó vẫn còn
/// trong danh sách để nằm ở mục "Thông báo cũ".
Future<List<dynamic>> apDaXemOnline(Iterable<dynamic> online) async {
  final daXem = {for (final d in await Db.i.nhomDang(_nhomOnlineDaXem)) d.khoa};
  final an = {for (final d in await Db.i.nhomDang(_nhomOnlineAn)) d.khoa};
  return [
    for (final m in online)
      if (daXem.contains(_onlineId(m as Map)) || an.contains(_onlineId(m)))
        {...m, 'IsRead': 1}
      else
        m,
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

/// Tiêu đề một trang kèm chuông ở góc phải — đúng chỗ chuông vẫn đứng trên
/// Trang chủ, nên trang nào mở ra chuông cũng nằm y một vị trí.
class TieuDeTrang extends StatelessWidget {
  const TieuDeTrang(this.title, {super.key, required this.session, this.phai});
  final String title;
  final Session session;

  /// Thay chuông bằng thứ khác — trang mở dạng đẩy thì chỗ đó là nút Quay lại.
  final Widget? phai;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Display',
            fontWeight: FontWeight.w800,
            fontSize: 30,
            color: Paper.ink,
          ),
        ),
      ),
      const SizedBox(width: 12),
      phai ?? Bell(session: session),
    ],
  );
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
    // Thông báo LMS đã nằm sẵn trong SQLite từ nhịp trước: bày ra ngay. Đợi
    // đăng nhập LMS xong mới hiện thì nó lên sau thư Online cả nửa phút, dù
    // chữ đã nằm trong máy từ lâu.
    await _docKho();
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
    await _docKho();
    var suKien = _suKien;
    try {
      suKien = await (widget.suKien ?? suKienSapToi)(DateTime.now());
    } on PortalError {
      // Giữ danh sách lần trước, mất mạng không được dọn sạch hộp thư.
    }
    if (!mounted) return;
    setState(() => _suKien = suKien);
    final n = unread(_tatCa);
    if (n > _chuaXem) _wiggle.forward(from: 0);
    _chuaXem = n;
  }

  /// Thông báo và sự kiện LMS đã cất trong máy, không đụng tới mạng.
  Future<void> _docKho() async {
    final lms = await LmsKho.doc();
    final suKien = suKienDaLuu(DateTime.now());
    if (!mounted) return;
    setState(() {
      _lms = lms;
      // Mẻ cũ chỉ để lấp chỗ trống trong lúc chờ LMS trả lời; có mẻ mới rồi
      // thì đừng thụt lùi về nó.
      if (_suKien.isEmpty) _suKien = suKien;
    });
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
                  borderRadius: BorderRadius.all(Paper.radius),
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
                        borderRadius: BorderRadius.all(Paper.radius),
                      ),
                      child: Text(
                        '$n',
                        style: const TextStyle(
                          fontFamily: 'Display',
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
    // Đọc lại ngay lúc mở: chuông chỉ đưa sang danh sách tin còn hiện, mục
    // "Thông báo cũ" cần cả những dòng đã xem và đã xoá.
    _docLai();
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
    await _docLai();
  }

  Future<void> _xem(Tin t) async {
    await showDialog(context: context, builder: (_) => _ChiTiet(t));
    await _daXem(t);
  }

  /// Vuốt là tin rời hộp thư, xuống nằm ở mục "Thông báo cũ" — nơi cất chỉ
  /// tắt cờ nên chữ vẫn còn, mở mục cũ ra là đọc lại được.
  Future<void> _xoa(Tin t) async {
    if (t.laLms) {
      await LmsKho.xoa(t.id);
    } else {
      await Db.i.ghi(_nhomOnlineAn, t.id);
    }
    await _docLai();
  }

  /// Đọc lại cả hai nguồn từ nơi cất, kể cả dòng đã xoá: cờ trên màn với cờ
  /// trong máy không có đường lệch nhau.
  Future<void> _docLai() async {
    final lms = await LmsKho.doc(caDaXoa: true);
    final online = await apDaXemOnline(widget.online);
    if (!mounted) return;
    setState(() {
      _lms = lms;
      _online = online;
    });
  }

  /// Thông báo LMS lên trước thư Online: nó mới là thứ đổi mỗi phút.
  List<Tin> get messages => [
    for (final m in [..._lms, ..._online]) tin(m),
  ];

  /// Hộp thư chỉ bày tin chưa xem; tin đã xem dồn xuống mục "Thông báo cũ",
  /// mở ra xem lại khi cần chứ không chen vào chỗ tin mới.
  List<Tin> get _moi => [
    for (final t in messages)
      if (t.chuaXem) t,
  ];

  List<Tin> get _cu => [
    for (final t in messages)
      if (!t.chuaXem) t,
  ];

  /// Đang mở mục thông báo cũ hay không.
  bool _moCu = false;

  /// Một dòng hộp thư: vuốt ngang là xoá. Dòng trong mục cũ thì không vuốt
  /// nữa — nó đã nằm đúng chỗ của nó rồi, mà Dismissible cũng không cho dòng
  /// vừa vuốt ở lại cùng một danh sách.
  Widget _dong(Tin t, {bool cu = false}) {
    final than = _Message(t, onXem: _xem, onDaXem: _daXem);
    if (cu) return than;
    return Dismissible(
      key: ValueKey('moi:${t.nguon}:${t.id}'),
      background: const _NenXoa(),
      secondaryBackground: const _NenXoa(phai: true),
      onDismissed: (_) => _xoa(t),
      // Dismissible xếp nền với dòng vào một Stack kiểu loose, thả ra là thẻ
      // co lại vừa đúng chữ của nó — mỗi thẻ một bề ngang. Ép dòng rộng hết
      // hộp thư thì cả chồng thẻ mới thẳng mép.
      child: SizedBox(width: double.infinity, child: than),
    );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(20),
    child: Container(
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
      decoration: BoxDecoration(
        color: Paper.paper,
        border: Paper.border,
        borderRadius: BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(8),
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
                    fontFamily: 'Display',
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
          // với nút Đóng đã ăn hết chiều ngang, hai nút này bị bóp còn mươi
          // pixel. Wrap chứ không Row: máy hẹp thì nút sau xuống dòng.
          if (_moi.isNotEmpty || _cu.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_moi.isNotEmpty)
                  PaperButton(
                    label: 'Đã xem tất cả',
                    fontSize: 13,
                    color: Paper.mint,
                    onColor: Paper.ink,
                    onPressed: () => _daXem(),
                  ),
                if (_cu.isNotEmpty)
                  PaperButton(
                    label: _moCu
                        ? 'Ẩn thông báo cũ'
                        : 'Thông báo cũ (${_cu.length})',
                    fontSize: 13,
                    color: Paper.card,
                    onColor: Paper.ink,
                    onPressed: () => setState(() => _moCu = !_moCu),
                  ),
              ],
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
                if (_moi.isEmpty)
                  const Text(
                    'Hộp thư trống.',
                    style: TextStyle(color: Paper.ink2),
                  ),
                for (final (i, m) in _moi.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _dong(m),
                ],
                if (_moCu) ...[
                  const SizedBox(height: 18),
                  const _Muc('Thông báo cũ'),
                  for (final (i, t) in _cu.indexed) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _dong(t, cu: true),
                  ],
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
        fontFamily: 'Display',
        fontWeight: FontWeight.w800,
        fontSize: 16,
        color: Paper.ink,
      ),
    ),
  );
}

/// Nền lộ ra sau dòng đang bị vuốt. Vuốt chiều nào cũng xoá nên hai chiều
/// cùng một nền, chỉ đổi phía đặt thùng rác.
class _NenXoa extends StatelessWidget {
  const _NenXoa({this.phai = false});
  final bool phai;

  @override
  Widget build(BuildContext context) => Container(
    alignment: phai ? Alignment.centerRight : Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 18),
    decoration: BoxDecoration(
      color: Paper.rose,
      border: Paper.border,
      borderRadius: BorderRadius.all(Paper.radius),
    ),
    child: const Icon(Icons.delete_rounded, color: Paper.ink),
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
