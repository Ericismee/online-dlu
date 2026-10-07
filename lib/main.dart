import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'behavior.dart';
import 'cache.dart';
import 'clock.dart';
import 'courses.dart';
import 'curriculum.dart';
import 'data.dart';
import 'db.dart';
import 'exams.dart';
import 'graph.dart';
import 'info.dart';
import 'lms.dart';
import 'login.dart';
import 'marks.dart';
import 'news.dart';
import 'paper.dart';
import 'portal.dart';
import 'prefetch.dart';
import 'settings.dart';
import 'su_kien.dart';
import 'update_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nền giấy luôn sáng, nên ép icon status bar / nav bar màu mực.
  // Không đặt thì Android vẽ icon trắng, mất tiêu trên nền kem.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  // Mở sổ của tài khoản đã lưu trước khi đụng tới dữ liệu: mỗi tài khoản một
  // tệp SQLite riêng, đọc nhầm sổ chung một lượt là app hiện số của người khác.
  await Db.moCho((await Vault.read())?.$1);
  await Db.i.nhapTuPrefs();
  await Cache.init();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'DLU Online',
    debugShowCheckedModeBanner: false,
    theme: Paper.theme(),
    // App chỉ có một bộ màu giấy; khai báo hẳn để máy đang dark mode
    // không bị Material tự chế biến thêm.
    themeMode: ThemeMode.light,
    // Cỡ chữ hệ thống to quá thì thanh tab và lưới lịch vỡ hàng; chặn ở 1.3.
    builder: (context, child) =>
        MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: child!),
    home: const Root(),
  );
}

/// Decides between the login screen and the app: with saved credentials we log
/// in again on every cold start, since the portal token only lives ~2h.
class Root extends StatefulWidget {
  const Root({super.key});

  @override
  State<Root> createState() => _RootState();
}

class _RootState extends State<Root> with WidgetsBindingObserver {
  Session? _session;
  String? _error;
  bool _checking = true;

  /// Đang bị khoá (đã bật khoá sinh trắc học và vừa quay lại từ nền).
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Mở app lần nào cũng thử lấy số mới: màn hiện số trong máy ngay, lượt
  /// tải chạy song song. Token còn hạn thì khỏi đăng nhập lại.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Xuống nền thì khoá ngay nếu đã bật — đợi tới lúc resumed mới khoá thì
    // app đã kịp hiện lại một khung hình dữ liệu trước khi khoá.
    if (state == AppLifecycleState.paused) {
      // Xuống nền thì tắt cả hai nhịp: máy khoá màn hình mà vẫn gõ cửa portal
      // và Moodle theo chu kỳ là ăn pin không để làm gì.
      PortalNhip.dung();
      LmsNhip.dung();
      unawaited(_khoaNeuBat());
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    if (_locked) return; // đợi mở khoá xong mới nạp lại số mới
    LmsNhip.chay();
    if (_session != null) PortalNhip.chay();
    final s = _session;
    if (s == null || !s.valid) {
      _resume();
    } else {
      unawaited(_napSan(s));
    }
  }

  Future<void> _khoaNeuBat() async {
    if (_session != null && await Settings.khoaBat() && mounted) {
      setState(() => _locked = true);
    }
  }

  Future<void> _resume() async {
    final saved = await Vault.read();
    if (saved == null) return setState(() => _checking = false);

    // Có phiên cũ thì vào app ngay, đăng nhập lại chạy ngầm.
    final cached = Cache.read('session')?.$1;
    if (cached != null) {
      _session = Session.fromMap(Map<String, dynamic>.from(cached as Map));
    }
    if (mounted) setState(() => _checking = _session == null);

    try {
      final s = await Portal().login(saved.$1, saved.$2);
      await Cache.write('session', s.toMap());
      if (mounted) setState(() => _session = s);
      // Vào app bằng phiên cũ thì token đã hết hạn (~2h), mọi màn nạp bằng nó
      // đều hỏng và nằm trống. Có token mới là nạp lại hết, đừng để người
      // dùng phải kéo xuống mới thấy hôm nay học gì.
      if (cached != null && mounted) await Cache.reloadAll();
      unawaited(_napSan(s));
    } on PortalError catch (e) {
      // Chỉ khi portal đích thân từ chối tài khoản mới xoá mật khẩu đã lưu.
      // Mất mạng, portal bảo trì trả 403, hay lần mở app đầu chưa có phiên cũ
      // — mật khẩu vẫn đúng, giữ nguyên để lần sau tự vào lại; cùng lắm là
      // màn đăng nhập hiện lý do, chứ không bắt gõ lại mật khẩu.
      if (!e.saiMatKhau) {
        if (mounted) setState(() => _error = e.message);
        return;
      }
      await Vault.clear();
      await Cache.clear();
      if (mounted) {
        setState(() {
          _session = null;
          _error = e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  /// Nạp sẵn phần còn lại cho offline, xong thì giao lại cho màn đang mở.
  Future<void> _napSan(Session s) async {
    await Prefetch.run(s);
    if (mounted) await Cache.reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: const [
                Skeleton(width: 220, height: 34),
                SizedBox(height: 20),
                Skeleton(height: 120, ink: true),
                SizedBox(height: 16),
                Skeleton(height: 320, ink: true),
              ],
            ),
          ),
        ),
      );
    }
    if (_session == null) {
      return LoginScreen(
        initialError: _error,
        onLoggedIn: (s) async {
          await Cache.write('session', s.toMap());
          unawaited(_napSan(s));
          if (mounted) {
            setState(() {
              _session = s;
              _error = null;
            });
          }
        },
      );
    }
    if (_locked) {
      return AppLockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return Shell(
      session: _session!,
      onLogout: () async {
        PortalNhip.dung();
        // Tài khoản LMS cũng phải đi theo: để lại là người đăng nhập sau thấy
        // LMS đang bật, nối sẵn với Moodle của chủ cũ và đọc được thông báo
        // lớp của người ta.
        await LmsVault.clear();
        await Settings.datLmsBat(false);
        await Vault.clear();
        await Cache.clear();
        if (mounted) setState(() => _session = null);
      },
    );
  }
}

/// Vỏ app: nội dung + thanh điều hướng giấy cắt dán ở đáy.
class Shell extends StatefulWidget {
  const Shell({super.key, required this.session, required this.onLogout});
  final Session session;
  final VoidCallback onLogout;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _tab = 2; // mở app là Trang chủ

  @override
  void initState() {
    super.initState();
    // Vào được app mới bắt đầu nhịp làm mới portal: màn đăng nhập thì chưa có
    // token mà gọi.
    PortalNhip.chay();
  }

  @override
  void dispose() {
    PortalNhip.dung();
    super.dispose();
  }

  @override
  // Nút back Android: đang ở tab khác thì về Trang chủ, ở Trang chủ mới thoát.
  Widget build(BuildContext context) => PopScope(
    canPop: _tab == 2,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) setState(() => _tab = 2);
    },
    child: Scaffold(
      body: DotBackground(
        child: Stack(
          children: [
            IndexedStack(
              index: _tab,
              children: [
                ScheduleTab(session: widget.session),
                ExamsTab(session: widget.session),
                HomeTab(
                  session: widget.session,
                  onGo: (i) => setState(() => _tab = i),
                ),
                MarksScreen(session: widget.session),
                InfoScreen(session: widget.session, onLogout: widget.onLogout),
              ],
            ),
            // nội dung cuộn xuống dưới status bar, làm mờ cho mượt
            const _TopBlur(),
            Align(
              alignment: Alignment.bottomCenter,
              child: PaperBar(
                index: _tab,
                onTap: (i) => setState(() => _tab = i),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dải mờ dưới status bar để chữ cuộn qua không đè lên giờ / pin.
class _TopBlur extends StatelessWidget {
  const _TopBlur();

  @override
  // Dải giấy đặc: nội dung cuộn qua thì khuất hẳn, không nhoè không chuyển sắc.
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: IgnorePointer(
      child: Container(
        height: MediaQuery.paddingOf(context).top,
        color: Paper.paper,
      ),
    ),
  );
}

/// Thanh đáy kiểu giấy cắt: nền kem, viền mực, bóng cứng, tab đang chọn là
/// một mẩu giấy màu dán hơi lệch phía sau icon.
class PaperBar extends StatelessWidget {
  const PaperBar({super.key, required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  /// icon, ảnh (nếu có), nhãn, màu giấy, độ nghiêng.
  static const _items = <(IconData?, String?, String, Color, double)>[
    (Icons.calendar_month_rounded, null, 'Lịch', Paper.sun, -0.06),
    (Icons.edit_note_rounded, null, 'Thi', Paper.rose, 0.04),
    (null, 'assets/logo_icon.png', 'Trang chủ', Paper.peach, 0.0),
    (Icons.grade_rounded, null, 'Điểm', Paper.accent, -0.04),
    (Icons.badge_rounded, null, 'Hồ sơ', Paper.sky, 0.05),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Paper.card,
        border: Paper.border,
        borderRadius: const BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (var i = 0; i < _items.length; i++)
            _Tab(item: _items[i], on: i == index, onTap: () => onTap(i)),
        ],
      ),
    ),
  );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.on, required this.onTap});
  final (IconData?, String?, String, Color, double) item;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, asset, label, color, tilt) = item;
    return Semantics(
      selected: on,
      child: Pressable(
        onTap: onTap,
        builder: (down) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Transform.rotate(
                angle: on ? tilt : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: on ? color : Colors.transparent,
                    border: on ? Paper.border : null,
                    borderRadius: const BorderRadius.all(Paper.radius),
                    boxShadow: on ? Paper.shadow(down ? 0 : 3) : null,
                  ),
                  child: asset != null
                      ? Opacity(
                          opacity: on ? 1 : 0.55,
                          child: Image.asset(
                            asset,
                            width: 26,
                            height: 26,
                            excludeFromSemantics: true,
                          ),
                        )
                      : Icon(
                          icon,
                          size: 22,
                          color: on ? Paper.ink : Paper.ink2,
                        ),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Display',
                  fontSize: 12,
                  fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                  color: on ? Paper.ink : Paper.ink2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.session, required this.onGo});
  final Session session;
  final ValueChanged<int> onGo;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with Reloadable<HomeTab> {
  @override
  Future<void> reload() => _load();

  /// Lớp sinh viên chỉ có ở /api/student/info, nạp một lần khi mở app.
  String? _lop;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final i = await Portal().studentInfo(widget.session.token);
      if (mounted) setState(() => _lop = i['LopSinhVien'] as String?);
    } on PortalError {
      // giữ lớp cũ
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: PullRefresh(
          // Không dùng ListView: thẻ nào cuộn khuất là nó dẹp đi, lúc quay lại
          // dựng lại từ đầu — mỗi thẻ ở đây initState là gọi portal, hiện
          // khung chờ rồi mới cao trở lại, nên chiều cao trang cứ đổi. Trên
          // iOS kéo quá mép là chiều cao đổi lúc đang nảy, nảy lại làm thẻ
          // khác dựng lại, thành vòng lặp nhảy lên nhảy xuống không dứt. Dựng
          // sẵn cả cột thì chiều cao đứng yên; có mười thẻ, không đắt.
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + 20,
              20,
              MediaQuery.paddingOf(context).bottom + chuaThanhDuoi,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Ticker(
                  builder: (_, now) =>
                      _Header(now: now, session: widget.session),
                ),
                const SizedBox(height: 16),
                Ticker(builder: (_, now) => StaleDataWarning(now: now)),
                const UpdateBanner(),
                const Changelog(),
                // Dưới mấy lời nhắc của chính app (cập nhật, dữ liệu cũ, đổi
                // mới) là tới mình: thẻ tên rồi tới hai vòng tiến độ, xong mới
                // đến các thẻ theo ngày.
                // Các thẻ hiện ra lần lượt cho đỡ khô khan.
                PopIn(
                  child: _Me(session: widget.session, lop: _lop),
                ),
                const SizedBox(height: 20),
                PopIn(
                  delay: const Duration(milliseconds: 70),
                  child: TienDoCard(session: widget.session),
                ),
                const SizedBox(height: 20),
                // Việc LMS sắp đến hạn: chỉ hiện khi đã cận kề, nên nó đứng
                // đây là đúng — thấy trước cả lịch hôm nay.
                const SuKienCard(),
                // Điểm danh nằm ngay trong dòng tiết của mục "Hôm nay":
                // nó là việc của chính buổi học đó.
                PopIn(
                  delay: const Duration(milliseconds: 140),
                  child: TodayLessons(session: widget.session),
                ),
                PopIn(
                  delay: const Duration(milliseconds: 180),
                  child: Ticker(
                    builder: (_, now) =>
                        _NextExam(session: widget.session, now: now),
                  ),
                ),
                const SizedBox(height: 20),
                PopIn(
                  delay: const Duration(milliseconds: 220),
                  child: MenuCard(onGo: widget.onGo, session: widget.session),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hai vòng tiến độ trên Trang chủ: GPA tích luỹ và số tiết đã học trong
/// tháng. Cả hai số đều đã nằm trong cache (prefetch kéo sẵn bảng điểm và lịch
/// tháng), nên thẻ này gần như không đụng tới portal.
class TienDoCard extends StatefulWidget {
  const TienDoCard({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<TienDoCard> createState() => _TienDoCardState();
}

class _TienDoCardState extends State<TienDoCard> with Reloadable<TienDoCard> {
  @override
  Future<void> reload() => _load();

  double? _gpa;
  (int, int)? _tiet;
  bool _xong = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = widget.portal ?? Portal();
    final token = widget.session.token;
    final now = Clock.instance.value;
    double? gpa;
    try {
      final years = await p.marks(token, await p.studyProgram(token));
      final keys = termKeys(years);
      final rec = keys.isEmpty
          ? null
          : subjectsOf(years, keys.first).firstOrNull;
      final v = toNum(rec?['TB_TL_TN']).toDouble();
      // Kỳ đầu chưa có điểm nào thì portal trả 0 — vòng 0/4 chẳng nói gì,
      // thà không hiện.
      if (v > 0) gpa = v;
    } on PortalError {
      // Không có điểm thì vẫn hiện được vòng tiết học.
    }
    (int, int)? tiet;
    try {
      final thang = await fetchMonth(p, token, DateTime(now.year, now.month));
      tiet = tietDaHoc(thang, now);
    } on PortalError {
      // Ngược lại cũng vậy.
    }
    if (mounted) {
      setState(() {
        _gpa = gpa;
        _tiet = tiet;
        _xong = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_xong) return const Skeleton(height: 196, ink: true);
    final gpa = _gpa;
    final tiet = _tiet;
    if (gpa == null && (tiet == null || tiet.$2 == 0)) {
      return const SizedBox.shrink();
    }
    final thang = Clock.instance.value.month;
    return PaperBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Tiến độ',
                style: TextStyle(
                  fontFamily: 'Display',
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Paper.ink,
                ),
              ),
              const Spacer(),
              Pill('Tháng $thang', color: Paper.sun),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (gpa != null)
                Expanded(
                  child: PaperRing(
                    value: gpa / 4,
                    center: gpa.toStringAsFixed(2),
                    duoi: 'trên 4.0',
                    label: 'GPA tích luỹ',
                    color: Paper.accent,
                  ),
                ),
              // Vạch ngăn mảnh giữa hai vòng, chỉ khi có cả hai.
              if (gpa != null && tiet != null && tiet.$2 > 0)
                Container(
                  width: 1.5,
                  height: 86,
                  color: Paper.ink.withValues(alpha: 0.12),
                ),
              if (tiet != null && tiet.$2 > 0)
                Expanded(
                  child: PaperRing(
                    value: tiet.$1 / tiet.$2,
                    center: '${tiet.$1}/${tiet.$2}',
                    duoi: 'tiết',
                    label: 'Đã học trong tháng',
                    color: Paper.sky,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now, required this.session});
  final DateTime now;
  final Session session;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Đại Học Đà Lạt',
              style: TextStyle(
                fontFamily: 'Display',
                fontWeight: FontWeight.w800,
                fontSize: 34,
                height: 1.1,
                color: Paper.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${dayNames[now.weekday]}, ${now.day}/${now.month}/${now.year}',
              style: const TextStyle(color: Paper.ink2, fontSize: 14),
            ),
            // Mất mạng thì app vẫn hiện số cũ; nói rõ cũ từ lúc nào.
            if (Cache.syncedAt != null) ...[
              const SizedBox(height: 6),
              Pill(dataAge(Cache.syncedAt!, now), color: Paper.card),
            ],
          ],
        ),
      ),
      const SizedBox(width: 12),
      // Không chèn lề: chuông phải đúng một mức với chuông của các trang khác,
      // đổi tab mà nó nhích lên nhích xuống là thấy ngay.
      Bell(session: session),
    ],
  );
}

/// Quá lâu không có mạng để làm mới thì cảnh báo đỏ ngay trên Trang chủ —
/// không có nút tắt, vì số đang hiện có thể đã sai lệch nhiều so với thực tế.
class StaleDataWarning extends StatelessWidget {
  const StaleDataWarning({super.key, required this.now});
  final DateTime now;

  static const limit = Duration(days: 1);

  @override
  Widget build(BuildContext context) {
    final at = Cache.syncedAt;
    if (at == null || now.difference(at) <= limit) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: PaperBox(
        color: Paper.accent,
        child: Row(
          children: [
            const Icon(Icons.warning_rounded, color: Paper.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đã hơn 1 ngày chưa làm mới — kéo xuống để cập nhật dữ liệu mới',
                style: const TextStyle(
                  // Giấy trên cam chỉ 2.82:1, và đây đúng là câu cần đọc được
                  // nhất trên Trang chủ.
                  color: Paper.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Me extends StatelessWidget {
  const _Me({required this.session, required this.lop});
  final Session session;
  final String? lop;

  @override
  Widget build(BuildContext context) => PaperBox(
    color: Paper.sun,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.fullName,
          style: const TextStyle(
            fontFamily: 'Display',
            fontWeight: FontWeight.w800,
            fontSize: 22,
            height: 1.2,
            color: Paper.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'MSSV ${session.id}',
          style: Paper.mono.copyWith(fontSize: 15, color: Paper.ink),
        ),
        const SizedBox(height: 2),
        Text(
          'Lớp ${lop ?? '…'}',
          style: const TextStyle(fontSize: 15, color: Paper.ink2),
        ),
      ],
    ),
  );
}

/// Tab Lịch: chỉ có biểu đồ tháng.
class ScheduleTab extends StatelessWidget {
  const ScheduleTab({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 940),
      child: PullRefresh(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 20,
            20,
            MediaQuery.paddingOf(context).bottom + chuaThanhDuoi,
          ),
          children: [
            TieuDeTrang('Thời khoá biểu', session: session),
            const SizedBox(height: 12),
            Ticker(
              builder: (_, now) => MonthGraph(session: session, now: now),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Ca thi gần nhất còn lại, lấy từ cùng API với tab Thi.
class _NextExam extends StatefulWidget {
  const _NextExam({required this.session, required this.now});
  final Session session;
  final DateTime now;

  @override
  State<_NextExam> createState() => _NextExamState();
}

class _NextExamState extends State<_NextExam> with Reloadable<_NextExam> {
  List<dynamic>? _exams;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Future<void> reload() => _load();

  Future<void> _load() async {
    try {
      final e = await Portal().exams(widget.session.token);
      if (mounted) setState(() => _exams = e);
    } on PortalError {
      if (mounted) setState(() => _exams ??= const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_exams == null) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 20),
        child: Skeleton(height: 120, ink: true),
      );
    }
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final next = sortExams(_exams!, today)
        .where((e) => !parseDMY(e['NgayThi'] as String).isBefore(today))
        .firstOrNull;
    if (next == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sắp thi',
            style: TextStyle(
              fontFamily: 'Display',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 10),
          ExamCard(next, today: today),
        ],
      ),
    );
  }
}

/// Một mục menu: tab, icon, nhãn, màu giấy. Tab âm = mở trang riêng thay vì
/// chuyển tab dưới.
typedef MucMenu = (int, IconData, String, Color);

/// Một danh mục: icon, tên, màu, các mục bên trong.
typedef DanhMuc = (IconData, String, Color, List<MucMenu>);

/// Thẻ menu trên Trang chủ: ba danh mục, bấm vào là mở màn danh mục đó.
///
/// Trước đây là một danh sách phẳng mười một dòng kéo thả được. Mười một dòng
/// cùng cỡ chữ cùng kiểu icon thì mắt không có chỗ nghỉ, mà thứ tự tự kéo cũng
/// chẳng cứu được: vẫn mười một dòng. Chia nhóm là thấy ba dòng, mỗi dòng nói
/// rõ bên trong có gì.
class MenuCard extends StatelessWidget {
  const MenuCard({super.key, required this.onGo, required this.session});
  final ValueChanged<int> onGo;
  final Session session;

  static const danhMuc = <DanhMuc>[
    (
      Icons.menu_book_rounded,
      'Học tập',
      Paper.sun,
      [
        (0, Icons.calendar_month_rounded, 'Thời khoá biểu', Paper.sun),
        (1, Icons.edit_note_rounded, 'Lịch thi', Paper.rose),
        (-1, Icons.menu_book_rounded, 'Học phần', Paper.mint),
        (-3, Icons.school_rounded, 'Chương trình đào tạo', Paper.sky),
      ],
    ),
    (
      Icons.grade_rounded,
      'Kết quả',
      Paper.accent,
      [
        (3, Icons.grade_rounded, 'Điểm', Paper.accent),
        (-6, Icons.trending_up_rounded, 'Cải thiện', Paper.rose),
        (-2, Icons.emoji_events_rounded, 'Điểm rèn luyện', Paper.peach),
        (-4, Icons.fact_check_rounded, 'Phiếu rèn luyện', Paper.mint),
      ],
    ),
    (
      Icons.person_rounded,
      'Cá nhân',
      Paper.sky,
      [
        (4, Icons.badge_rounded, 'Hồ sơ', Paper.sky),
        (-5, Icons.settings_rounded, 'Cài đặt', Paper.card),
        (-7, Icons.system_update_rounded, 'Cập nhật', Paper.sky),
      ],
    ),
  ];

  void _mo(BuildContext context, int tab) {
    if (tab >= 0) return onGo(tab);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => switch (tab) {
          -1 => CoursesTab(session: session),
          -2 => BehaviorScreen(session: session),
          -4 => BehaviorDetailScreen(session: session),
          -5 => SettingsScreen(session: session),
          -6 => ImprovementScreen(session: session),
          -7 => const ChangelogScreen(),
          _ => CurriculumScreen(session: session),
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Menu',
        style: TextStyle(
          fontFamily: 'Display',
          fontWeight: FontWeight.w800,
          fontSize: 22,
          color: Paper.ink,
        ),
      ),
      const SizedBox(height: 10),
      for (final (i, d) in danhMuc.indexed) ...[
        if (i > 0) const SizedBox(height: 16),
        // Tên danh mục là một cái thẻ giấy màu, không phải dòng chữ trơn:
        // nhìn xuống là thấy ngay khối nào thuộc nhóm nào.
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: d.$3,
              border: Paper.border,
              borderRadius: BorderRadius.all(Paper.radius),
              boxShadow: Paper.shadow(3),
            ),
            child: Text(
              d.$2,
              style: const TextStyle(
                fontFamily: 'Display',
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: Paper.ink,
              ),
            ),
          ),
        ),
        // Ô tự nó đã là mẩu giấy có viền với bóng riêng; bọc thêm một thẻ
        // nữa chỉ là thẻ lồng thẻ, nhìn nặng mà chẳng nói thêm gì.
        LayoutBuilder(
          builder: (_, c) {
            const khe = 10.0;
            // Hai ô một hàng: ô nằm ngang nên cần bề ngang cho nhãn, mà
            // hàng thấp hơn thì cả danh mục cũng gọn hơn lưới ba cột.
            final rong = (c.maxWidth - khe) / 2;
            return Wrap(
              spacing: khe,
              runSpacing: khe,
              children: [
                for (final (tab, icon, label, color) in d.$4)
                  SizedBox(
                    width: rong,
                    child: _MenuO(
                      icon: icon,
                      label: label,
                      color: color,
                      onTap: () => _mo(context, tab),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ],
  );
}

/// Một ô menu: cả ô là một mẩu giấy viền mực có bóng cứng, trong đó huy hiệu
/// icon màu nằm cạnh nhãn. Ô liền khối như vầy đọc ra một món bấm được, chứ
/// không phải mảng màu trơ với dòng chữ rơi ở dưới.
class _MenuO extends StatelessWidget {
  const _MenuO({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    shift: 3,
    builder: (down) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Paper.card,
        border: Paper.border,
        borderRadius: BorderRadius.all(Paper.radius),
        boxShadow: Paper.shadow(down ? 0 : 3),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: Paper.ink, width: 2),
              borderRadius: BorderRadius.all(Paper.radius),
            ),
            child: Icon(icon, size: 21, color: Paper.ink),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Display',
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w700,
                color: Paper.ink,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
