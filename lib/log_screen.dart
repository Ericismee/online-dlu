import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cache.dart';
import 'lms.dart';
import 'nhat_ky.dart';
import 'paper.dart';

String _gio(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}'
    ':${t.second.toString().padLeft(2, '0')}.'
    '${(t.millisecond ~/ 100)}';

/// Còn bao lâu tới mốc đó, rỗng khi nhịp đang tắt.
String _demNguoc(DateTime? moc, DateTime now) {
  if (moc == null) return 'tắt';
  final con = moc.difference(now);
  if (con.isNegative) return 'đang chạy';
  final s = con.inSeconds;
  return s >= 60
      ? '${s ~/ 60}m${(s % 60).toString().padLeft(2, '0')}s'
      : '${s}s';
}

/// Sổ verbose đầy đủ: mới nhất trên cùng, chép được cả sổ để dán vào issue.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DotBackground(
      child: SafeArea(
        child: ValueListenableBuilder<List<DongLog>>(
          valueListenable: NhatKy.dong,
          builder: (context, dong, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Log',
                            style: TextStyle(
                              fontFamily: 'Display',
                              fontWeight: FontWeight.w800,
                              fontSize: 30,
                              color: Paper.ink,
                            ),
                          ),
                        ),
                        PaperButton(
                          label: 'Quay lại',
                          fontSize: 13,
                          color: Paper.card,
                          onColor: Paper.ink,
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _Giay(
                      builder: (now) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Pill('${dong.length}/${NhatKy.gioiHan} dòng'),
                          Pill(
                            'portal ${_demNguoc(PortalNhip.ke, now)}',
                            color: Paper.sky,
                          ),
                          Pill(
                            'lms ${_demNguoc(LmsNhip.ke, now)}',
                            color: Paper.sun,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PaperButton(
                          label: 'Chép hết',
                          fontSize: 13,
                          color: Paper.mint,
                          onColor: Paper.ink,
                          onPressed: dong.isEmpty
                              ? null
                              : () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: [
                                        for (final d in dong.reversed)
                                          '${_gio(d.luc)} ${d.nguon} · ${d.viec}',
                                      ].join('\n'),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Đã chép nhật ký'),
                                    ),
                                  );
                                },
                        ),
                        PaperButton(
                          label: 'Xoá sổ',
                          fontSize: 13,
                          color: Paper.rose,
                          onPressed: dong.isEmpty ? null : NhatKy.xoa,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: dong.length,
                  itemBuilder: (_, i) => _Dong(dong[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Đồng hồ chung của app chỉ nhích mỗi đầu phút, nên đếm ngược vẽ theo nó
/// đứng yên cả phút rồi tụt một cục — và số hiện ra lố tới gần một phút. Sổ
/// verbose thì đếm từng giây, chỉ chạy khi màn này còn trên màn hình.
class _Giay extends StatefulWidget {
  const _Giay({required this.builder});
  final Widget Function(DateTime now) builder;

  @override
  State<_Giay> createState() => _GiayState();
}

class _GiayState extends State<_Giay> {
  Timer? _hen;

  @override
  void initState() {
    super.initState();
    _hen = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _hen?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(DateTime.now());
}

class _Dong extends StatelessWidget {
  const _Dong(this.d);
  final DongLog d;

  /// Lượt hỏng đỏ, lượt đi/về xanh, còn lại là giấy — lướt là thấy chỗ gãy.
  Color get _mau => d.viec.startsWith('✗')
      ? Paper.rose
      : d.viec.startsWith('←')
      ? Paper.mint
      : d.viec.startsWith('→')
      ? Paper.sky
      : Paper.card;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _mau,
        border: Border.all(color: Paper.ink, width: 2),
        borderRadius: const BorderRadius.all(Paper.radius),
      ),
      child: Text(
        '${_gio(d.luc)}  ${d.nguon}  ${d.viec}',
        style: Paper.mono.copyWith(fontSize: 12, color: Paper.ink),
      ),
    ),
  );
}
