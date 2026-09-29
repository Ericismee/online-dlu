import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'paper.dart';

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
  const UpdateBanner({super.key, this.check = UpdateCheck.newerVersion});

  /// Cách kiểm tra bản mới — thay bằng giả lập lúc test, khỏi đụng mạng
  /// hay PackageInfo thật.
  final Future<String?> Function() check;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  String? _version;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final v = await widget.check();
    if (v == null || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString('dismissed_update') == v) return;
    if (mounted) setState(() => _version = v);
  }

  Future<void> _dismiss() async {
    final v = _version;
    setState(() => _version = null);
    if (v != null) {
      (await SharedPreferences.getInstance()).setString('dismissed_update', v);
    }
  }

  @override
  Widget build(BuildContext context) {
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
            const Icon(Icons.rocket_launch_rounded, color: Paper.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Có bản mới v$v — bấm để tải',
                style: const TextStyle(
                  color: Paper.ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: const Icon(Icons.close_rounded, color: Paper.ink2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Changelog của bản đang cài, đọc từ `lc.json` đóng gói sẵn trong app —
/// cùng nội dung AltStore/LiveContainer hiện lúc cài, khỏi phải gõ hai chỗ.
class Changelog extends StatefulWidget {
  const Changelog({super.key});

  @override
  State<Changelog> createState() => _ChangelogState();
}

class _ChangelogState extends State<Changelog> {
  String? _text;
  String? _version;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await rootBundle.loadString('lc.json');
      final versions = (jsonDecode(raw)['apps'][0]['versions'] as List)
          .cast<Map>();
      final mine = (await PackageInfo.fromPlatform()).version;
      final v = versions.firstWhere(
        (v) => v['version'] == mine,
        orElse: () => versions.first,
      );
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('dismissed_changelog') == mine) return;
      if (mounted) {
        setState(() {
          _text = v['localizedDescription'] as String;
          _version = mine;
        });
      }
    } catch (_) {
      // Thiếu asset (test) hay JSON hỏng thì im lặng, khỏi hiện gì.
    }
  }

  Future<void> _dismiss() async {
    final v = _version;
    setState(() => _text = null);
    if (v != null) {
      (await SharedPreferences.getInstance()).setString(
        'dismissed_changelog',
        v,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _text;
    if (t == null || t.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: PaperBox(
        color: Paper.card,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.new_releases_rounded, color: Paper.ink),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Có gì mới',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Paper.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t,
                    style: const TextStyle(fontSize: 13, color: Paper.ink2),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _dismiss,
              icon: const Icon(Icons.close_rounded, color: Paper.ink2),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
