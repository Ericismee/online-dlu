import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cache.dart';
import 'graph.dart';
import 'nhac.dart';
import 'paper.dart';
import 'portal.dart';
import 'update_check.dart';

/// Cờ lưu trong SharedPreferences, đọc/ghi trực tiếp — không cần Store riêng
/// vì mỗi cờ chỉ có một chỗ đọc (màn Cài đặt) và một chỗ dùng.
class Settings {
  static const _khoaDev = 'dev_mode';
  static const _khoaNguyHiem = 'unlock_dangerous';
  static const _khoaLock = 'app_lock';

  static Future<bool> devMode() async =>
      (await SharedPreferences.getInstance()).getBool(_khoaDev) ?? false;
  static Future<void> datDevMode(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_khoaDev, v);

  static Future<bool> nguyHiem() async =>
      (await SharedPreferences.getInstance()).getBool(_khoaNguyHiem) ?? false;
  static Future<void> datNguyHiem(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_khoaNguyHiem, v);

  static Future<bool> khoaBat() async =>
      (await SharedPreferences.getInstance()).getBool(_khoaLock) ?? false;
  static Future<void> datKhoaBat(bool v) async =>
      (await SharedPreferences.getInstance()).setBool(_khoaLock, v);
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _dev;
  bool? _nguyHiem;
  bool? _khoa;
  bool _dangLamMoi = false;
  bool _dangKiemTra = false;

  @override
  void initState() {
    super.initState();
    _doc();
  }

  Future<void> _doc() async {
    final dev = await Settings.devMode();
    final nguyHiem = await Settings.nguyHiem();
    final khoa = await Settings.khoaBat();
    if (mounted) {
      setState(() {
        _dev = dev;
        _nguyHiem = nguyHiem;
        _khoa = khoa;
      });
    }
  }

  Future<void> _lamMoiData() async {
    setState(() => _dangLamMoi = true);
    await Cache.refreshAll();
    if (mounted) {
      setState(() => _dangLamMoi = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Đã làm mới dữ liệu')));
    }
  }

  Future<void> _kiemTraCapNhat() async {
    setState(() => _dangKiemTra = true);
    final v = await UpdateCheck.newerVersion();
    if (!mounted) return;
    setState(() => _dangKiemTra = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(v == null ? 'Đã là bản mới nhất' : 'Có bản mới v$v'),
      ),
    );
  }

  Future<void> _doiKhoa(bool v) async {
    if (v) {
      final auth = LocalAuthentication();
      final duoc =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!duoc) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Máy này không hỗ trợ khoá sinh trắc học'),
            ),
          );
        }
        return;
      }
      try {
        final ok = await auth.authenticate(
          localizedReason: 'Xác thực để bật khoá ứng dụng',
        );
        if (!ok) return;
      } catch (_) {
        return;
      }
    }
    await Settings.datKhoaBat(v);
    if (mounted) setState(() => _khoa = v);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Paper.paper,
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 940),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            MediaQuery.paddingOf(context).top + 20,
            20,
            MediaQuery.paddingOf(context).bottom + 40,
          ),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cài đặt',
                    style: TextStyle(
                      fontFamily: 'Baloo',
                      fontWeight: FontWeight.w800,
                      fontSize: 30,
                      color: Paper.ink,
                    ),
                  ),
                ),
                PaperButton(
                  label: 'Quay lại',
                  color: Paper.card,
                  onColor: Paper.ink,
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            NhacToggle(session: widget.session, portal: widget.portal),
            const SizedBox(height: 20),
            PaperBox(
              onTap: _dangLamMoi ? null : _lamMoiData,
              child: Row(
                children: [
                  const Icon(Icons.refresh_rounded, color: Paper.ink),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Làm mới Data',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Paper.ink,
                      ),
                    ),
                  ),
                  if (_dangLamMoi)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            PaperBox(
              onTap: _dangKiemTra ? null : _kiemTraCapNhat,
              child: Row(
                children: [
                  const Icon(Icons.system_update_rounded, color: Paper.ink),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Kiểm tra bản cập nhật',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Paper.ink,
                      ),
                    ),
                  ),
                  if (_dangKiemTra)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _CongTac(
              icon: Icons.code_rounded,
              label: 'Chế độ nhà phát triển',
              value: _dev,
              onChanged: (v) async {
                await Settings.datDevMode(v);
                if (mounted) setState(() => _dev = v);
              },
            ),
            const SizedBox(height: 10),
            _CongTac(
              icon: Icons.warning_amber_rounded,
              label: 'Mở khoá tính năng nguy hiểm',
              color: Paper.peach,
              value: _nguyHiem,
              onChanged: (v) async {
                await Settings.datNguyHiem(v);
                if (mounted) setState(() => _nguyHiem = v);
              },
            ),
            const SizedBox(height: 10),
            _CongTac(
              icon: Icons.fingerprint_rounded,
              label: 'Khoá ứng dụng bằng sinh trắc học',
              color: Paper.sky,
              value: _khoa,
              onChanged: _doiKhoa,
            ),
          ],
        ),
      ),
    ),
  );
}

class _CongTac extends StatelessWidget {
  const _CongTac({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.color = Paper.card,
  });
  final IconData icon;
  final String label;
  final bool? value;
  final ValueChanged<bool> onChanged;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final v = value;
    if (v == null) return const Skeleton(height: 60, radius: 16, ink: true);
    return PaperBox(
      color: v ? color : Paper.card,
      child: Row(
        children: [
          Icon(icon, color: Paper.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Paper.ink,
              ),
            ),
          ),
          Switch(
            value: v,
            onChanged: onChanged,
            activeThumbColor: Paper.ink,
            activeTrackColor: Paper.sun,
          ),
        ],
      ),
    );
  }
}

/// Màn khoá app: chặn hết nội dung tới khi xác thực sinh trắc học xong.
class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  bool _dang = false;

  @override
  void initState() {
    super.initState();
    _thu();
  }

  Future<void> _thu() async {
    setState(() => _dang = true);
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: 'Xác thực để mở ứng dụng',
      );
      if (ok) widget.onUnlocked();
    } catch (_) {
      // Xác thực hỏng (huỷ, khoá quá nhiều lần...) thì cứ đứng ở màn khoá,
      // người dùng bấm nút để thử lại.
    } finally {
      if (mounted) setState(() => _dang = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Paper.paper,
    body: DotBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 56, color: Paper.ink),
              const SizedBox(height: 16),
              const Text(
                'Ứng dụng đang khoá',
                style: TextStyle(
                  fontFamily: 'Baloo',
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: Paper.ink,
                ),
              ),
              const SizedBox(height: 20),
              PaperButton(
                label: _dang ? 'Đang xác thực…' : 'Mở khoá',
                onPressed: _dang ? () {} : _thu,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Công tắc nhắc trước giờ vào lớp. Mặc định tắt, tự bật mới có. Tắt ở đây
/// thì xoá hết lịch hẹn đang chờ, bật thì hẹn lại ngay từ lịch trong cache.
class NhacToggle extends StatefulWidget {
  const NhacToggle({super.key, required this.session, this.portal});
  final Session session;
  final Portal? portal;

  @override
  State<NhacToggle> createState() => _NhacToggleState();
}

class _NhacToggleState extends State<NhacToggle> {
  bool? _bat;

  /// Máy có cho hẹn đúng phút không — không thì nhắc vẫn chạy nhưng được
  /// phép trễ, nên phải nói thẳng ra chứ đừng hứa suông 15 phút.
  bool _chinhXac = true;

  @override
  void initState() {
    super.initState();
    _doc();
  }

  Future<void> _doc() async {
    final bat = await Nhac.bat();
    final chinhXac = await Nhac.chinhXacDuoc();
    if (mounted) {
      setState(() {
        _bat = bat;
        _chinhXac = chinhXac;
      });
    }
  }

  Future<void> _doi(bool v) async {
    setState(() => _bat = v);
    await Nhac.datBat(v);
    if (!v) return;
    // Hẹn ngay chứ không đợi lượt mở app sau: bật xong mà tối nay chưa nhắc
    // thì người dùng tưởng công tắc hỏng. Lịch đã có trong cache nên thường
    // không đụng portal.
    final now = DateTime.now();
    final p = widget.portal ?? Portal();
    final ngay = <DateTime, List<dynamic>>{};
    for (final m in [
      DateTime(now.year, now.month),
      DateTime(now.year, now.month + 1),
    ]) {
      try {
        final d = await fetchMonth(p, widget.session.token, m);
        ngay.addAll({
          for (final e in d.entries) DateTime(m.year, m.month, e.key): e.value,
        });
      } on PortalError {
        // Thiếu một tháng thì vẫn hẹn được các buổi của tháng còn lại.
      }
    }
    await Nhac.datLai(ngay);
  }

  @override
  Widget build(BuildContext context) {
    final bat = _bat;
    if (bat == null) return const Skeleton(height: 64, radius: 16, ink: true);
    return Column(
      children: [
        PaperBox(
          color: bat ? Paper.mint : Paper.card,
          child: Row(
            children: [
              Icon(
                bat
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: Paper.ink,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nhắc trước giờ vào lớp',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Paper.ink,
                      ),
                    ),
                    Text(
                      bat ? 'Báo trước 15 phút' : 'Đang tắt',
                      style: const TextStyle(fontSize: 13, color: Paper.ink2),
                    ),
                  ],
                ),
              ),
              Switch(
                value: bat,
                onChanged: _doi,
                activeThumbColor: Paper.ink,
                activeTrackColor: Paper.sun,
              ),
            ],
          ),
        ),
        if (bat && !_chinhXac) ...[
          const SizedBox(height: 10),
          PaperBox(
            color: Paper.peach,
            onTap: () async {
              await Nhac.xinChinhXac();
              await _doc();
            },
            child: const Row(
              children: [
                Icon(Icons.alarm_rounded, color: Paper.ink),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Máy đang chặn báo thức chính xác nên nhắc có thể trễ. '
                    'Bấm để mở phần cấp quyền.',
                    style: TextStyle(fontSize: 13, color: Paper.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
