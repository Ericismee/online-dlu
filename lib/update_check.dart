import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'db.dart';
import 'paper.dart';

/// Một dòng lịch sử cập nhật: bản nào, ra ngày nào, đổi những gì.
typedef BanGhi = ({String version, String date, String text});

/// So bản đang cài với bản mới nhất trên GitHub Releases của repo. Không
/// đụng gì tới portal trường hay Cache — gọi thẳng GitHub, và im lặng bỏ
/// qua nếu mạng hỏng hay GitHub chặn (rate-limit).
class UpdateCheck {
  static const repo = 'dopaemon/online-dlu';
  static const releasesUrl = 'https://github.com/$repo/releases/latest';

  /// Tag bản mới nhất (vd '1.0.2') nếu mới hơn bản đang chạy, null nếu đã
  /// là bản mới nhất hoặc không kiểm tra được.
  static Future<String?> newerVersion({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c
          .get(Uri.parse('https://api.github.com/repos/$repo/releases/latest'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final tag = (jsonDecode(res.body)['tag_name'] as String?)?.replaceFirst(
        'v',
        '',
      );
      if (tag == null) return null;
      final current = (await PackageInfo.fromPlatform()).version;
      return _newer(tag, current) ? tag : null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// Link tải trực tiếp file build của bản [version] cho máy này, null nếu
  /// release đó chưa có file. Tag ra trước lúc CI dựng xong là chuyện thường,
  /// và lúc đó nút tải chỉ dẫn người ta vào một trang không có gì để tải.
  static Future<String?> taiUrl(String version, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c
          .get(
            Uri.parse(
              'https://api.github.com/repos/$repo/releases/tags/v$version',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final duoi = defaultTargetPlatform == TargetPlatform.iOS
          ? '.ipa'
          : '.apk';
      for (final a in (jsonDecode(res.body)['assets'] as List? ?? const [])) {
        final ten = a['name'] as String? ?? '';
        // Bản 'unsigned' phải tự ký mới cài được, không tính là file tải sẵn.
        if (ten.endsWith(duoi) && !ten.contains('unsigned')) {
          return a['browser_download_url'] as String?;
        }
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (client == null) c.close();
    }
  }

  /// `version.json` trên nhánh main — nơi kê khai mọi bản, nên có cả bản vừa
  /// ra. Mạng hỏng thì lấy bản đóng gói sẵn trong app, cũ
  /// hơn nhưng vẫn đọc được lịch sử tới lúc đóng gói.
  static Future<List<BanGhi>> lichSu({http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      final res = await c
          .get(
            Uri.parse(
              'https://raw.githubusercontent.com/$repo/main/version.json',
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        // Rỗng thì coi như chưa đọc được, rơi xuống bản đóng gói chứ đừng
        // hiện màn trống.
        final m = _doc(utf8.decode(res.bodyBytes));
        if (m.isNotEmpty) return m;
      }
    } catch (_) {
      // mạng hỏng, rơi xuống bản đóng gói
    } finally {
      if (client == null) c.close();
    }
    try {
      return _doc(await rootBundle.loadString('version.json'));
    } catch (_) {
      return const [];
    }
  }

  static List<BanGhi> _doc(String raw) => [
    for (final m in (jsonDecode(raw)['versions'] as List? ?? const []))
      (
        version: m['version'] as String,
        date: m['date'] as String? ?? '',
        text: [for (final c in (m['changes'] as List? ?? const [])) '• $c']
            .join('\n'),
      ),
  ];

  /// Changelog của bản [version], null nếu lịch sử chưa có bản đó — thà không
  /// hiện còn hơn dán nhầm mô tả bản cũ lên thẻ báo bản mới.
  static Future<String?> notesFor(String version, {http.Client? client}) async {
    for (final m in await lichSu(client: client)) {
      if (m.version == version) return m.text;
    }
    return null;
  }

  /// So 'x.y.z' theo từng số — đủ dùng cho kiểu versioning ba số của app này.
  static bool _newer(String a, String b) {
    final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < pa.length || i < pb.length; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}

/// Thẻ báo có bản mới, tự ẩn khi không có gì để báo. Bấm tắt thì im luôn
/// tới bản sau, không nhắc lại cùng một bản đã bỏ qua.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({
    super.key,
    this.check = UpdateCheck.newerVersion,
    this.notes = UpdateCheck.notesFor,
  });

  /// Cách kiểm tra bản mới — thay bằng giả lập lúc test, khỏi đụng mạng
  /// hay PackageInfo thật.
  final Future<String?> Function() check;

  /// Changelog của bản mới, cũng thay được lúc test.
  final Future<String?> Function(String) notes;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner>
    with AutomaticKeepAliveClientMixin, Reloadable<UpdateBanner> {
  String? _version;
  String? _notes;

  /// Kéo xuống làm mới là hỏi GitHub lại luôn — người dùng kéo vì muốn mọi thứ
  /// mới, bản app cũng là một thứ.
  @override
  Future<void> reload() => _check();

  @override
  void initState() {
    super.initState();
    _check(moApp: true);
  }

  Future<void> _check({bool moApp = false}) async {
    final v = await widget.check();
    if (v == null || !mounted) return;
    if ((await Db.i.doc(nhomMoc, 'dismissed_update'))?.giaTri == v) return;
    if (mounted) setState(() => _version = v);
    final notes = await widget.notes(v);
    if (notes != null && mounted) setState(() => _notes = notes);
    // Mở app mà có bản mới thì nói thẳng một lần, đừng để thẻ nằm im dưới
    // cuộn rồi chẳng ai thấy. Lần sau mở lại cùng bản đó thì thôi, còn thẻ.
    final daHien = (await Db.i.doc(nhomMoc, 'shown_update'))?.giaTri;
    if (moApp && mounted && daHien != v) {
      await Db.i.ghi(nhomMoc, 'shown_update', giaTri: v);
      if (!mounted) return;
      final tai = await confirmDialog(
        context,
        title: 'Có bản mới v$v',
        body: notes ?? 'Bấm tải về để cập nhật.',
        ok: 'Tải về',
        icon: Icons.rocket_launch_rounded,
        color: Paper.mint,
      );
      if (tai) {
        await launchUrl(
          Uri.parse(UpdateCheck.releasesUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    }
  }

  // Kéo khỏi màn hình là ListView huỷ thẻ, lúc quay lại nó dựng lại từ đầu nên
  // cao 0 một nhịp: cả trang tụt đúng chiều cao thẻ rồi phình lại, nhìn như bị
  // nhảy ngược lên trên. Giữ state là hết.
  @override
  bool get wantKeepAlive => true;

  Future<void> _dismiss() async {
    final v = _version;
    setState(() => _version = null);
    if (v != null) {
      await Db.i.ghi(nhomMoc, 'dismissed_update', giaTri: v);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final v = _version;
    if (v == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: PaperBox(
        color: Paper.mint,
        onTap: () => launchUrl(
          Uri.parse(UpdateCheck.releasesUrl),
          mode: LaunchMode.externalApplication,
        ),
        child: Row(
          children: [
            Icon(Icons.rocket_launch_rounded, color: Paper.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Có bản mới v$v — bấm để tải',
                    style: TextStyle(
                      color: Paper.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_notes != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _notes!,
                      style: TextStyle(fontSize: 13, color: Paper.ink2),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: Icon(Icons.close_rounded, color: Paper.ink2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Changelog của bản đang cài, đọc từ `version.json` đóng gói sẵn trong app —
/// cùng nguồn với màn Cập nhật, khỏi phải gõ hai chỗ.
class Changelog extends StatefulWidget {
  const Changelog({super.key});

  @override
  State<Changelog> createState() => _ChangelogState();
}

class _ChangelogState extends State<Changelog>
    with AutomaticKeepAliveClientMixin {
  String? _text;
  String? _version;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final lichSu = UpdateCheck._doc(
        await rootBundle.loadString('version.json'),
      );
      final mine = (await PackageInfo.fromPlatform()).version;
      final v = lichSu.firstWhere(
        (v) => v.version == mine,
        orElse: () => lichSu.first,
      );
      if ((await Db.i.doc(nhomMoc, 'dismissed_changelog'))?.giaTri == mine) {
        return;
      }
      if (mounted) {
        setState(() {
          _text = v.text;
          _version = mine;
        });
      }
    } catch (_) {
      // Thiếu asset (test) hay JSON hỏng thì im lặng, khỏi hiện gì.
    }
  }

  // Như [UpdateBanner]: dựng lại mất một nhịp, thẻ co về 0 làm trang nhảy.
  @override
  bool get wantKeepAlive => true;

  Future<void> _dismiss() async {
    final v = _version;
    setState(() => _text = null);
    if (v != null) {
      await Db.i.ghi(nhomMoc, 'dismissed_changelog', giaTri: v);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = _text;
    if (t == null || t.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: PaperBox(
        color: Paper.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.new_releases_rounded, color: Paper.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Có gì mới',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Paper.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(t, style: TextStyle(fontSize: 13, color: Paper.ink2)),
                ],
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: Icon(Icons.close_rounded, color: Paper.ink2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Màn 'Cập nhật': bản đang dùng, nút tải nếu có bản mới, và lịch sử thay đổi
/// của mọi bản. Nguồn là `version.json` nên khỏi gõ changelog ở chỗ thứ hai.
class ChangelogScreen extends StatefulWidget {
  const ChangelogScreen({
    super.key,
    this.check = UpdateCheck.newerVersion,
    this.lichSu = UpdateCheck.lichSu,
    this.tai = UpdateCheck.taiUrl,
  });

  /// Cách kiểm tra bản mới — thay bằng giả lập lúc test.
  final Future<String?> Function() check;

  /// Nguồn lịch sử, cũng thay được lúc test.
  final Future<List<BanGhi>> Function() lichSu;

  /// Link tải file build của một bản, null nếu bản đó chưa có file.
  final Future<String?> Function(String) tai;

  @override
  State<ChangelogScreen> createState() => _ChangelogScreenState();
}

class _ChangelogScreenState extends State<ChangelogScreen>
    with Reloadable<ChangelogScreen> {
  @override
  Future<void> reload() => _load();

  List<BanGhi>? _lichSu;
  String? _dangDung;
  String? _moi;

  /// Link tải của bản mới; null là release chưa có file build cho máy này.
  String? _tai;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lichSu = await widget.lichSu();
    final moi = await widget.check();
    if (!mounted) return;
    setState(() {
      _lichSu = lichSu;
      _moi = moi;
      _tai = null;
    });
    if (moi != null) {
      final tai = await widget.tai(moi);
      if (mounted) setState(() => _tai = tai);
    }
    // Số bản đang dùng chỉ để gắn nhãn, đừng để nó chặn danh sách: không có
    // nền tảng thật (test) thì PackageInfo treo luôn.
    try {
      final v = (await PackageInfo.fromPlatform()).version;
      if (mounted) setState(() => _dangDung = v);
    } catch (_) {
      // thôi, khỏi khoe số bản
    }
  }

  @override
  Widget build(BuildContext context) {
    final lichSu = _lichSu;
    final moi = _moi;
    return Scaffold(
      body: DotBackground(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 940),
            child: PullRefresh(
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
                      Expanded(
                        child: Text(
                          'Cập nhật',
                          style: TextStyle(
                            fontFamily: 'Display',
                            fontWeight: FontWeight.w800,
                            fontSize: 30,
                            color: Paper.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PaperButton(
                        label: 'Quay lại',
                        color: Paper.card,
                        onColor: Paper.ink,
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (moi != null)
                    PaperBox(
                      color: Paper.mint,
                      child: Row(
                        children: [
                          Icon(Icons.rocket_launch_rounded, color: Paper.ink),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Có bản mới v$moi',
                                  style: TextStyle(
                                    color: Paper.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                // Tag ra trước, file build theo sau: nói rõ là
                                // chưa có gì để tải, hơn là cho nút dẫn vào
                                // trang release trống.
                                if (_tai == null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Bản này chưa có file tải cho máy bạn',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Paper.ink2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (_tai != null) ...[
                            const SizedBox(width: 12),
                            PaperButton(
                              label: 'Tải xuống',
                              fontSize: 13,
                              onPressed: () => launchUrl(
                                Uri.parse(_tai!),
                                mode: LaunchMode.externalApplication,
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  else if (_dangDung != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Pill('Đang dùng v$_dangDung'),
                    ),
                  const SizedBox(height: 20),
                  if (lichSu == null)
                    const Skeleton(height: 120, ink: true)
                  else
                    for (final m in lichSu)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _BanCard(
                          ban: m,
                          dangDung: m.version == _dangDung,
                        ),
                      ),
                  if (lichSu != null && lichSu.isEmpty)
                    Text(
                      'Chưa đọc được lịch sử cập nhật.',
                      style: TextStyle(color: Paper.ink2),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BanCard extends StatelessWidget {
  const _BanCard({required this.ban, required this.dangDung});
  final BanGhi ban;
  final bool dangDung;

  @override
  Widget build(BuildContext context) => PaperBox(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'v${ban.version}',
              style: TextStyle(
                fontFamily: 'Display',
                fontWeight: FontWeight.w800,
                fontSize: 20,
                color: Paper.ink,
              ),
            ),
            const SizedBox(width: 10),
            if (dangDung) Pill('Đang dùng', color: Paper.mint),
            const Spacer(),
            Text(ban.date, style: TextStyle(fontSize: 12, color: Paper.ink2)),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          ban.text,
          style: TextStyle(fontSize: 13, color: Paper.ink2, height: 1.45),
        ),
      ],
    ),
  );
}
