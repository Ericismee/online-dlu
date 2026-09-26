import 'dart:ui';

import 'package:flutter/material.dart';

import 'data.dart';
import 'exams.dart';
import 'graph.dart';
import 'info.dart';
import 'login.dart';
import 'news.dart';
import 'paper.dart';
import 'portal.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'TKB',
    debugShowCheckedModeBanner: false,
    theme: Paper.theme(),
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

class _RootState extends State<Root> {
  Session? _session;
  String? _error;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  Future<void> _resume() async {
    final saved = await Vault.read();
    if (saved != null) {
      try {
        _session = await Portal().login(saved.$1, saved.$2);
      } on PortalError catch (e) {
        _error = e.message;
      }
    }
    if (mounted) setState(() => _checking = false);
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
                Skeleton(width: 220, height: 34, radius: 10),
                SizedBox(height: 20),
                Skeleton(height: 120, radius: 16, ink: true),
                SizedBox(height: 16),
                Skeleton(height: 320, radius: 16, ink: true),
              ],
            ),
          ),
        ),
      );
    }
    if (_session == null) {
      return LoginScreen(
        initialError: _error,
        onLoggedIn: (s) => setState(() {
          _session = s;
          _error = null;
        }),
      );
    }
    return Shell(
      session: _session!,
      onLogout: () async {
        await Vault.clear();
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
  int _tab = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DotBackground(
      child: Stack(
        children: [
          IndexedStack(
            index: _tab,
            children: [
              HomeTab(session: widget.session),
              ExamsTab(session: widget.session),
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
  );
}

/// Dải mờ dưới status bar để chữ cuộn qua không đè lên giờ / pin.
class _TopBlur extends StatelessWidget {
  const _TopBlur();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: MediaQuery.paddingOf(context).top,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Paper.paper.withValues(alpha: 0.92),
                Paper.paper.withValues(alpha: 0.55),
              ],
            ),
          ),
        ),
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

  static const _items = [
    (Icons.calendar_month_rounded, 'Lịch', Paper.sun, -0.06),
    (Icons.edit_note_rounded, 'Thi', Paper.rose, 0.04),
    (Icons.badge_rounded, 'Hồ sơ', Paper.sky, 0.05),
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      margin: const EdgeInsets.fromLTRB(28, 0, 28, 14),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Paper.card,
        border: Paper.border,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
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
  final (IconData, String, Color, double) item;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color, tilt) = item;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
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
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  boxShadow: on ? Paper.shadow(3) : null,
                ),
                child: Icon(icon, size: 22, color: on ? Paper.ink : Paper.ink3),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Baloo',
                fontSize: 12,
                fontWeight: on ? FontWeight.w800 : FontWeight.w600,
                color: on ? Paper.ink : Paper.ink3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.session});
  final Session session;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  /// Lớp sinh viên chỉ có ở /api/student/info, nạp một lần khi mở app.
  String? _lop;

  @override
  void initState() {
    super.initState();
    Portal()
        .studentInfo(widget.session.token)
        .then(
          (i) => mounted
              ? setState(() => _lop = i['LopSinhVien'] as String?)
              : null,
        )
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 20,
            20,
            120,
          ),
          children: [
            _Header(now: now, session: widget.session),
            const SizedBox(height: 16),
            _Me(session: widget.session, lop: _lop),
            const SizedBox(height: 16),
            MonthGraph(session: widget.session, now: now),
          ],
        ),
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
                fontFamily: 'Baloo',
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
          ],
        ),
      ),
      const SizedBox(width: 12),
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Bell(session: session),
      ),
    ],
  );
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
            fontFamily: 'Baloo',
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
